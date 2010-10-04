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

@end
