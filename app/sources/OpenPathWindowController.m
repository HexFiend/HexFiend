//
//  OpenPathWindowController.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "OpenPathWindowController.h"
#include <sys/stat.h>
#include <objc/message.h>

/* The key used to store the last "open path" path in userdefs */
#define kOpenPathDialogPathKey @"OpenPathDialogPathKey"

/* A key used to store the new URL for recovery suggestions for certain errors */
#define kNewURLErrorKey @"NewURL"

/* Recovery option indexes */
enum {
    eOpenCharacterFile,
    eCancel
};

@implementation OpenPathWindowController

- (NSString *)windowNibName {
    return @"OpenPathDialog";
}

static CFURLRef copyCharacterDevicePathForPossibleBlockDevice(NSURL *url) {
    if (! url) return NULL;
    CFURLRef result = nil;
    CFStringRef path = CFURLCopyFileSystemPath((CFURLRef)url, kCFURLPOSIXPathStyle);
    if (path) {
        char cpath[PATH_MAX + 1];
        if (CFStringGetFileSystemRepresentation(path, cpath, sizeof cpath)) {
            struct stat sb;
            if (stat(cpath, &sb)) {
                printf("stat('%s') returned error %d (%s)\n", cpath, errno, strerror(errno));
            }
            else if (S_ISBLK(sb.st_mode)) {
                /* It's a block file, so try getting the corresponding character file.  The device number that corresponds to this path is sb.st_rdev (not sb.st_dev, which is the device of this inode, which is the device filesystem itself) */
                char deviceName[PATH_MAX + 1] = {0};
                if (devname_r(sb.st_rdev, S_IFCHR, deviceName, sizeof deviceName)) {
                    /* We got the device name.  Prepend /dev/ and then return the URL */
                    char characterDevicePath[PATH_MAX + 1] = "/dev/";
                    size_t slen = strlcat(characterDevicePath, deviceName, sizeof characterDevicePath);
                    if (slen < sizeof characterDevicePath) {
                        result = CFURLCreateFromFileSystemRepresentation(NULL, (unsigned char *)characterDevicePath, slen, NO /* not a directory */);
                    }
                }
            }
        }
        CFRelease(path);
    }
    return result;
}


/* Error handling */
- (BOOL)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex {
    BOOL success = NO;
    switch (recoveryOptionIndex) {
        case eCancel:
            /* Simple */
            success = YES;
            break;
        case eOpenCharacterFile:
        {
            NSURL *newURL = [error userInfo][kNewURLErrorKey];
            if (newURL) {
                NSError *anotherError = nil;
                NSDocument *newDocument = [self openURL:newURL error:&anotherError];
                if (anotherError) [NSApp presentError:anotherError];
                success = !! newDocument;
            }
        }
            break;
        default:
            NSLog(@"Unknown error recovery option %ld", (long)recoveryOptionIndex);
            break;
    }
    return success;
}

- (void)attemptRecoveryFromError:(NSError *)error optionIndex:(NSUInteger)recoveryOptionIndex delegate:(id)delegate didRecoverSelector:(SEL)didRecoverSelector contextInfo:(void *)contextInfo {
    BOOL success = [self attemptRecoveryFromError:error optionIndex:recoveryOptionIndex];
    objc_msgSend(delegate, didRecoverSelector, success, contextInfo);
}


