//
//  HFFileReference.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/23/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFileReference.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>

#define USE_STAT64 0

/* The return code is just to quiet the static analyzer */
static BOOL returnReadError(NSError **error) {
    if (! error) return NO;

    int posixCode = errno;
    NSInteger cocoaCode = 0;
    switch (posixCode) {
	case ENOENT:	cocoaCode = NSFileReadNoSuchFileError; break;
	case EPERM:
	case EACCES:	cocoaCode = NSFileReadNoPermissionError; break;
	case ENAMETOOLONG:  cocoaCode = NSFileReadInvalidFileNameError; break;
    }
    if (cocoaCode != 0) {
	*error = [NSError errorWithDomain:NSCocoaErrorDomain code:cocoaCode userInfo:nil];	
    }
    else {
	*error = [NSError errorWithDomain:NSPOSIXErrorDomain code:posixCode userInfo:nil];
    }
    return NO;
}

static BOOL returnUnsupportedFileTypeError(NSError **error, mode_t mode) {
    if (! error) return NO;
    
    printf("TYPE: %o\n", mode);
    NSString *fileType;

    
    if (S_ISBLK(mode)) {
	fileType = @"special block file";
    }
    else if (S_ISCHR(mode)) {
	fileType = @"special character file";
    }
    else if (S_ISDIR(mode)) {
	fileType = @"directory";
    }    
    else if (S_ISFIFO(mode)) {
	fileType = @"named pipe (fifo)";
    }
    else if (S_ISSOCK(mode)) {
	fileType = @"socket";
    }
    else if (S_ISWHT(mode)) {
	fileType = @"whiteout";
    }
    else {
	fileType = [NSString stringWithFormat:@"unknown type (mode 0x%lx)", (long)mode];
    }
    NSString *errorDescription = [NSString stringWithFormat:@"The file is a %@ which is not a supported type.", fileType];
    NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:errorDescription, NSLocalizedDescriptionKey, nil];
    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:errorDict];
    return NO;
}

static BOOL returnFortunateSonError(NSError **error) {
    if (! error) return NO;
    NSString *errorDescription = @"There was an error communicating with the privileged helper process.";
    NSDictionary *errorDict = [NSDictionary dictionaryWithObjectsAndKeys:errorDescription, NSLocalizedDescriptionKey, nil];
    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:errorDict];    
    return NO;
}

static BOOL isFileTypeSupported(mode_t mode) {
    /* We support regular and block file types */
    return S_ISREG(mode) || S_ISBLK(mode) || S_ISCHR(mode);
}

static BOOL isFileTypeWritable(mode_t mode) {
    /* We only support writing to regular files */
    return S_ISREG(mode);
}

static BOOL returnFTruncateError(NSError **error) {
    const NSInteger HF_NSFileWriteVolumeReadOnlyError = 642 /* NSFileWriteVolumeReadOnlyError, only on SnowLeopard and later */;
    if (error) {
	int posixCode = errno;
	NSInteger cocoaCode = 0;
	switch (posixCode) {
	    case ENOSPC:	cocoaCode = NSFileWriteOutOfSpaceError; break;
	    case EROFS:		if (HFIsRunningOnLeopardOrLater()) cocoaCode = HF_NSFileWriteVolumeReadOnlyError; break;
	}
	if (cocoaCode != 0) {
	    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:cocoaCode userInfo:nil];	
	}
	else {
	    *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:posixCode userInfo:nil];
	}
    }
    return YES;
}

@implementation HFFileReference

- (void)close { UNIMPLEMENTED_VOID(); }
- (void)readBytes:(unsigned char *)buff length:(NSUInteger)length from:(unsigned long long)offset { UNIMPLEMENTED_VOID(); }
- (int)writeBytes:(const unsigned char *)buff length:(NSUInteger)length to:(unsigned long long)offset { UNIMPLEMENTED(); }
- (BOOL)setLength:(unsigned long long)length error:(NSError **)error { UNIMPLEMENTED(); }

- (unsigned long long)length {
    return fileLength;
}

/* Must be overridden - do not call super */
- (BOOL)initSharedWithPath:(NSString *)path error:(NSError **)error { UNIMPLEMENTED_VOID(); }

- (NSUInteger)hash {
    return (NSUInteger)inode;
}

- (BOOL)isEqual:(id)val {
    if (! [val isKindOfClass:[HFFileReference class]]) return NO;
    HFFileReference *ref = (HFFileReference *)val;
    return ref->device == device && ref->inode == inode;
}

+ allocWithZone:(NSZone *)zone {
    if (self == [HFFileReference class]) {
	/* Default to HFUnprivilegedFileReference */
	return [HFUnprivilegedFileReference allocWithZone:zone];
    }
    else {
	return [super allocWithZone:zone];
    }
}

- (BOOL)validateWithError:(NSError **)error {
    /* If this file is not a supported file type, then we fail validation */
    if (! isFileTypeSupported(fileMode) || (isWritable && ! isFileTypeWritable(fileMode))) {
	returnUnsupportedFileTypeError(error, fileMode);
	return NO;
    }
    return YES;
    
}

- initWithPath:(NSString *)path error:(NSError **)error {
    [super init];
    isWritable = NO;
    fileDescriptor = -1;
    if (! ([self initSharedWithPath:path error:error] && [self validateWithError:error])) {
	[self close];
	[self release];
	self = nil;
    }
    return self;
}

