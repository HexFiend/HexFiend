//
//  HFFileReference.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/23/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFFileReference.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>

#define USE_STAT64 0

@implementation HFFileReference

- sharedInitWithPath:(NSString *)path {
    int result;
    REQUIRE_NOT_NULL(path);
    const char* p = [path fileSystemRepresentation];
    if (isWritable) {
        fileDescriptor = open(p, O_RDWR | O_CREAT, 0);
    }
    else {
        fileDescriptor = open(p, O_RDONLY, 0);
    }
    if (fileDescriptor < 0) {
        [NSException raise:NSGenericException format:@"Unable to open file %@. %s.", path, strerror(errno)];
    }
#if USE_STAT64
    struct stat64 sb;
    result = fstat64(fileDescriptor, &sb);
#else
    struct stat sb;
    result = fstat(fileDescriptor, &sb);
#endif
    if (result != 0) {
        close(fileDescriptor);
        [NSException raise:NSGenericException format:@"Unable to fstat64 file %@. %s.", path, strerror(errno)];
    }
    fileLength = sb.st_size;
    inode = sb.st_ino;
    HFSetFDShouldCache(fileDescriptor, NO);
    return self;
}

- initWithPath:(NSString *)path {
    [super init];
    isWritable = NO;
    [self sharedInitWithPath:path];
    return self;
}

- initWritableWithPath:(NSString *)path {
    [super init];
    isWritable = YES;
    [self sharedInitWithPath:path];
    return self;
}

- (void)readBytes:(unsigned char*)buff length:(NSUInteger)length from:(unsigned long long)pos {
    if (! length) return;
    REQUIRE_NOT_NULL(buff);
    HFASSERT(length <= LONG_MAX);
    HFASSERT(pos <= fileLength);
    HFASSERT(length <= fileLength - pos);
    if (fileDescriptor < 0) [NSException raise:NSInvalidArgumentException format:@"File has already been closed."];
    ssize_t result = pread(fileDescriptor, buff, length, pos);
    if (result != (long)length) {
        [NSException raise:NSGenericException format:@"Read result: %d expected: %u error: %s", result, length, strerror(errno)];
    }    
}

- (int)writeBytes:(unsigned char *)buff length:(NSUInteger)length to:(unsigned long long)offset {
    HFASSERT(isWritable);
    HFASSERT(fileDescriptor >= 0);
    if (! length) return 0;
    REQUIRE_NOT_NULL(buff);
    HFASSERT(offset <= fileLength);
    HFASSERT(length <= LONG_MAX);
    HFASSERT(offset <= LLONG_MAX);
    int err = 0;
    ssize_t result = pwrite(fileDescriptor, buff, (size_t)length, (off_t)offset);
    HFASSERT(result == -1 || result == (ssize_t)length);
    if (result < 0) err = errno;
    return err;
}

- (void)close {
    if (fileDescriptor >= 0) {
        close(fileDescriptor);
        fileDescriptor = -1;
    }
}

- (void)finalize {
    [self close];
    [super finalize];
}

- (void)dealloc {
    [self close];
    [super dealloc];
}

- (unsigned long long)length {
    return fileLength;
}

- (int)setLength:(unsigned long long)length {
    HFASSERT(isWritable);
    HFASSERT(fileDescriptor >= 0);
    HFASSERT(length <= LLONG_MAX);
    int err = 0, result;
    result = ftruncate(fileDescriptor, (off_t)length);
    HFASSERT(result <= 0);
    if (result < 0) {
        err = errno;
    }
    else {
        fileLength = length;
    }
    return err;
}

- (NSUInteger)hash {
    return (NSUInteger)inode;
}

- (BOOL)isEqual:(HFFileReference *)ref {
    if (! [ref isKindOfClass:[HFFileReference class]]) return NO;
    return ref->device == device && ref->inode == inode;
}

@end
