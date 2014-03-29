//
//  OpenDriveWindowController.h
//  HexFiend_2
//
//  Created by Richard D. Guzman on 1/8/12.
//  Copyright (c) 2012 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <DiskArbitration/DiskArbitration.h>

@interface OpenDriveWindowController : NSWindowController
{
	IBOutlet NSTableView * table;
	NSButton * selectButton;
	NSButton * cancelButton;
	NSMutableArray * driveList;
}

- (IBAction) selectDrive:(id) sender;
- (IBAction) cancelDriveSelection:sender;

- (NSDocument *)openURL:(NSURL *)url error:(NSError **)error;

@end
