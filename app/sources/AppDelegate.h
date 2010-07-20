//
//  AppDelegate.h
//  HexFiend_2
//
//  Created by Peter Ammon on 4/1/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppDelegate : NSObject {
    IBOutlet NSMenuItem *extendForwardsItem, *extendBackwardsItem;
    IBOutlet NSMenuItem *fontMenuItem;
    IBOutlet NSMenuItem *processListMenuItem;
    IBOutlet NSMenu *bookmarksMenu;
}


- (IBAction)openProcess:(id)sender; //queries the user for a process and opens it
- (IBAction)openProcessByProcessMenuItem:(id)sender; //opens a process from a menu item that directly represents that process

- (void)openDiffFromFile:(NSString *)leftPath toFile:(NSString *)rightPath;
- (IBAction)diffFrontDocuments:(id)sender;

@end
