//
//  AppDelegate.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface AppDelegate : NSObject {
    IBOutlet NSMenuItem *extendForwardsItem, *extendBackwardsItem;
    IBOutlet NSMenuItem *fontMenuItem;
    IBOutlet NSMenuItem *processListMenuItem;
    IBOutlet NSMenu *bookmarksMenu;
    IBOutlet NSMenuItem *noBookmarksMenuItem;
    NSArray *bookmarksMenuItems;
    IBOutlet NSMenu *stringEncodingMenu;
}

- (IBAction)diffFrontDocuments:(id)sender;
- (IBAction)diffFrontDocumentsByRange:(id)sender;

- (IBAction)setStringEncodingFromMenuItem:(NSMenuItem *)item;
- (void)setStringEncoding:(NSStringEncoding)encoding;

@end
