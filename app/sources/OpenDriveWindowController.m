//
//  OpenDriveWindowController.m
//  HexFiend_2
//
//  Created by Richard D. Guzman on 1/8/12.
//  Copyright (c) 2012 ridiculous_fish. All rights reserved.
//

#import "OpenDriveWindowController.h"
#import "AppUtilities.h"
#include <sys/stat.h>

/* A key used to store the new URL for recovery suggestions for certain errors */
#define kNewURLErrorKey @"NewURL"

/* Macro to specify functions and function parameters as unused. */
#define UNUSED __attribute__((unused))

/* Recovery option indexes */
enum {
    eOpenCharacterFile,
    eCancel
};

@interface NSDictionary (DiskArbHelpers)
- (NSString *)bsdName;
@end

@implementation NSDictionary (DiskArbHelpers)
- (NSString *)bsdName
{
    return self[(id)kDADiskDescriptionMediaBSDNameKey];
}
@end

@implementation OpenDriveWindowController (TableView)

- (NSInteger)numberOfRowsInTableView:(NSTableView *)UNUSED tableView
{
	return [driveList count];
}

- (id)tableView:(NSTableView *)UNUSED tableView objectValueForTableColumn:(NSTableColumn *)col row:(int)rowIndex
{
    NSString * temp = [col identifier];
    NSDictionary * tempDrive = driveList[rowIndex];
    NSString * returnString = nil;
    if([temp isEqualToString:@"BSD Name"])
    {
        returnString = [tempDrive bsdName];
    }
    else if([temp isEqualToString:@"Bus"])
    {
        returnString = tempDrive[(id)kDADiskDescriptionBusNameKey];
    }
    else if([temp isEqualToString:@"Label"])
    {
        NSNumber *whole = tempDrive[(id)kDADiskDescriptionMediaWholeKey];
        if (whole && [whole boolValue]) {
            returnString = tempDrive[(id)kDADiskDescriptionMediaNameKey];
        } else {
            returnString = tempDrive[(id)kDADiskDescriptionVolumeNameKey];
        }
    }
    return returnString;
}

@end

@interface OpenDriveWindowController (Private)

- (void) addToDriveList:(NSDictionary*)dict;
- (void)removeDrive:(NSString *)bsdName;

- (void) refreshDriveList;
- (void) selectDrive;

@end

@implementation OpenDriveWindowController

-(instancetype)init
{	
	if ((self = [super initWithWindowNibName:@"OpenDriveDialog"]) != nil) {
        driveList = [[NSMutableArray alloc] init];
        [NSThread detachNewThreadSelector:@selector(refreshDriveList) toTarget:self withObject:nil];
    }
    return self;
}

- (NSString *)windowNibName
{
    return @"OpenDriveDialog";
}

- (void)awakeFromNib
{
    table.doubleAction = @selector(selectDrive:);
    table.target = self;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    // Hide Open Drive if we are sandboxed
    if ([menuItem action] == @selector(showWindow:) && isSandboxed()) {
        [menuItem setHidden:YES];
        return NO;
    }
    return YES;
}

static void addDisk(DADiskRef disk, UNUSED void * context)
{
    @autoreleasepool {
        NSDictionary *diskDesc = (__bridge_transfer NSDictionary*)DADiskCopyDescription(disk);
        if (diskDesc) {
            // Don't add disks that represent a network volume
            NSNumber *isNetwork = diskDesc[(id)kDADiskDescriptionVolumeNetworkKey];
            if (!isNetwork || ![isNetwork boolValue]) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [(__bridge OpenDriveWindowController*)context addToDriveList:diskDesc];
                });
            }
        }
    }
}

static void removeDisk(DADiskRef disk, void * context)
{
    @autoreleasepool {
        const char *bsdName = DADiskGetBSDName(disk);
        NSString *nsbsdName = bsdName ? @(bsdName) : @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            [(__bridge OpenDriveWindowController*)context removeDrive:nsbsdName];
        });
    }
}

- (void)refreshDriveList
{
    @autoreleasepool {
        CFRunLoopRef runLoop = CFRunLoopGetCurrent();
        DASessionRef session = DASessionCreate(kCFAllocatorDefault);
        DARegisterDiskAppearedCallback(session, NULL, addDisk, (__bridge void*)self);
        DARegisterDiskDisappearedCallback(session, NULL, removeDisk, (__bridge void*)self);
        DASessionScheduleWithRunLoop(session, runLoop, kCFRunLoopDefaultMode);
        CFRunLoopRun();
        DASessionUnscheduleFromRunLoop(session, runLoop, kCFRunLoopDefaultMode);
        DAUnregisterCallback(session, removeDisk, (__bridge void*)self);
        DAUnregisterCallback(session, addDisk, (__bridge void*)self);
        CFRelease(session);
    }
}

- (IBAction) selectDrive:(UNUSED id)sender
{
	[self selectDrive];
}

