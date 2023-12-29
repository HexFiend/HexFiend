//
//  HFFileReference.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFileReference.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/disk.h>

static HFPrivilegedHelperShared privilegedHelperCallback;

@interface HFConcreteFileReference : HFFileReference
@end

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
    NSDictionary *errorDict = @{NSLocalizedFailureReasonErrorKey: errorDescription};
    *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:errorDict];
    return NO;
}

static BOOL isFileTypeSupported(mode_t mode) {
    /* We support regular and block file types */
    return S_ISREG(mode) || S_ISBLK(mode) || S_ISCHR(mode);
}

static BOOL isFileTypeWritable(mode_t mode) {
    /* We only support writing to regular files */
    return S_ISREG(mode) || S_ISBLK(mode) || S_ISCHR(mode);
}

static BOOL returnFTruncateError(NSError **error) {
    if (error) {
        int posixCode = errno;
        NSInteger cocoaCode = 0;
        switch (posixCode) {
            case ENOSPC:	cocoaCode = NSFileWriteOutOfSpaceError; break;
            case EROFS:		cocoaCode = NSFileWriteVolumeReadOnlyError; break;
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

/* Modifies F_NOCACHE for a given file descriptor */
static void HFSetFDShouldCache(int fd, BOOL shouldCache) {
    int result = fcntl(fd, F_NOCACHE, !shouldCache);
    if (result == -1) {
        int err = errno;
        NSLog(@"fcntl(%d, F_NOCACHE, %d) returned error %d: %s", fd, !shouldCache, err, strerror(err));
    }
}

@implementation HFFileReference {
@protected
    int fileDescriptor;
    dev_t device;
    unsigned long long inode;
    unsigned long long fileLength;
    mode_t fileMode;
    BOOL isWritable;
    uint32_t blockSize;
    BOOL isPrivileged;
    BOOL isFixedLength;
}

@synthesize isPrivileged, isFixedLength;

- (void)close { UNIMPLEMENTED_VOID(); }
- (void)readBytes:(unsigned char *)buff length:(NSUInteger)length from:(unsigned long long)offset {USE(buff); USE(length); USE(offset); UNIMPLEMENTED_VOID(); }
- (int)writeBytes:(const unsigned char *)buff length:(NSUInteger)length to:(unsigned long long)offset {USE(buff); USE(length); USE(offset);  UNIMPLEMENTED(); }
- (BOOL)setLength:(unsigned long long)length error:(NSError **)error { USE(length); USE(error); UNIMPLEMENTED(); }

- (unsigned long long)length {
    return fileLength;
}

/* Must be overridden - do not call super */
- (BOOL)initSharedWithPath:(NSString *)path error:(NSError **)error { USE(path); USE(error); UNIMPLEMENTED(); }

- (NSUInteger)hash {
    return (NSUInteger)inode;
}

- (BOOL)isEqual:(id)val {
    if (! [val isKindOfClass:[HFFileReference class]]) return NO;
    HFFileReference *ref = (HFFileReference *)val;
    return ref->device == device && ref->inode == inode;
}

+ (instancetype)allocWithZone:(NSZone *)zone {
    if (self == [HFFileReference class]) {
        /* Default to HFConcreteFileReference */
        return [HFConcreteFileReference allocWithZone:zone];
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

- (instancetype)initWithPath:(NSString *)path error:(NSError **)error {
    self = [super init];
    isWritable = NO;
    fileDescriptor = -1;
    if (! ([self initSharedWithPath:path error:error] && [self validateWithError:error])) {
        [self close];
        self = nil;
    }
    return self;
}

- (instancetype)initWritableWithPath:(NSString *)path error:(NSError **)error{
    self = [super init];
    isWritable = YES;
    fileDescriptor = -1;
    if (! ([self initSharedWithPath:path error:error] && [self validateWithError:error])) {
        [self close];
        self = nil;
    }
    return self;
}

- (void)dealloc {
    [self close];
}

+ (void)setPrivilegedHelperShared:(HFPrivilegedHelperShared)callback {
    privilegedHelperCallback = [callback copy];
}

@end

@implementation HFConcreteFileReference

- (BOOL)initSharedWithPath:(NSString *)path error:(NSError **)error {
    REQUIRE_NOT_NULL(path);
    const char* p = [path fileSystemRepresentation];
    if (isWritable) {
        fileDescriptor = open(p, O_RDWR | O_CREAT, 0644);
    }
    else {
        fileDescriptor = open(p, O_RDONLY, 0);
    }

	if (fileDescriptor < 0 && errno == EACCES) {
		if (privilegedHelperCallback && [privilegedHelperCallback() openFileAtPath:p writable:isWritable fileDescriptor:&fileDescriptor error:error]) {
            isPrivileged = YES;
        } else {
			fileDescriptor = -1; 
			errno = EACCES;
		}
	}

    if (fileDescriptor < 0) {
        returnReadError(error);
        return NO;
    }

    struct stat sb;
    const int result = fstat(fileDescriptor, &sb);

    if (result != 0) {
        int err = errno;
        returnReadError(error);
        NSLog(@"Unable to fstat file %@. %s.", path, strerror(err));
        return NO;
    }

    if (isPrivileged && !sb.st_size && (S_ISCHR(sb.st_mode) || S_ISBLK(sb.st_mode))) {
        uint64_t blockCount;

        if (ioctl(fileDescriptor, DKIOCGETBLOCKSIZE, &blockSize) < 0
            || ioctl(fileDescriptor, DKIOCGETBLOCKCOUNT, &blockCount) < 0) {
            int err = errno;
            returnReadError(error);
            NSLog(@"Unable to get block size/count file %@. %s.", path, strerror(err));
            return NO;
        }
        
        fileLength = blockSize * blockCount;
        isFixedLength = YES;
    }
    else {
        fileLength = sb.st_size;
    }

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

	NSUInteger lastBlockLen = 0;
	void *tempBuf = NULL;

    @try {
        if (S_ISCHR(fileMode) && blockSize) {
            // We have to make sure all accesses are aligned
            unsigned prePad = (unsigned)(pos % blockSize);
            if (prePad) {
                // Deal with the first unaligned block
                tempBuf = malloc(blockSize);
                ssize_t result = pread(fileDescriptor, tempBuf, blockSize, pos - prePad);
                if (result != (ssize_t)blockSize) {
                    [NSException raise:NSGenericException format:@"Read result: %zd expected: %u error: %s", result, blockSize, strerror(errno)];
                }
                NSUInteger toCopy = blockSize - prePad;
                if (toCopy > length)
                    toCopy = length;
                memcpy(buff, tempBuf + prePad, toCopy);
                length -= toCopy;
                pos += toCopy;
                buff += toCopy;
            }
            lastBlockLen = length % blockSize;
            length -= lastBlockLen;
        }
        
        ssize_t result = pread(fileDescriptor, buff, length, pos);
        if (result != (long)length) {
            [NSException raise:NSGenericException format:@"Read result: %zd expected: %lu error: %s", result, (unsigned long)length, strerror(errno)];
        }
        
        if (lastBlockLen) {
            if (!tempBuf)
                tempBuf = malloc(blockSize);
            result = pread(fileDescriptor, tempBuf, blockSize, pos + length);
            if (result != (ssize_t)blockSize) {
                [NSException raise:NSGenericException format:@"Read result: %zd expected: %u error: %s", result, blockSize, strerror(errno)];
            }
            memcpy(buff + length, tempBuf, lastBlockLen);
        }

    }
    @finally {
        free (tempBuf);
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

	NSUInteger lastBlockLen = 0;
	void *tempBuf = NULL;
	
    @try {
        if (S_ISCHR(fileMode) && blockSize) {
            // We have to make sure all accesses are aligned
            unsigned prePad = (unsigned)(offset % blockSize);
            if (prePad) {
                // Deal with the first unaligned block
                tempBuf = malloc(blockSize);
                ssize_t result = pread(fileDescriptor, tempBuf, blockSize, offset - prePad);
                if (result != (ssize_t)blockSize) {
                    [NSException raise:NSGenericException format:@"Read result: %zd expected: %u error: %s", result, blockSize, strerror(errno)];
                }
                NSUInteger toCopy = blockSize - prePad;
                if (toCopy > length)
                    toCopy = length;
                memcpy(tempBuf + prePad, buff, toCopy);
                
                result = pwrite(fileDescriptor, tempBuf, blockSize, offset - prePad);
                if (result < 0)
                    return errno;
                HFASSERT(result == (ssize_t)blockSize);
                
                if (!(length -= toCopy))
                    return 0;
                
                offset += toCopy;
                buff += toCopy;
            }
            lastBlockLen = length % blockSize;
            length -= lastBlockLen;
        }
        
        ssize_t result = pwrite(fileDescriptor, buff, (size_t)length, (off_t)offset);
        if (result < 0)
            return errno;
        HFASSERT(result == (ssize_t)length);
        
        if (lastBlockLen) {
            offset += length;
            buff += length;
            
            if (!tempBuf)
                tempBuf = malloc(blockSize);
            
            result = pread(fileDescriptor, tempBuf, blockSize, offset);
            if (result != (ssize_t)blockSize) {
                [NSException raise:NSGenericException format:@"Read result: %zd expected: %u error: %s", result, blockSize, strerror(errno)];
            }
            memcpy(tempBuf, buff, lastBlockLen);
            
            result = pwrite(fileDescriptor, tempBuf, blockSize, offset);
            if (result < 0)
                return errno;
            HFASSERT(result == (ssize_t)blockSize);
        }
        
        return 0;
    }
    @finally {
        free(tempBuf);
    }
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