- initWritableWithPath:(NSString *)path error:(NSError **)error{
    [super init];
    isWritable = YES;
    fileDescriptor = -1;
    if (! ([self initSharedWithPath:path error:error] && [self validateWithError:error])) {
	[self close];
	[self release];
	self = nil;
    }
    return self;
}

- (void)finalize {
    [self close];
    [super finalize];
}

- (void)dealloc {
    [self close];
    [super dealloc];
}

@end

@implementation HFUnprivilegedFileReference

- (BOOL)initSharedWithPath:(NSString *)path error:(NSError **)error {
    int result;
    REQUIRE_NOT_NULL(path);
    const char* p = [path fileSystemRepresentation];
    if (isWritable) {
        fileDescriptor = open(p, O_RDWR | O_CREAT, 0744);
    }
    else {
        fileDescriptor = open(p, O_RDONLY, 0);
    }
    if (fileDescriptor < 0) {
	returnReadError(error);
	return NO;
    }
#if USE_STAT64
    struct stat64 sb;
    result = fstat64(fileDescriptor, &sb);
#else
    struct stat sb;
    result = fstat(fileDescriptor, &sb);
#endif
    if (result != 0) {
	int err = errno;
	returnReadError(error);
        NSLog(@"Unable to fstat64 file %@. %s.", path, strerror(err));
	return NO;
    }
    
    fileLength = sb.st_size;
    fileMode = sb.st_mode;
    inode = sb.st_ino;
    device = sb.st_dev;
    HFSetFDShouldCache(fileDescriptor, NO);
    return YES;
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

- (int)writeBytes:(const unsigned char *)buff length:(NSUInteger)length to:(unsigned long long)offset {
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
    if (result == 0) fileLength = MAX(fileLength, HFSum(length, offset));
    return err;
}

- (void)close {
    if (fileDescriptor >= 0) {
        close(fileDescriptor);
        fileDescriptor = -1;
    }
}

- (BOOL)setLength:(unsigned long long)length error:(NSError **)error {
    HFASSERT(isWritable);
    HFASSERT(fileDescriptor >= 0);
    if (length > LLONG_MAX) { //largest file we can make is LLONG_MAX, because off_t has type long long
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteOutOfSpaceError userInfo:nil];
        return NO;
    }
    int result = ftruncate(fileDescriptor, (off_t)length);
    HFASSERT(result <= 0);
    if (result < 0) {
	returnFTruncateError(error);
    }
    else {
        fileLength = length;
    }
    return result == 0;
}

@end

#ifndef HF_NO_PRIVILEGED_FILE_OPERATIONS
#import "HFPrivilegedHelperConnection.h"
@implementation HFPrivilegedFileReference

- (size_t)readAlignment {
    /* Returns the required alignment and block multiple for reads, or 0 if there is no required alignment */
    if (S_ISBLK(fileMode) || S_ISCHR(fileMode)) {
	return 512;
    }
    else {
	return 0;
    }
}

- (HFPrivilegedHelperConnection *)connection {
    return [HFPrivilegedHelperConnection sharedConnection];
}

- (BOOL)initSharedWithPath:(NSString *)path error:(NSError **)error {
    int result;
    REQUIRE_NOT_NULL(path);
    const char *p = [path fileSystemRepresentation];
    int localErrno = 0;
    if (! [[self connection] openFileAtPath:p writable:isWritable result:&fileDescriptor resultError:&localErrno fileSize:&fileLength fileType:&fileMode inode:&inode device:&device]) {
	returnFortunateSonError(error);
	return NO;
    }
    if (fileDescriptor < 0) {
	errno = localErrno;
	returnReadError(error);
	return NO;
    }
    return YES;
}

- (void)close {
    if (fileDescriptor >= 0) {
	[[self connection] closeFile:fileDescriptor];
        fileDescriptor = -1;
    }    
}

- (void)readBytes:(unsigned char *)buff length:(NSUInteger)length from:(unsigned long long)pos {
    if (! length) return;
    REQUIRE_NOT_NULL(buff);
    HFASSERT(length <= LONG_MAX);
    HFASSERT(pos <= fileLength);
    HFASSERT(length <= fileLength - pos);
    if (fileDescriptor < 0) [NSException raise:NSInvalidArgumentException format:@"File has already been closed."];
    
    /* Expand to multiples of readAlignment */
    NSUInteger alignment = [self readAlignment];
    HFASSERT(alignment > 0);
    
    /* The most we can read at once is UINT32_MAX (clipped to our alignment).  In the very unlikely case that length is larger than that, we loop. */
    NSUInteger remainingToRead = length;
    while (remainingToRead > 0) {
	uint32_t amountToRead = (uint32_t)MIN(remainingToRead, (UINT32_MAX / alignment) * alignment);
	uint32_t amountRead = amountToRead;
	int err = 0;
	[[self connection] readFile:fileDescriptor offset:pos alignment:alignment length:&amountRead result:buff error:&err];
	if (amountRead != amountToRead) {
	    [NSException raise:NSGenericException format:@"Read result: %u expected: %u error: %s", amountRead, amountToRead, strerror(err)];
	}
	buff += amountRead;
	pos = HFSum(pos, amountRead);
	remainingToRead -= amountRead;
    }
}

@end
#endif
