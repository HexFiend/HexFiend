//
//  MyDocumentController.m
//  HexFiend_2
//
//  Created by Peter Ammon on 9/11/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "MyDocumentController.h"
#include <sys/stat.h>

@implementation MyDocumentController

- (void)noteNewRecentDocumentURL:(NSURL *)absoluteURL {
    /* Work around the fact that LS crashes trying to fetch icons for block and character devices.  Let's just prevent it for all files that aren't normal or directories, heck. */
    BOOL callSuper = YES;
    unsigned char path[PATH_MAX + 1];
    struct stat sb;
    if (absoluteURL && CFURLGetFileSystemRepresentation((CFURLRef)absoluteURL, YES, path, sizeof path) && 0 == stat((char *)path, &sb)) {
	if (! S_ISREG(sb.st_mode) && ! S_ISDIR(sb.st_mode)) {
	    callSuper = NO;
	}
    }
    if (callSuper) {
	[super noteNewRecentDocumentURL:absoluteURL];
    }
}

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <errno.h>
#include <paths.h>
#include <sys/param.h>
#include <IOKit/IOKitLib.h>
#include <IOKit/IOBSD.h>
#include <IOKit/storage/IOCDMedia.h>
#include <IOKit/storage/IOStorage.h>
#include <IOKit/storage/IOMedia.h>
#include <IOKit/storage/IOCDTypes.h>
#include <IOKit/storage/IOMediaBSDClient.h>
#include <IOKit/storage/IOBlockStorageDevice.h>
#include <IOKit/IOCFPlugIn.h>
#include <sys/param.h>
#include <sys/mount.h>

kern_return_t MyFindEjectableCDMedia( io_iterator_t *mediaIterator )
{
    mach_port_t         masterPort;
    kern_return_t       kernResult;
    CFMutableDictionaryRef   classesToMatch;
    
    kernResult = IOMasterPort( MACH_PORT_NULL, &masterPort );
    if ( kernResult != KERN_SUCCESS )
    {
        printf( "IOMasterPort returned %d\n", kernResult );
        return kernResult;
    }
    
    // CD media are instances of class kIOCDMediaClass.
    classesToMatch = IOServiceMatching( kIOBlockStorageDeviceClass );
    if ( classesToMatch == NULL )
        printf( "IOServiceMatching returned a NULL dictionary.\n" );
    else
    {
        // Each IOMedia object has a property with key kIOMediaEjectableKey
        // which is true if the media is indeed ejectable. So add this
        // property to the CFDictionary for matching.
        CFDictionarySetValue( classesToMatch,
			     CFSTR( kIOMediaEjectableKey ), kCFBooleanTrue );
    }
    kernResult = IOServiceGetMatchingServices( masterPort,
					      classesToMatch, mediaIterator );
    if ( (kernResult != KERN_SUCCESS) || (*mediaIterator == NULL) )
        printf( "No ejectable CD media found.\n kernResult = %d\n",
	       kernResult );
    return kernResult;
}


kern_return_t MyGetDeviceFilePath( io_iterator_t mediaIterator,
				  char *deviceFilePath, CFIndex maxPathSize )
{
    io_object_t nextMedia;
    kern_return_t kernResult = KERN_FAILURE;
    
    *deviceFilePath = '\0';
    nextMedia = IOIteratorNext( mediaIterator );
    while ( nextMedia )
    {
	
	CFMutableDictionaryRef dict = NULL;
	IORegistryEntryCreateCFProperties(nextMedia, &dict, NULL, 0);
	NSLog(@"%@", dict);
	
        CFTypeRef   deviceFilePathAsCFString;
        deviceFilePathAsCFString = IORegistryEntryCreateCFProperty(
								   nextMedia, CFSTR( kIOBSDNameKey ),
								   kCFAllocatorDefault, 0 );
	
//	IOCreatePlugInInterfaceForService(nextMedia, <#CFUUIDRef pluginType#>, <#CFUUIDRef interfaceType#>, <#IOCFPlugInInterface ***theInterface#>, <#SInt32 *theScore#>)
	
	
	NSLog(@"Path: %@", deviceFilePathAsCFString);
	
	*deviceFilePath = '\0';
        if ( deviceFilePathAsCFString )
        {
            size_t devPathLength;
            strcpy( deviceFilePath, _PATH_DEV );
            // Add "r" before the BSD node name from the I/O Registry
            // to specify the raw disk node. The raw disk node receives
            // I/O requests directly and does not go through the
            // buffer cache.
            strcat( deviceFilePath, "r");
            devPathLength = strlen( deviceFilePath );
            if ( CFStringGetCString( deviceFilePathAsCFString,
				    deviceFilePath + devPathLength,
				    maxPathSize - devPathLength,
				    kCFStringEncodingASCII ) )
            {
                printf( "BSD path: %s\n", deviceFilePath );
                kernResult = KERN_SUCCESS;
            }
            CFRelease( deviceFilePathAsCFString );
        }
	nextMedia = IOIteratorNext( mediaIterator );
    }
    IOObjectRelease( nextMedia );
    
    return kernResult;
}


- (void)doStuff {
    struct statfs buf = {0};
    statfs("/Users/peter/BigFile.data", &buf);
    printf("f_mntfromname: %s\n", buf.f_mntfromname);
    char path[PATH_MAX + 1] = {0};
    
    struct stat buf2 = {0};
    stat("/Users/peter/BigFile.data", &buf2);
    devname_r(buf2.st_dev, S_IFCHR, path, sizeof path);
    printf("EXPECTED DEVICE: %d\n", buf2.st_dev);
    printf("devname_r: %s\n", path);
    return;
    
    io_iterator_t mediaIterator;
    char deviceFilePath[ MAXPATHLEN ] = {0};
    kern_return_t kr = MyFindEjectableCDMedia(&mediaIterator);
    NSLog(@"kr: %d", kr);
    kr = MyGetDeviceFilePath(mediaIterator, deviceFilePath, sizeof deviceFilePath);
    NSLog(@"kr2: %d", kr);
    printf("Path: %s\n", deviceFilePath);
}

- (void)doOtherStuff {

    
}

- (id)init {
    [super init];
    [self doStuff];
    [self doOtherStuff];
    return self;
}


@end
