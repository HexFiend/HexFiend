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

@implementation HFFileReference

- initWithPath:(NSString *)path {
    int result;
    REQUIRE_NOT_NULL(path);
    const char* p = [path fileSystemRepresentation];
    fileDescriptor = open(p, O_RDONLY, 0);
    if (fileDescriptor < 0) {
        [NSException raise:NSGenericException format:@"Unable to open file %@. %s.", path, strerror(errno)];
    }
    struct stat64 sb;
    result = fstat64(fileDescriptor, &sb);
    if (result != 0) {
        close(fileDescriptor);
        [NSException raise:NSGenericException format:@"Unable to fstat64 file %@. %s.", path, strerror(errno)];
    }
    fileLength = sb.st_size;
    inode = sb.st_ino;
    HFSetFDShouldCache(fileDescriptor, NO);
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

@end
