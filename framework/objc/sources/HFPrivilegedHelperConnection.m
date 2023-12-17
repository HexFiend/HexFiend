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
#import <HexFiend/HFAssert.h>

#include "fileport.h"

@implementation HFPrivilegedHelperConnection

+ (instancetype)sharedConnection {
    static HFPrivilegedHelperConnection *shared = nil;
    if (!shared) shared = [[self alloc] init];
#if HF_NO_PRIVILEGED_FILE_OPERATIONS
    shared.disabled = YES;
#endif
    return shared;
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
    if(bytes) memcpy(bytes, resultData, (size_t)range.length);
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

- (BOOL)openFileAtPath:(const char *)path writable:(BOOL)writable fileDescriptor:(int *)outFD error:(NSError **)error
{
    if (! [self connectIfNecessary]) return NO;
	
	int err;
	fileport_t fd_port;

    kern_return_t kr = _GratefulFatherOpenFile([childReceiveMachPort machPort], path, writable, &fd_port, &err);

    if (kr != KERN_SUCCESS) {
        fprintf(stdout, "_GratefulFatherOpenFile failed with mach error: %s\n", (char*) mach_error_string(kr));
        return NO;
    }

	if (fd_port == MACH_PORT_NULL) {
		if (error)
			*error = [NSError errorWithDomain:NSPOSIXErrorDomain
										 code:err
									 userInfo:nil];
		return NO;
	}
	
	if (outFD)
		*outFD = fileport_makefd(fd_port);

	mach_port_deallocate(mach_task_self(), fd_port);

    return YES;    
}

- (BOOL)getInfo:(struct HFProcessInfo_t *)outInfo forProcess:(pid_t)process {
    HFASSERT(outInfo != NULL);
    if (![self connectIfNecessary]) return NO;
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
    if (self.disabled) return NO;
    if (childReceiveMachPort == nil) {
        NSError *oops = nil;
        if (! [self launchAndConnect:&oops]) {
            if (oops) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    @autoreleasepool {
                        HFASSERT_MAIN_THREAD();
                        NSAlert *alert = [[NSAlert alloc] init];
                        alert.messageText = NSLocalizedString(@"Failed to launch and connect helper.", "");
                        alert.informativeText = oops.localizedDescription;
                        (void)[alert runModal];
                    }
                });
            }
        }
    }
    return [childReceiveMachPort isValid];
}

- (BOOL)launchAndConnect:(NSError **)error {
    if (self.disabled) {
        if(error) *error = nil;
        return NO;
    }
    
    /* If we're already connected, we're done */
    if ([childReceiveMachPort isValid]) return YES;
    
    /* Guess not. This is probably the first connection. */
    [childReceiveMachPort invalidate];
    childReceiveMachPort = nil;
    int err = 0;
    
    /* Our label and port name happen to be the same */
    CFStringRef label = CFSTR("com.ridiculousfish.HexFiend.PrivilegedHelper");
    NSString *portName = @"com.ridiculousfish.HexFiend.PrivilegedHelper";
    
    /* Always remove the job if we've previously submitted it. This is to help with versioning (we always install the latest tool). It also avoids conflicts where the installed tool was signed with a different key (i.e. someone building Hex Fiend while also having run the signed distribution). A potentially negative consequence is that we have to authenticate every launch, but that is actually a benefit, because it serves as a sort of notification that user's action requires elevated privileges, instead of just (potentially silently) doing it. */
    BOOL helperIsAlreadyInstalled = NO;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    CFDictionaryRef existingJob = SMJobCopyDictionary(kSMDomainSystemLaunchd, label);
#pragma clang diagnostic pop
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
                *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadNoPermissionError userInfo:@{NSLocalizedDescriptionKey: description}];
            }
        }
	}
    
    /* Remove the existing helper. If this fails it's not a fatal error (SMJobBless can handle the case when a job is already installed). */
    if (! err && helperIsAlreadyInstalled) {
        CFErrorRef localError = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        SMJobRemove(kSMDomainSystemLaunchd, label, authRef, true /* wait */, &localError);
#pragma clang diagnostic pop
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
            if (error) *error = (__bridge_transfer NSError*)localError;
        }
	}
    
    /* Get the port for our helper as provided by launchd */
    NSMachPort *helperLaunchdPort = nil;
    if (! err) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        NSMachBootstrapServer *boots = [NSMachBootstrapServer sharedInstance];
#pragma clang diagnostic pop
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
    if (! err) {
		childReceiveMachPort = [[NSMachPort alloc] initWithMachPort:ourSendPort options:NSMachPortDeallocateSendRight];
	
		/* Pass over our authorization reference. */
		AuthorizationExternalForm authExt;
		AuthorizationMakeExternalForm(authRef, &authExt);

		_GratefulFatherSetAuthorization([childReceiveMachPort machPort], authExt);
	}
	
    /* Done with any AuthRef */
    if (authRef) AuthorizationFree(authRef, kAuthorizationFlagDestroyRights);

    /* Done with helperLaunchdPort */
    [helperLaunchdPort invalidate];
	return ! err;
}

@end
