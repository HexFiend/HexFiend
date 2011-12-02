//
//  HFPrivilegedHelperConnection.m
//  HexFiend_2
//
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

/* Since the SMJobBless() API requires that the helper live in the app's bundle and plist (grr) this should be factored so that the app provides the interface to the framework. */

#import "HFPrivilegedHelperConnection.h"
#import "HFHelperProcessSharedCode.h"
#import "FortunateSon.h"
#import <ServiceManagement/ServiceManagement.h>
#import <Security/Authorization.h>

static HFPrivilegedHelperConnection *sSharedConnection;

@implementation HFPrivilegedHelperConnection

+ (HFPrivilegedHelperConnection *)sharedConnection {
    if (! sSharedConnection) {
        sSharedConnection = [[self alloc] init];
    }
    return sSharedConnection;
}

- (id)init {
    self = [super init];
    
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
    
    mach_port_t childReceivePort = [childReceiveMachPort machPort];
    
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
    kern_return_t kr = _GratefulFatherAttributesForAddress([childReceiveMachPort machPort], process, offset, &atts, &length);
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
    kern_return_t kr = _GratefulFatherOpenFile([childReceiveMachPort machPort], path, writable, outFD, outErrno, outFileSize, outFileType, outInode, outDevice);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherOpenFile failed with mach error: %s\n", (char*) mach_error_string(kr));
        return NO;
    }
    return YES;
}

- (BOOL)closeFile:(int)fd {
    HFASSERT(fd > 0);
    if (! [self connectIfNecessary]) return NO;
    kern_return_t kr = _GratefulFatherCloseFile([childReceiveMachPort machPort], fd);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherCloseFile failed with mach error: %s\n", (char*) mach_error_string(kr));
        return NO;
    }    
    return YES;
}

- (BOOL)readFile:(int)fd offset:(unsigned long long)requestedOffset alignment:(uint32_t)alignment length:(uint32_t *)inoutLength result:(unsigned char *)result error:(int *)outErr {
    BOOL log = NO;
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
    if (log) NSLog(@"Issuing read %llu / %u", alignedRange.location, alignedLength);
    kern_return_t kr = _GratefulFatherReadFile([childReceiveMachPort machPort], fd, alignedRange.location, &alignedLength, &buffer, &bufferAllocatedSize, outErr);
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
    kern_return_t kr = _GratefulFatherProcessInfo([childReceiveMachPort machPort], process, &bitSize);
    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherProcessInfo failed with mach error: %s\n", (char*) mach_error_string(kr));
        return NO;
    }
    outInfo->bits = bitSize;
    return YES;
}

- (BOOL)connectIfNecessary {
    if (childReceiveMachPort == nil) {
        NSError *oops = nil;
        if (! [self launchAndConnect:&oops]) {
            if (oops) [NSApp presentError:oops];
        }
    }
    return [childReceiveMachPort isValid];
}

- (BOOL)launchAndConnect:(NSError **)error {
    /* If we're already connected, we're done */
    if ([childReceiveMachPort isValid]) return YES;
    
    /* Guess not. This is probably the first connection. */
    [childReceiveMachPort invalidate];
    [childReceiveMachPort release];
    childReceiveMachPort = nil;
    int err = 0;
    
    /* Our label and port name happen to be the same */
    CFStringRef label = CFSTR("com.ridiculousfish.HexFiend.PrivilegedHelper");
    NSString *portName = @"com.ridiculousfish.HexFiend.PrivilegedHelper";
    
    /* Always remove the job if we've previously submitted it. This is to help with versioning (we always install the latest tool). It also avoids conflicts where the installed tool was signed with a different key (i.e. someone building Hex Fiend while also having run the signed distribution). A potentially negative consequence is that we have to authenticate every launch, but that is actually a benefit, because it serves as a sort of notification that user's action requires elevated privileges, instead of just (potentially silently) doing it. */
    BOOL helperIsAlreadyInstalled = NO;
    CFDictionaryRef existingJob = SMJobCopyDictionary(kSMDomainSystemLaunchd, label);
    if (existingJob) {
        helperIsAlreadyInstalled = YES;
        CFRelease(existingJob);
    }
    
    /* Decide what rights to authorize with. If the helper is not installed, we only need the privileged helper; if it is installed we need ModifySystemDaemons too, to uninstall it. */
	AuthorizationItem authItems[2] = {{ kSMRightBlessPrivilegedHelper, 0, NULL, 0 }, { kSMRightModifySystemDaemons, 0, NULL, 0 }};
	AuthorizationRights authRights = { (helperIsAlreadyInstalled ? 2 : 1), authItems };
	AuthorizationFlags flags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
	AuthorizationRef authRef = NULL;
	
	/* Now authorize. */
	err = AuthorizationCreate(&authRights, kAuthorizationEmptyEnvironment, flags, &authRef);
	if (err != errAuthorizationSuccess) {
        if (error) {
            if (err == errAuthorizationCanceled) {
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
            } else {
                NSString *description = [NSString stringWithFormat:@"Failed to create AuthorizationRef (error code %ld).", (long)err];
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoPermissionError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:description, NSLocalizedDescriptionKey, nil]];
            }
        }
	}
    
    /* Remove the existing helper. If this fails it's not a fatal error (SMJobBless can handle the case when a job is already installed). */
    if (! err && helperIsAlreadyInstalled) {
        CFErrorRef localError = NULL;
        SMJobRemove(kSMDomainSystemLaunchd, label, authRef, true /* wait */, &localError);
        if (localError) {
            NSLog(@"SMJobRemove() failed with error %@", localError);
            CFRelease(localError);
        }
    }
    
    /* Bless the job */
    if (! err) {
        CFErrorRef localError = NULL;
		err = ! SMJobBless(kSMDomainSystemLaunchd, label, authRef, (CFErrorRef *)&localError);
        if (localError) {
            if (error) *error = [[(id)localError retain] autorelease];
            CFRelease(localError);
        }
	}
    
    /* Done with any AuthRef */
    if (authRef) AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);
	
    /* Get the port for our helper as provided by launchd */
    NSMachPort *helperLaunchdPort = nil;
    if (! err) {
        NSMachBootstrapServer *boots = [NSMachBootstrapServer sharedInstance];
        helperLaunchdPort = (NSMachPort *)[boots portForName:portName];
        err = ! [helperLaunchdPort isValid];
    }
    
    /* Create our own port, and give it a send right */
    mach_port_t ourSendPort = MACH_PORT_NULL;
    if (! err) err = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &ourSendPort);
    if (! err) err = mach_port_insert_right(mach_task_self(), ourSendPort, ourSendPort, MACH_MSG_TYPE_MAKE_SEND);
    
    /* Tell our privileged helper about it, moving the receive right over */
    if (! err) err = send_port([helperLaunchdPort machPort], ourSendPort, MACH_MSG_TYPE_MOVE_RECEIVE);
    
    /* Now we have the ability to send on this port, and only the privileged helper can receive on it. We are responsible for cleaning up the send right we created. */
    if (! err) childReceiveMachPort = [[NSMachPort alloc] initWithMachPort:ourSendPort options:NSMachPortDeallocateSendRight];
    
    /* Done with helperLaunchdPort */
    [helperLaunchdPort invalidate];
	return ! err;
}

@end

