#include "FortunateSonServer.h"
#include <stdio.h>
#include <limits.h>
#include <fcntl.h>
#include <errno.h>
#include <assert.h>
#include <stdarg.h>
#include <unistd.h>
#include <stdlib.h>
#include <mach/mach_vm.h>
#include <mach/mach_init.h>
#include <mach/vm_map.h>
#include <mach/task.h>
#include <mach/mach_traps.h>
#include <mach/mach_error.h>


#define MAX_FD_VALUE 1024
unsigned char sOpenFiles[MAX_FD_VALUE / CHAR_BIT];

static void print_error(const char *fmt, ...) __attribute__ ((format (printf, 1, 2)));
static void print_error(const char *fmt, ...) {
    va_list argp;
    va_start(argp, fmt);
    vfprintf(stderr, fmt, argp);
    va_end(argp);
    fputc('\n', stderr);
    fflush(stderr);
}

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

kern_return_t _FortunateSonSayHey(mach_port_t server, FilePath path, int *result) {
    printf("Hey guys this is my function %s\n", path);
    *result = 12345;
    return KERN_SUCCESS;
}

kern_return_t _FortunateSonOpenFile(mach_port_t server, FilePath path, int writable, int *result, int *result_error) {
    if (! result || ! result_error) {
        print_error("Cannot pass NULL pointers to OpenFile()");
        return KERN_SUCCESS;
    }
    int flags = (writable ? O_RDONLY : O_RDWR);
    int fd = open(path, flags);
    if (fd == -1) {
        *result_error = errno;
    }
    else {
        fcntl(fd, F_NOCACHE, 0); //disable caching
        set_bit_value(fd, 1);
        *result_error = 0;
    }
    *result = fd;
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

kern_return_t _FortunateSonReadProcess(mach_port_t server, int pid, mach_vm_address_t offset, mach_vm_size_t requestedLength, VarData_t* result, mach_msg_type_number_t *resultCnt) {
    mach_port_name_t task;
    kern_return_t kr = task_for_pid(mach_task_self(), pid, &task);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "failed to get task for pid %d\nmach error: %s\n", pid, (char*) mach_error_string(kr));
        exit(-1);
    }

    printf("Reading %p, %llu\n", (void *)(long)offset, requestedLength);

    mach_vm_address_t startPage = mach_vm_trunc_page(offset);
    mach_vm_size_t pageLength = mach_vm_round_page(offset + requestedLength - startPage);
    
    vm_offset_t data = 0;
    mach_msg_type_number_t dataLen = 0;
    kr = mach_vm_read(task, startPage, pageLength, &data, &dataLen);
    if (kr == KERN_PROTECTION_FAILURE) {
        /* Can't read this range */
        vm_size_t localSize = requestedLength;
        void *localAddress = allocate_mach_memory(&localSize);
        bzero(localAddress, localSize); //probably not necessary
        *result = localAddress;
        *resultCnt = localSize;
    }
    else if (kr == KERN_INVALID_ADDRESS) {
        vm_size_t localSize = requestedLength;
        void *localAddress = allocate_mach_memory(&localSize);
        bzero(localAddress, localSize); //probably not necessary
        *result = localAddress;
        *resultCnt = localSize;
    }
    else if (kr == KERN_SUCCESS) {
        if (startPage == offset) {
            /* We can return the data immediately */
            *result = (unsigned char *)data;
            *resultCnt = dataLen;
        }
        else {
            /* We have to allocate new pages and copy it */
            vm_size_t localSize = requestedLength;
            void *localAddress = allocate_mach_memory(&localSize);
            memcpy(localAddress, (offset - startPage) + (const unsigned char *)data, requestedLength);
            vm_deallocate(mach_task_self(), data, dataLen);
            *result = (void *)localAddress;
            *resultCnt = localSize;
        }
    }
    else {
        fprintf(stdout, "failed to vm_read for pid %d\nmach error: %s\n", pid, (char*) mach_error_string(kr));
        vm_size_t localSize = requestedLength;
        void *localAddress = allocate_mach_memory(&localSize);
        bzero(localAddress, localSize); //probably not necessary
        *result = localAddress;
        *resultCnt = localSize;
    }
    
    return KERN_SUCCESS;
}
