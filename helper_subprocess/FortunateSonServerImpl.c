#include "FortunateSonServer.h"
#include <stdio.h>
#include <limits.h>
#include <fcntl.h>
#include <errno.h>
#include <assert.h>
#include <stdarg.h>
#include <unistd.h>

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
