//
//  HFPrivilegedHelperConnection.m
//  HexFiend_2
//
//  Created by Peter Ammon on 7/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "HFPrivilegedHelperConnection.h"
#import "HFHelperProcessSharedCode.h"
#import "FortunateSon.h"

static HFPrivilegedHelperConnection *sSharedConnection;

struct inheriting_fork_return_t {
    pid_t child_pid;
    mach_port_t child_recv_port;
};
static struct inheriting_fork_return_t fork_with_inherit(const char *path);

@implementation HFPrivilegedHelperConnection

+ (HFPrivilegedHelperConnection *)sharedConnection {
    if (! sSharedConnection) {
        sSharedConnection = [[self alloc] init];
    }
    return sSharedConnection;
}

- (id)init {
    [super init];
    
    return self;
}

static NSString *read_line(FILE *file) {
    NSMutableString *result = nil;
    char buffer[256];
    BOOL done = NO;
    while (done == NO && fgets(buffer, sizeof buffer, file)) {
        char *endPtr = strchr(buffer, '\n');
        if (endPtr) {
            *endPtr = '\0';
            done = YES;
        }
        if (! result) {
            result = [NSMutableString stringWithUTF8String:buffer];
        }
        else {
            CFStringAppendCString((CFMutableStringRef)result, buffer, kCFStringEncodingUTF8);
        }
    }
    return result;
}

- (BOOL)readBytes:(void *)bytes range:(HFRange)range process:(pid_t)process error:(NSError **)error {
    HFASSERT(range.length <= ULONG_MAX);
    HFASSERT(bytes != NULL || range.length > 0);
    if (! [self connectIfNecessary]) return NO;
    void *resultData = NULL;
    mach_msg_type_number_t resultCnt;
    
    kern_return_t kr = _GratefulFatherReadProcess(childReceivePort, process, range.location, range.length, (unsigned char **)&resultData, &resultCnt);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherReadProcess failed with mach error: %s\n", (char*) mach_error_string(kr));
        if (error) *error = nil;
        return NO;
    }
    memcpy(bytes, resultData, (size_t)range.length);
    kr = vm_deallocate(mach_task_self(), (vm_address_t)resultData, resultCnt);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "failed to vm_deallocate(%p) for pid %d\nmach error: %s\n", resultData, process, (char*) mach_error_string(kr));
    }
    return YES;
}

- (BOOL)getAttributes:(VMRegionAttributes *)outAttributes length:(unsigned long long *)outLength offset:(unsigned long long)offset process:(pid_t)process error:(NSError **)error {
    if (! [self connectIfNecessary]) return NO;
    VMRegionAttributes atts = 0;
    mach_vm_size_t length = 0;
    kern_return_t kr = _GratefulFatherAttributesForAddress(childReceivePort, process, offset, &atts, &length);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherAttributesForAddress failed with mach error: %s\n", (char*) mach_error_string(kr));
        if (error) *error = nil;
        return NO;
    }
    if (outAttributes) *outAttributes = atts;
    if (outLength) *outLength = length;
    return YES;
}

- (BOOL)openFileAtPath:(const char *)path writable:(BOOL)writable result:(int *)outFD resultError:(int *)outErrno fileSize:(unsigned long long *)outFileSize fileType:(uint16_t *)outFileType inode:(unsigned long long *)outInode device:(int *)outDevice {
    if (! [self connectIfNecessary]) return NO;
    HFASSERT(outFD && outErrno && outFileSize && outFileType && outInode && outDevice);
    kern_return_t kr = _GratefulFatherOpenFile(childReceivePort, path, writable, outFD, outErrno, outFileSize, outFileType, outInode, outDevice);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherOpenFile failed with mach error: %s\n", (char*) mach_error_string(kr));
        return NO;
    }
    return YES;
}

- (BOOL)closeFile:(int)fd {
    HFASSERT(fd > 0);
    if (! [self connectIfNecessary]) return NO;
    kern_return_t kr = _GratefulFatherCloseFile(childReceivePort, fd);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherCloseFile failed with mach error: %s\n", (char*) mach_error_string(kr));
        return NO;
    }    
    return YES;
}

