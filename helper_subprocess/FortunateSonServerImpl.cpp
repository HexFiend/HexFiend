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
#include <mach/mach_vm.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>
#include <mach/task.h>
#include <mach/mach_traps.h>
#include <mach/mach_error.h>

#define MAX_FD_VALUE 1024

static char sOpenFiles[MAX_FD_VALUE / CHAR_BIT];

static unsigned get_bit_value(int index) {
    if (index < 0 || index >= MAX_FD_VALUE) return 0;
    unsigned byte = index / CHAR_BIT;
    unsigned bit = index % CHAR_BIT;
    return !! (sOpenFiles[byte] & (1 << bit));
}

static void set_bit_value(int index, unsigned val) {        
    assert(val >= 0 && val < MAX_FD_VALUE);
    unsigned byte = index / CHAR_BIT;
    unsigned bit = index % CHAR_BIT;
    if (val) {
        sOpenFiles[byte] |= (1 << bit);
    }
    else {
        sOpenFiles[byte] &= ~(1 << bit);
    }
}

static void print_error(const char *fmt, ...) __attribute__ ((format (printf, 1, 2)));
static void print_error(const char *fmt, ...) {
    va_list argp;
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    va_end(argp);
    fputc('\n', stderr);
    fflush(stderr);
}

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

static void free_mach_memory(void *ptr, vm_size_t size) {
    kern_return_t kr = vm_deallocate(mach_task_self(), (vm_address_t)ptr, size);
    if (kr != KERN_SUCCESS) {
	fprintf(stdout, "failed to vm_deallocate(%p)\nmach error: %s\n", ptr, (char*) mach_error_string(kr));
	exit(-1);
    }    
}


kern_return_t _FortunateSonSayHey(mach_port_t server, FilePath path, int *result) {
    printf("Hey guys this is my function %s\n", path);
    *result = 12345;
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonOpenFile(mach_port_t server, FilePath path, int writable, int *result, int *result_error, uint64_t *file_size, uint16_t *file_type, uint64_t *inode, int *device) {
    if (! result || ! result_error) {
        print_error("Cannot pass NULL pointers to OpenFile()");
        return KERN_SUCCESS;
    }
    writable = 0;
    printf("Opening %s\n", path);    
    int flags = (writable ? O_RDONLY : O_RDWR);
    errno = 0;
    int fd = open(path, flags);
    if (fd == -1) {
        *result_error = errno;
    }
    int oldErr = errno;
    printf("Seeking: %d - %lld\n", fd, lseek(fd, 100, SEEK_END));
    errno = oldErr;
    
    if (fd >= 0) {
        fcntl(fd, F_NOCACHE, 0); //disable caching
        set_bit_value(fd, 1);
        *result_error = 0;
    }
    
    struct stat sb = {0};
    if (fd >= 0) {
	int statresult = fstat(fd, &sb);
	if (statresult != 0) {
	    *result_error = errno;
	    close(fd);
	    fd = -1;
	}
    }
    
    if (fd >= 0) {
	if (S_ISBLK(sb.st_mode) || S_ISCHR(sb.st_mode)) {
	    /* Block and character files don't return their size in the stat struct.  We can get it with some ioctls. There's a ton more ioctls we should be handling here, like DKIOCGETMAXBLOCKCOUNTREAD; we don't get these right yet. */
	    uint32_t blockSize = 0;
	    uint64_t blockCount = 0;
	    int bsderr = 0;
	    bsderr = bsderr || ioctl(fd, DKIOCGETBLOCKSIZE, &blockSize);
	    bsderr = bsderr || ioctl(fd, DKIOCGETBLOCKCOUNT, &blockCount);
	    if (bsderr) {
		*result_error = errno;
		close(fd);
		fd = -1;
	    }
	    *file_size = blockSize * (uint64_t)blockCount;
	    printf("SIZE: %llu\n", *file_size);
	}
	else {
	    *file_size = sb.st_size;
	}
	
	*file_type = sb.st_mode;
	*inode = sb.st_ino;
	*device = sb.st_dev;
    }
    *result = fd;
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonReadFile(mach_port_t server, int fd, FileOffset_t offset, uint32_t *requestedLength, VarData_t *result, mach_msg_type_number_t *resultCnt, int *result_error) {
    if (! result || ! result_error || ! resultCnt || ! requestedLength) {
        print_error("Cannot pass NULL pointers to ReadFile()");
        return KERN_SUCCESS;
    }
    if (! get_bit_value(fd)) {
        print_error("File %d is not open", fd);
        return KERN_SUCCESS;
    }

    vm_size_t localSize = *requestedLength;
    void *localAddress = allocate_mach_memory(&localSize);
    
    int localError = 0;
    ssize_t amountRead = pread(fd, localAddress, *requestedLength, offset);
    if (amountRead == -1) {
	localError = errno;
	free_mach_memory(localAddress, localSize);
	localAddress = 0;
	localSize = 0;
    }
    
    *result = (VarData_t)localAddress;
    *resultCnt = localSize;
    *requestedLength = (uint32_t)amountRead;
    *result_error = localError;
    
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonCloseFile(mach_port_t server, int fd) {
    if (! get_bit_value(fd)) {
        print_error("File %d is not open", fd);
        return KERN_SUCCESS;
    }
    close(fd);
    set_bit_value(fd, 0);
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

kern_return_t _FortunateSonReadProcess(mach_port_t server, int pid, mach_vm_address_t offset, mach_vm_size_t requestedLength, VarData_t* result, mach_msg_type_number_t *resultCnt) {
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
        *resultCnt = localSize;
    }
    else if (kr == KERN_INVALID_ADDRESS) {
        vm_size_t localSize = requestedLength;
        void *localAddress = allocate_mach_memory(&localSize);
        bzero(localAddress, localSize); //probably not necessary
        *result = (VarData_t)localAddress;
        *resultCnt = localSize;
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
            *resultCnt = localSize;
        }
    }
    else {
        fprintf(stdout, "failed to vm_read for pid %d\nmach error: %s\n", pid, (char*) mach_error_string(kr));
        vm_size_t localSize = requestedLength;
        void *localAddress = allocate_mach_memory(&localSize);
        bzero(localAddress, localSize); //probably not necessary
        *result = (VarData_t)localAddress;
        *resultCnt = localSize;
    }
    
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonAttributesForAddress(mach_port_t server, int pid, mach_vm_address_t offset, VMRegionAttributes *result, mach_vm_size_t *applicableLength) {
    printf("Reading attributes for %p\n", (void *)(long)offset);
    mach_port_name_t task = check_task_for_pid(pid);
    mach_vm_address_t regionAddress = offset;
    mach_vm_size_t regionSize = 0;
    struct vm_region_basic_info_64 info = {0};
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

//extern C
UNINDENT_HIDDEN_FROM_XCODE
