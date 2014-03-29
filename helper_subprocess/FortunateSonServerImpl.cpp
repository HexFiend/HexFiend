#define INDENT_HIDDEN_FROM_XCODE {
#define UNINDENT_HIDDEN_FROM_XCODE }

extern "C" INDENT_HIDDEN_FROM_XCODE

#include "FortunateSonServer.h"
#include <stdio.h>
#include <limits.h>
#include <fcntl.h>
#include <errno.h>
#include <assert.h>
#include <stdarg.h>
#include <unistd.h>
#include <stdlib.h>
#include <sys/disk.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <mach/mach_vm.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>
#include <mach/task.h>
#include <mach/mach_traps.h>
#include <mach/mach_error.h>
#include <mach/machine.h>
#include "fileport.h"
#include <Security/Authorization.h>

#define MAX_FD_VALUE 1024

static AuthorizationRef authRef;

static void *allocate_mach_memory(vm_size_t *size) {
    vm_size_t localSize = mach_vm_round_page(*size);
    void *localAddress = NULL;
    kern_return_t kr = vm_allocate(mach_task_self(), (vm_address_t *)&localAddress, localSize, VM_FLAGS_ANYWHERE);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "failed to vm_allocate(%ld)\nmach error: %s\n", (long)localSize, (char*)mach_error_string(kr));
        exit(-1);
    }
    *size = localSize;
    return (void *)localAddress;
}

kern_return_t _FortunateSonSayHey(mach_port_t, FilePath path, int *result) {
    printf("Hey guys this is my function %s\n", path);
    *result = 12345;
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonOpenFile(mach_port_t, FilePath path, int writable, fileport_t *fd_port, int *err) {
	char *right_name;
	asprintf(&right_name, "sys.openfile.%s.%s",
			 writable ? "readwritecreate" : "readonly",
			 path);

	AuthorizationItem right = {
		.name = right_name
	};
	
	AuthorizationRights rights = {
		.count = 1,
		.items = &right
	};

	OSStatus status = AuthorizationCopyRights(authRef, &rights, NULL, kAuthorizationFlagExtendRights | kAuthorizationFlagInteractionAllowed, NULL);
	free (right_name);

	if (status == errAuthorizationCanceled) {
		*fd_port = MACH_PORT_NULL;
		*err = ECANCELED;
		return KERN_SUCCESS;
	}
	if (status) {
		*fd_port = MACH_PORT_NULL;
		*err = EACCES;
		return KERN_SUCCESS;
	}

	int fd = open(path, writable ? O_RDWR | O_CREAT : O_RDONLY, S_IRUSR|S_IWUSR);

	if (fd < 0) {
		*fd_port = MACH_PORT_NULL;
		*err = errno;
		return KERN_SUCCESS;
	}
	
	if (fileport_makeport(fd, fd_port)) {
		*fd_port = MACH_PORT_NULL;
		*err = errno;
		perror("fileport_makeport failed");
		close(fd);
		return KERN_SUCCESS;
	}

	if (close(fd))
		perror("close failed");
	*err = 0;

	return KERN_SUCCESS;
}

#if 0
    mach_vm_address_t address = 0;
    VMUNonOverlappingRangeArray        *ranges = [[VMUNonOverlappingRangeArray new] autorelease];
    natural_t nesting_depth = 0;
    NSString *lastRegionDescription = nil;
    
    while (1) {
        mach_vm_size_t size;
        vm_region_submap_short_info_data_64_t info;
        mach_msg_type_number_t count;
        count = VM_REGION_SUBMAP_SHORT_INFO_COUNT_64;
        kern_return_t err = mach_vm_region_recurse(task, &address, &size, &nesting_depth, (vm_region_info_t)&info, &count);
        if (err) break; // invalid entry when we reach end.
        
        VMURange regionRange = VMUMakeRange(address, size);
        
        if (info.share_mode == SM_EMPTY ||                  // ignore all NULL regions !!!  Check this here so we don't need to in other conditionals below.
            info.user_tag == VM_MEMORY_ANALYSIS_TOOL ) {    // ignore memory used to record the malloc stacks for MallocStackLogging
            //
            //fprintf(stderr, "Skipping region %s\n", [[regionIdentifier descriptionForRange:regionRange] UTF8String]);
            //
        } else {
            lastRegionDescription = add_region_range(ranges, regionRange, regionIdentifier, lastRegionDescription, "region to full region list");
        }
        
        address += size;
    }
    
    return ranges;
#endif

static mach_port_name_t check_task_for_pid(pid_t pid) {
    mach_port_name_t task = MACH_PORT_NULL;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &task);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "failed to get task for pid %d\nmach error: %s\n", pid, (char*) mach_error_string(kr));
        exit(-1);
    }
    return task;
}

