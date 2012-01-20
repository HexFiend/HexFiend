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
	//id delegate;
	NSMutableArray * driveList;
	NSTimer * timer;
    id operationQueue;
}

- (IBAction) selectDrive:(id) sender;
- (IBAction) cancelDriveSelection:sender;

- (void) addToDriveList:(NSDictionary*)dict;

- (void) refreshDriveList;
- (void) closeOpenDriveWindow;
- (void) reloadData:(NSTimer*)theTimer;
- (void) selectDrive;

- (NSDocument *)openURL:(NSURL *)url error:(NSError **)error;

@end

@interface OpenDriveWindowController (TableView)

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView;
- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)col row:(int)rowIndex;
//- (void)tableView:(NSTableView *)tableView setObjectVallue:(id)object forTableColumn:(NSTableColumn *) tableColumn row:(int) rowIndex;
//- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;

@end