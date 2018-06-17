//
//  AppDelegate.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class ChooseStringEncodingWindowController;

@interface AppDelegate : NSObject {
    IBOutlet NSMenuItem *extendForwardsItem, *extendBackwardsItem;
    IBOutlet NSMenuItem *fontMenuItem;
    IBOutlet NSMenuItem *processListMenuItem;
    IBOutlet NSMenu *bookmarksMenu;
    IBOutlet NSMenuItem *noBookmarksMenuItem;
    NSArray *bookmarksMenuItems;
    IBOutlet NSMenu *stringEncodingMenu;
    IBOutlet ChooseStringEncodingWindowController *chooseStringEncoding;
}

- (IBAction)diffFrontDocuments:(id)sender;
- (IBAction)diffFrontDocumentsByRange:(id)sender;

- (IBAction)setStringEncodingFromMenuItem:(NSMenuItem *)item;
- (void)setStringEncoding:(HFStringEncoding *)encoding;

- (IBAction)openPreferences:(id)sender;

@property (readonly) HFStringEncoding *defaultStringEncoding;

@end