kern_return_t _FortunateSonReadProcess(mach_port_t, int pid, mach_vm_address_t offset, mach_vm_size_t requestedLength, VarData_t* result, mach_msg_type_number_t *resultCnt) {
    printf("Reading %p, %llu\n", (void *)(long)offset, requestedLength);
    mach_port_name_t task = check_task_for_pid(pid);
    mach_vm_address_t startPage = mach_vm_trunc_page(offset);
    mach_vm_size_t pageLength = mach_vm_round_page(offset + requestedLength - startPage);
    
    vm_offset_t data = 0;
    mach_msg_type_number_t dataLen = 0;
    kern_return_t kr = mach_vm_read(task, startPage, pageLength, &data, &dataLen);
    if (kr == KERN_PROTECTION_FAILURE) {
        /* Can't read this range */
        vm_size_t localSize = requestedLength;
        void *localAddress = allocate_mach_memory(&localSize);
        bzero(localAddress, localSize); //probably not necessary
        *result = (VarData_t)localAddress;
        *resultCnt = (mach_msg_type_number_t)localSize;
    }
    else if (kr == KERN_INVALID_ADDRESS) {
        vm_size_t localSize = requestedLength;
        void *localAddress = allocate_mach_memory(&localSize);
        bzero(localAddress, localSize); //probably not necessary
        *result = (VarData_t)localAddress;
        *resultCnt = (mach_msg_type_number_t)localSize;
    }
    else if (kr == KERN_SUCCESS) {
        if (startPage == offset) {
            /* We can return the data immediately */
            *result = (VarData_t)data;
            *resultCnt = dataLen;
        }
        else {
            /* We have to allocate new pages and copy it */
            vm_size_t localSize = requestedLength;
            void *localAddress = allocate_mach_memory(&localSize);
            memcpy(localAddress, (offset - startPage) + (const unsigned char *)data, requestedLength);
            vm_deallocate(mach_task_self(), data, dataLen);
            *result = (unsigned char *)localAddress;
            *resultCnt = (mach_msg_type_number_t)localSize;
        }
    }
    else {
        fprintf(stdout, "failed to vm_read for pid %d\nmach error: %s\n", pid, (char*) mach_error_string(kr));
        vm_size_t localSize = requestedLength;
        void *localAddress = allocate_mach_memory(&localSize);
        bzero(localAddress, localSize); //probably not necessary
        *result = (VarData_t)localAddress;
        *resultCnt = (mach_msg_type_number_t)localSize;
    }
    
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonAttributesForAddress(mach_port_t, int pid, mach_vm_address_t offset, VMRegionAttributes *result, mach_vm_size_t *applicableLength) {
    printf("Reading attributes for %p\n", (void *)(long)offset);
    mach_port_name_t task = check_task_for_pid(pid);
    mach_vm_address_t regionAddress = offset;
    mach_vm_size_t regionSize = 0;
    struct vm_region_basic_info_64 info = {};
    mach_msg_type_number_t infoCount = VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t unused_object_name;
    kern_return_t kr = mach_vm_region(task, &regionAddress, &regionSize, VM_REGION_BASIC_INFO_64, (vm_region_info_t)&info, &infoCount, &unused_object_name);
    VMRegionAttributes resultingAttributes = 0;
    mach_vm_size_t resultingLength = 0;
    if (kr == KERN_INVALID_ADDRESS) {
        printf("Bad address %p -> %p, size is %ld\n", (void *)(long)offset, (void *)(long)regionAddress, (long)regionSize);
    }
    else if (kr == KERN_SUCCESS) {
        if (regionAddress > offset) {
            /* We found a region larger than the given offset.  We are unmapped up to that found region. */
            resultingAttributes |= VMRegionUnmapped;
            resultingLength = regionAddress - offset;
        }
        else {
            if (info.protection & VM_PROT_READ) resultingAttributes |= VMRegionReadable;
            if (info.protection & VM_PROT_WRITE) resultingAttributes |= VMRegionWritable;
            if (info.protection & VM_PROT_EXECUTE) resultingAttributes |= VMRegionExecutable;
            if (info.shared) resultingAttributes |= VMRegionShared;
            assert(offset - regionAddress <= regionSize);
            resultingLength = regionSize - (offset - regionAddress);
        }
    }
    else {
        fprintf(stdout, "failed to mach_vm_region for pid %d\nmach error: %s\n", pid, (char*) mach_error_string(kr));
    }
    *result = resultingAttributes;
    *applicableLength = resultingLength;
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonProcessInfo(mach_port_t, int pid, uint8_t *outBitSize) {

    cpu_type_t  cpuType;
    size_t      cpuTypeSize;
    int         mib[CTL_MAXNAME];
    size_t      mibLen;
    mibLen  = CTL_MAXNAME;
    int err;
    uint8_t bitSize = 0;
    
    err = sysctlnametomib("sysctl.proc_cputype", mib, &mibLen);
    if (err == 0) {
        assert(mibLen < CTL_MAXNAME);
        mib[mibLen] = pid;
        mibLen += 1;
        
        cpuTypeSize = sizeof(cpuType);
        err = sysctl(mib, (u_int)mibLen, &cpuType, &cpuTypeSize, 0, 0);
        if (err == 0) {
            switch (cpuType) {
                case CPU_TYPE_X86:
                case CPU_TYPE_POWERPC:
                case CPU_TYPE_ARM:
                    bitSize = 32;
                    break;
                case CPU_TYPE_X86_64:
                case CPU_TYPE_POWERPC64:
                    bitSize = 64;
                    break;
                default:
                    bitSize = 0;
                    break;
            }
        }
    }
    
    *outBitSize = bitSize;
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonSetAuthorization(mach_port_t, AuthorizationExternalForm authExt) {
	AuthorizationCreateFromExternalForm(&authExt, &authRef);
	return KERN_SUCCESS;
}

//extern C
UNINDENT_HIDDEN_FROM_XCODE