- (BOOL)readFile:(int)fd offset:(unsigned long long)requestedOffset alignment:(uint32_t)alignment length:(uint32_t *)inoutLength result:(unsigned char *)result error:(int *)outErr {
    HFASSERT(inoutLength);
    HFASSERT(alignment > 0);
    if (! *inoutLength) return YES;
    if (! [self connectIfNecessary]) return NO;
    unsigned char * buffer = NULL;
    const uint32_t requestedLength = *inoutLength;    
    
    /* Expand to multiples of alignment */
    unsigned long long end = HFSum(requestedOffset, requestedLength);
    unsigned long long alignedStart = requestedOffset - requestedOffset % alignment, alignedEnd = HFRoundUpToMultiple(end, alignment);
    HFASSERT(alignedEnd > alignedStart);
    HFASSERT(alignedEnd - alignedStart >= requestedLength);
    HFRange alignedRange = HFRangeMake(alignedStart, alignedEnd - alignedStart);
    HFASSERT(alignedRange.length < UINT_MAX); //there's no reason for this to necessarily be true - we just require the app to not pass us buffers that are so close to UINT_MAX that they overflow when aligned
    
    uint32_t alignedLength = (uint32_t)alignedRange.length;
    mach_msg_type_number_t bufferAllocatedSize = 0;
    NSLog(@"Issuing read %llu / %u", alignedRange.location, alignedLength);
    kern_return_t kr = _GratefulFatherReadFile(childReceivePort, fd, alignedRange.location, &alignedLength, &buffer, &bufferAllocatedSize, outErr);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherReadFile failed with mach error: %s\n", (char*) mach_error_string(kr));
        return NO;
    }
    if (! buffer) return NO; // paranoia
    
    
    /* Buffer now contains mach allocated memory that we own.  Copy it over to the result, handling the alignment, and then free it. */
    uint32_t realAmountCopied = alignedLength;
    NSUInteger prefix = ll2l(requestedOffset - alignedRange.location);
    unsigned long long realBufferEnd = HFSum(alignedRange.location, realAmountCopied);
    if (realBufferEnd <= requestedOffset) {
        /* The only stuff that got copied was in the prefix */
        *inoutLength = 0;
    }
    else {
        /* Add alignedRange.location to amountCopied to get the true end of the buffer, and subtract pos to get the range from position to the end of the buffer, then take the smaller of that with the amount desired to get the amount to copy to the buffer. */
        *inoutLength = (uint32_t)MIN(realBufferEnd - requestedOffset, requestedLength);
        memcpy(result, buffer + prefix, *inoutLength);
    }
    
    if (buffer) {
        kr = vm_deallocate(mach_task_self(), (vm_address_t)buffer, bufferAllocatedSize);
        if (kr != KERN_SUCCESS) {
            fprintf(stdout, "failed to vm_deallocate(%p)\nmach error: %s\n", buffer, (char *)mach_error_string(kr));
        }
    }
    
    return YES;
}

- (BOOL)getInfo:(struct HFProcessInfo_t *)outInfo forProcess:(pid_t)process {
    HFASSERT(outInfo != NULL);
    if (! [self connectIfNecessary]) return NO;
    uint8_t bitSize = 0;
    kern_return_t kr = _GratefulFatherProcessInfo(childReceivePort, process, &bitSize);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherProcessInfo failed with mach error: %s\n", (char*) mach_error_string(kr));
        return NO;
    }
    outInfo->bits = bitSize;
    return YES;
}

- (BOOL)connectIfNecessary {
    if (childReceivePort == MACH_PORT_NULL) {
        [self launchAndConnect];
    }
    return childReceivePort != MACH_PORT_NULL;
}

- (BOOL)launchAndConnect {
    BOOL result = YES;
    NSBundle *bund = [NSBundle bundleForClass:[self class]];
    NSString *helperPath = [bund pathForResource:@"FortunateSon" ofType:@""];
    NSString *privilegedHelperPath = nil;
    if (! helperPath) {
        [NSException raise:NSInternalInconsistencyException format:@"Couldn't find FortunateSon helper tool in bundle %@", bund];
    }
    NSString *launcherPath = [bund pathForResource:@"FortunateSonCopier" ofType:@""];
    if (! launcherPath) {
        [NSException raise:NSInternalInconsistencyException format:@"Couldn't find FortunateSonCopier helper tool in bundle %@", bund];
    }
    
    OSStatus status;
    
    AuthorizationRef authorizationRef = NULL;
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    result = result && (status == noErr);
    
    if (result) {
        AuthorizationItem authItems = { kAuthorizationRightExecute, 0, NULL, 0};
        AuthorizationRights authRights = {1, &authItems};
        
        AuthorizationFlags authFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
        
        status = AuthorizationCopyRights(authorizationRef, &authRights, NULL, authFlags, NULL);
        if (status != errAuthorizationSuccess) {
            result = NO;
            if (status != errAuthorizationCanceled && status != errAuthorizationDenied) {
                NSLog(@"AuthorizationCopyRights returned error: %ld", (long)status);
            }
        }
    }
    
    FILE *pipe = NULL;
    if (result) {
        const char *launcherPathCString = [launcherPath fileSystemRepresentation];
        const char * const arguments[] = {[helperPath fileSystemRepresentation], NULL};
        OSStatus authorizationResult = AuthorizationExecuteWithPrivileges(authorizationRef, launcherPathCString, 0, (char * const *)arguments, &pipe);
        
        if (authorizationResult != errAuthorizationSuccess) {
            NSLog(@"AuthorizationExecuteWithPrivileges %s returned error: %ld (%lx)", launcherPathCString, (long)authorizationResult, (long)authorizationResult);
            result = NO;
        }
    }
    
    if (result) {
        privilegedHelperPath = read_line(pipe);
        NSString *error = read_line(pipe);
        if ([error length] > 0) {
            NSLog(@"Error: %@", error);
            result = NO;
        }
        else if (! [privilegedHelperPath length]) {
            NSLog(@"Unable to get path");
            result = NO;
        }
    }
    
    if (result) {
        /* Launch the path */
        const char *pathToLaunch = [privilegedHelperPath fileSystemRepresentation];
        struct inheriting_fork_return_t fork_return = fork_with_inherit(pathToLaunch);
        childReceivePort = fork_return.child_recv_port;
        printf("CHILD PID: %d\n", fork_return.child_pid);
    }
    
    /* Tell our launcher, OK, so it deletes it for us */
    if (pipe) fputs("OK\n", pipe);
    
    return result;
}