static CFURLRef copyCharacterDevicePathForPossibleBlockDevice(NSURL *url) 
{
    if (! url) return NULL;
    CFURLRef result = nil;
    CFStringRef path = CFURLCopyFileSystemPath((CFURLRef)url, kCFURLPOSIXPathStyle);
    if (path) 
    {
        char cpath[PATH_MAX + 1];
        if (CFStringGetFileSystemRepresentation(path, cpath, sizeof cpath)) 
        {
            struct stat sb;
            if (stat(cpath, &sb)) 
            {
                printf("stat('%s') returned error %d (%s)\n", cpath, errno, strerror(errno));
            }
            else if (S_ISBLK(sb.st_mode)) 
            {
                /* It's a block file, so try getting the corresponding character file.  The device number that corresponds to this path is sb.st_rdev (not sb.st_dev, which is the device of this inode, which is the device filesystem itself) */
                char deviceName[PATH_MAX + 1] = {0};
                if (devname_r(sb.st_rdev, S_IFCHR, deviceName, sizeof deviceName)) 
                {
                    /* We got the device name.  Prepend /dev/ and then return the URL */
                    char characterDevicePath[PATH_MAX + 1] = "/dev/";
                    size_t slen = strlcat(characterDevicePath, deviceName, sizeof characterDevicePath);
                    if (slen < sizeof characterDevicePath) 
                    {
                        result = CFURLCreateFromFileSystemRepresentation(NULL, (unsigned char *)characterDevicePath, slen, NO /* not a directory */);
                    }
                }
            }// end else if
        }// end if
        CFRelease(path);
    }// end if
    return result;
}

/* Given that a URL 'url' could not be opened because it referenced a block device, construct an error that offers to open the corresponding character device at 'newURL' */ 
- (NSError *)makeBlockToCharacterDeviceErrorForOriginalURL:(NSURL *)url newURL:(NSURL *)newURL underlyingError:(NSError *)underlyingError 
{
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
    return [NSError errorWithDomain:NSPOSIXErrorDomain code:EBUSY userInfo:userInfo];
}

- (void) selectDrive
{
	if([table numberOfSelectedRows] == 1)
	{
        NSMutableString * path = [NSMutableString stringWithString:@"/dev/"];
        NSDictionary * tempDrive = (NSDictionary*)driveList[[table selectedRow]];
        [path appendString:(NSString*)tempDrive[(NSString*)kDADiskDescriptionMediaBSDNameKey]];
        if ([path length] > 0) 
        {
            /* Try making the document */
            NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
            [self openURL:url completionHandler:^(NSDocument *document, NSError *error) {
                if (! document && error)
                {
                    if ([[error domain] isEqual:NSPOSIXErrorDomain] && [error code] == EBUSY) 
                    {
                        /* If this is a block device, try getting the corresponding character device, and offer to open that. */
                        CFURLRef newURL = copyCharacterDevicePathForPossibleBlockDevice(url);
                        if (newURL) 
                        {
                            error = [self makeBlockToCharacterDeviceErrorForOriginalURL:url newURL:(__bridge NSURL *)newURL underlyingError:error];
                            CFRelease(newURL);
                        }
                    }	    
                    [NSApp presentError:error];
                }
            }];
        }
	}
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
                [self openURL:newURL completionHandler:^(NSDocument * __unused document, NSError *anotherRrror) {
                    if (anotherRrror) [NSApp presentError:anotherRrror];
                }];
                success = YES; // openURL is async, so we can't tell if it succeeded, so fake success
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
    const BOOL success = [self attemptRecoveryFromError:error optionIndex:recoveryOptionIndex];

    NSInvocation *invoke = [NSInvocation invocationWithMethodSignature:
                                   [delegate methodSignatureForSelector:didRecoverSelector]];
    [invoke setSelector:didRecoverSelector];
    [invoke setArgument:(void *)&success atIndex:2];
    [invoke setArgument:&contextInfo atIndex:3];
    [invoke invokeWithTarget:delegate];
}

- (void)openURL:(NSURL *)url completionHandler:(OpenURLCompletionHandler)completionHandler {
    /* Attempts to create an NSDocument for the given NSURL */
    [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument * _Nullable document, BOOL __unused documentWasAlreadyOpen, NSError * _Nullable error) {
        if (document) {
            /* The open succeeded, so close the window */
            [self close];
        }
        completionHandler(document, error);
    }];
}

- (IBAction) cancelDriveSelection:(UNUSED id)sender
{
	[self close];
}

- (void) addToDriveList:(NSDictionary*)dict
{
	[driveList addObject:dict];
    NSSortDescriptor *sorter = [[NSSortDescriptor alloc] initWithKey:(NSString*)kDADiskDescriptionMediaBSDNameKey ascending:YES];
    [driveList sortUsingDescriptors:@[sorter]];
    [table reloadData];
}

- (void)removeDrive:(NSString *)bsdName
{
    NSMutableArray *drivesToRemove = [NSMutableArray array];
    for (NSDictionary *dict in driveList) {
        if ([[dict bsdName] isEqualToString:bsdName]) {
            [drivesToRemove addObject:dict];
        }
    }
    [driveList removeObjectsInArray:drivesToRemove];
    [table reloadData];
}

@end
