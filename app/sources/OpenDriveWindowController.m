//
//  OpenDriveWindowController.m
//  HexFiend_2
//
//  Created by Richard D. Guzman on 1/8/12.
//  Copyright (c) 2012 ridiculous_fish. All rights reserved.
//

#import "OpenDriveWindowController.h"
#include <sys/stat.h>
#include <objc/message.h>

void * refSelf;

static inline BOOL isRunningOnLeopardOrLater(void) {
    return NSAppKitVersionNumber >= 949;
}

/* The key used to store the last "open path" path in userdefs */
#define kOpenPathDialogPathKey @"OpenPathDialogPathKey"

/* A key used to store the new URL for recovery suggestions for certain errors */
#define kNewURLErrorKey @"NewURL"

/* Recovery option indexes */
enum {
    eOpenCharacterFile,
    eCancel
};

@implementation OpenDriveWindowController (TableView)

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	if(tableView)
	{}
	return [driveList count];
}


- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)col row:(int)rowIndex
{
	if(tableView)
	{}
	
    NSString * temp = [col identifier];
    NSDictionary * tempDrive = (NSDictionary*)[driveList objectAtIndex:rowIndex];
    NSString * returnString = 0;
    [returnString autorelease];
    if([temp isEqualToString:@"BSD Name"])
    {
        returnString = [tempDrive objectForKey:(NSString*)kDADiskDescriptionMediaBSDNameKey];
    }
    else if([temp isEqualToString:@"Bus"])
    {
        returnString = (NSString*)[tempDrive objectForKey:(NSString*)kDADiskDescriptionBusNameKey];
    }
    else if([temp isEqualToString:@"Label"])
    {
         returnString = (NSString*)[tempDrive objectForKey:(NSString*)kDADiskDescriptionVolumeNameKey];
    }
    return returnString;
}

@end

@implementation OpenDriveWindowController

-(id)init
{	
	return [super initWithWindowNibName:@"OpenDriveDialog"];
}

- (void)dealloc
{
    [operationQueue release];
    operationQueue = nil;
    [super dealloc];
}

- (NSString *)windowNibName 
{
    return @"OpenDriveDialog";
}

- (void) awakeFromNib
{
	refSelf = self;
	//[table setDelegate:self];
	timer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:0.1 target:self selector:@selector(reloadData) userInfo:nil repeats:FALSE];
	[NSThread detachNewThreadSelector:@selector(refreshDriveList) toTarget:self withObject:nil];
    
	//[self window];
}



void addDisk(DADiskRef disk, void * context)
{
    USE(context);
	if(DADiskCopyDescription(disk))
	{
        [(id)refSelf addToDriveList:((NSDictionary*)DADiskCopyDescription(disk))];
	}
}

void removeDisk(DADiskRef disk, void * context)
{
	if(context)
        printf("disk %s disappeared\n", DADiskGetBSDName(disk));
}

- (void)refreshDriveList
{	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	DASessionRef session;
    
    session = DASessionCreate(kCFAllocatorDefault);
    
    if(driveList == nil)
    {
        driveList = [[NSMutableArray alloc] init];
    }
    else 
    {
        [driveList 	removeAllObjects];
    }
    
    DARegisterDiskAppearedCallback(session, NULL, addDisk, self); 
    DARegisterDiskDisappearedCallback(session, NULL, removeDisk, NULL);
    
    DASessionScheduleWithRunLoop(session, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
    
    CFRunLoopRun();
    
    CFRelease(session);
    [pool drain];
}

- (IBAction) selectDrive:sender
{
    if(sender)
    {}
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
    NSError *result;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *failureReason = NSLocalizedString(@"The file is busy.", @"Failure reason for opening a file that's busy");
    NSString *descriptionFormatString = NSLocalizedString(@"The file at path '%@' could not be opened because it is busy.", @"Error description for opening a file that's busy");
    NSString *recoverySuggestionFormatString = NSLocalizedString(@"Do you want to open the corresponding character device at path '%@'?", @"Recovery suggestion for opening a character device at a given path");
    NSString *recoveryOption = NSLocalizedString(@"Open character device", @"Recovery option for opening a character device at a given path");
    NSString *cancel = NSLocalizedString(@"Cancel", @"Cancel");
    
    NSString *description = [NSString stringWithFormat:descriptionFormatString, [url path]];
    NSString *recoverySuggestion = [NSString stringWithFormat:recoverySuggestionFormatString, [newURL path]];
    NSArray *recoveryOptions = [NSArray arrayWithObjects:recoveryOption, cancel, nil];
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
    [pool drain];
    return [result autorelease];
}



- (void) selectDrive
{
	if([table numberOfSelectedRows] == 1)
	{
        NSMutableString * path = [NSMutableString stringWithString:@"/dev/"];
        NSDictionary * tempDrive = (NSDictionary*)[driveList objectAtIndex:[table selectedRow]];
        [path appendString:(NSString*)[tempDrive objectForKey:(NSString*)kDADiskDescriptionMediaBSDNameKey]];
        if ([path length] > 0) 
        {
            /* Try making the document */
            NSError *error = nil;
            NSURL *url = [NSURL fileURLWithPath:path isDirectory:NO];
            id document = [self openURL:url error:&error];
            if (! document && error) 
            {
                if ([[error domain] isEqual:NSPOSIXErrorDomain] && [error code] == EBUSY) 
                {
                    /* If this is a block device, try getting the corresponding character device, and offer to open that. */
                    CFURLRef newURL = copyCharacterDevicePathForPossibleBlockDevice(url);
                    if (newURL) 
                    {
                        error = [self makeBlockToCharacterDeviceErrorForOriginalURL:url newURL:(NSURL *)newURL underlyingError:error];
                        CFRelease(newURL);
                    }
                }	    
                [NSApp presentError:error];
            }
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
            NSURL *newURL = [[error userInfo] objectForKey:kNewURLErrorKey];
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


- (NSDocument *)openURL:(NSURL *)url error:(NSError **)error {
    /* Attempts to create an NSDocument for the given NSURL, and returns an error on failure */
    NSDocument *result = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:url display:YES error:error];
    if (result) {
        /* The open succeeded, so close the window */
        [self close];
    }
    return result;
}



- (IBAction) cancelDriveSelection:sender
{
	if(sender)
	{}
	[self closeOpenDriveWindow];
}

- (void) closeOpenDriveWindow
{
	[self close];
}

- (void) addToDriveList:(NSDictionary*)dict
{
	[driveList addObject:dict];
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(reloadData:) userInfo:nil repeats:NO];
	
}

- (void) reloadData:(NSTimer*)theTimer
{
    if(theTimer)
    {}
	[table reloadData];
}


@end