/* Given that a URL 'url' could not be opened because it referenced a block device, construct an error that offers to open the corresponding character device at 'newURL' */ 
- (NSError *)makeBlockToCharacterDeviceErrorForOriginalURL:(NSURL *)url newURL:(NSURL *)newURL underlyingError:(NSError *)underlyingError {
    NSError *result;
    @autoreleasepool {
    NSString *failureReason = NSLocalizedString(@"The file is busy.", @"Failure reason for opening a file that's busy");
    NSString *descriptionFormatString = NSLocalizedString(@"The file at path '%@' could not be opened because it is busy.", @"Error description for opening a file that's busy");
    NSString *recoverySuggestionFormatString = NSLocalizedString(@"Do you want to open the corresponding character device at path '%@'?", @"Recovery suggestion for opening a character device at a given path");
    NSString *recoveryOption = NSLocalizedString(@"Open character device", @"Recovery option for opening a character device at a given path");
    NSString *cancel = NSLocalizedString(@"Cancel", @"Cancel");
    
    NSString *description = [NSString stringWithFormat:descriptionFormatString, [url path]];
    NSString *recoverySuggestion = [NSString stringWithFormat:recoverySuggestionFormatString, [newURL path]];
    NSArray *recoveryOptions = @[recoveryOption, cancel];
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              failureReason, NSLocalizedFailureReasonErrorKey,
                              recoverySuggestion, NSLocalizedRecoverySuggestionErrorKey,
                              recoveryOptions, NSLocalizedRecoveryOptionsErrorKey,
                              underlyingError, NSUnderlyingErrorKey,
                              self, NSRecoveryAttempterErrorKey,
                              url, NSURLErrorKey,
                              [url path], NSFilePathErrorKey,
                              newURL, kNewURLErrorKey,
                              nil];
    result = [[NSError alloc] initWithDomain:NSPOSIXErrorDomain code:EBUSY userInfo:userInfo];
    
    [userInfo release];
    }
    return [result autorelease];
}

- (NSDocument *)openURL:(NSURL *)url error:(NSError **)error {
    /* Attempts to create an NSDocument for the given NSURL, and returns an error on failure */
    NSDocument *result = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:error];
    if (result) {
        /* The open succeeded, so close the window */
        [self close];
    }
    return result;
}

- (IBAction)openPathOKButtonClicked:(id)sender {
    USE(sender);
    NSString *path = [[pathField stringValue] stringByExpandingTildeInPath];
    if ([path length] > 0) {
        /* Try making the document */
        NSError *error = nil;
        NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
        id document = [self openURL:url error:&error];
        if (! document && error) {
            if ([[error domain] isEqual:NSPOSIXErrorDomain] && [error code] == EBUSY) {
                /* If this is a block device, try getting the corresponding character device, and offer to open that. */
                CFURLRef newURL = copyCharacterDevicePathForPossibleBlockDevice(url);
                if (newURL) {
                    error = [self makeBlockToCharacterDeviceErrorForOriginalURL:url newURL:(NSURL *)newURL underlyingError:error];
                    CFRelease(newURL);
                }
            }	    
            [NSApp presentError:error];
        }
    }
}

- (void)updateIcon:(NSImage *)icon {
    [iconView setImage:icon];
}

- (void)fetchIconOp:(NSString *)path {
    /* This is invoked off the main thread */
    @autoreleasepool {
    NSImage *result = nil;
    NSString *expandedPath = [path stringByExpandingTildeInPath];
    if ([expandedPath length] == 0) {
        result = nil;
    }
    else if ([[NSFileManager defaultManager] fileExistsAtPath:expandedPath]) {
        result = [[NSWorkspace sharedWorkspace] iconForFile:expandedPath];
    }
    [self performSelectorOnMainThread:@selector(updateIcon:) withObject:result waitUntilDone:NO];
    }
}

- (void)updateIconAndOKButtonEnabledState {
    [okButton setEnabled:[[pathField stringValue] length] > 0];
    if (operationQueue) {
        [operationQueue cancelAllOperations];
        NSOperation *fetchIconOp = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(fetchIconOp:) object:[pathField stringValue]];
        [operationQueue addOperation:fetchIconOp];
        [fetchIconOp release];
    }
}

- (void)controlTextDidChange:(NSNotification *)obj {
    if ([obj object] == pathField) {
        NSString *stringValue = [pathField stringValue];
        [[NSUserDefaults standardUserDefaults] setObject:stringValue forKey:kOpenPathDialogPathKey];
        [self updateIconAndOKButtonEnabledState];
    }
}

- (void)windowDidLoad {
    [super windowDidLoad];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs registerDefaults:@{kOpenPathDialogPathKey: @"/dev/disk0s1"}];
    [okButton setEnabled:[[pathField stringValue] length] > 0];
    NSString *value = [defs stringForKey:kOpenPathDialogPathKey];
    if (value) [pathField setStringValue:value];
    if (! operationQueue) {
        operationQueue = [[NSClassFromString(@"NSOperationQueue") alloc] init];
        [operationQueue setMaxConcurrentOperationCount:1];
    }
    [self updateIconAndOKButtonEnabledState];
}

- (void)dealloc {
    [operationQueue release];
    operationQueue = nil;
    [super dealloc];
}

@end