+ (void)UNUSEDload {
    id pool = [[NSAutoreleasePool alloc] init];
    [self performSelector:@selector(test:) withObject:nil afterDelay:.1];
    [pool release];
}

+ (void)test:unused {
    USE(unused);
    HFPrivilegedHelperConnection *helper = [HFPrivilegedHelperConnection sharedConnection];
    [helper launchAndConnect];
}

@end

// We need to weak-import posix_spawn and friends as they're not available on Tiger.
// The BSD-level system headers do not have availability macros, so we redeclare the
// functions ourselves with the "weak" attribute.

#define WEAK_IMPORT __attribute__((weak))
#define POSIX_SPAWN_SETEXEC 0x0040
typedef void *posix_spawnattr_t;
typedef void *posix_spawn_file_actions_t;
int posix_spawnattr_init(posix_spawnattr_t *) WEAK_IMPORT;
int posix_spawn(pid_t * __restrict, const char * __restrict, const posix_spawn_file_actions_t *, const posix_spawnattr_t * __restrict, char *const __argv[ __restrict], char *const __envp[ __restrict]) WEAK_IMPORT;
int posix_spawnattr_setbinpref_np(posix_spawnattr_t * __restrict, size_t, cpu_type_t *__restrict, size_t *__restrict) WEAK_IMPORT;
int posix_spawnattr_setflags(posix_spawnattr_t *, short) WEAK_IMPORT;

extern char ***_NSGetEnviron(void);

static struct inheriting_fork_return_t fork_with_inherit(const char *path) {
    struct inheriting_fork_return_t result = {-1, -1};
    const struct inheriting_fork_return_t errorReturn = {-1, -1};
    kern_return_t       err;
    mach_port_t         parent_recv_port = MACH_PORT_NULL;
    mach_port_t         child_recv_port = MACH_PORT_NULL;
    
    if (setup_recv_port(&parent_recv_port) != 0)
        return errorReturn;
#if MESS_WITH_BOOTSTRAP_PORT
    CHECK_MACH_ERROR(task_set_bootstrap_port(mach_task_self(), parent_recv_port));
#else
    // register a port with launchd
    char ipc_name[256];
    derive_ipc_name(ipc_name, getpid());
    mach_port_t bp = MACH_PORT_NULL;
    task_get_bootstrap_port(mach_task_self(), &bp);
    CHECK_MACH_ERROR(bootstrap_register(bp, ipc_name, parent_recv_port));
#endif
    
    char * argv[] = {(char *)path, NULL};
    int posixErr = posix_spawn(&result.child_pid, path, NULL/*file actions*/, NULL/*spawn attr*/, argv, *_NSGetEnviron());
    if (posixErr != 0) {
        printf("posix_spawn failed: %d %s\n", posixErr, strerror(posixErr));
        return errorReturn;
    }
    
#if MESS_WITH_BOOTSTRAP_PORT
    CHECK_MACH_ERROR(task_set_bootstrap_port(mach_task_self (), bootstrap_port));
#endif
    
    /* talk to the child */
    if (recv_port(parent_recv_port, &child_recv_port) != 0)
        return errorReturn;
    
#if MESS_WITH_BOOTSTRAP_PORT
    if (send_port(child_recv_port, bootstrap_port, MACH_MSG_TYPE_COPY_SEND) != 0)
        return errorReturn;
    CHECK_MACH_ERROR(mach_port_deallocate (mach_task_self(), parent_recv_port));

#else
    /* Note: this is one of those weird cases where we really really do want to destroy the Mach port (not simply decrement its refcount. This is what allows us to unregister it. */
    CHECK_MACH_ERROR(mach_port_destroy (mach_task_self(), parent_recv_port));
    /* since we got the child port, we can unregister our launchd service */
    CHECK_MACH_ERROR(bootstrap_register(bp, ipc_name, MACH_PORT_NULL));
#endif
    
    int val;
    _GratefulFatherSayHey(child_recv_port, "From Daddy", &val);
    printf("Daddy got back Val: %d\n", val);
    
    result.child_recv_port = child_recv_port;
    return result;
}
