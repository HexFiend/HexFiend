//
//  AppDelegate.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HexFiend.h>

NS_ASSUME_NONNULL_BEGIN

@class ChooseStringEncodingWindowController;
@class CLIController;
@class DiffRangeWindowController;
@class HFByteTheme;

@interface AppDelegate : NSObject {
    IBOutlet NSMenuItem *extendForwardsItem, *extendBackwardsItem;
    IBOutlet NSMenuItem *fontMenuItem;
    IBOutlet NSMenuItem *fontListPlaceholderMenuItem;
    IBOutlet NSMenuItem *processListMenuItem;
    IBOutlet NSMenu *bookmarksMenu;
    IBOutlet NSMenuItem *noBookmarksMenuItem;
    NSArray *bookmarksMenuItems;
    IBOutlet NSMenu *stringEncodingMenu;
    IBOutlet NSMenuItem *byteGroupingMenuItem;
    IBOutlet NSMenuItem *byteThemeMenuItem;
    IBOutlet CLIController *cliController; // unused, prevents leak
}

@property (class, readonly) AppDelegate *shared;

- (IBAction)diffFrontDocuments:(id)sender;
- (IBAction)diffFrontDocumentsByRange:(id)sender;

- (IBAction)setStringEncodingFromMenuItem:(NSMenuItem *)item;
- (void)setStringEncoding:(HFStringEncoding *)encoding;

- (IBAction)openPreferences:(id)sender;

@property (readonly) HFStringEncoding *defaultStringEncoding;

@property NSArray<NSNumber *> *menuSystemEncodingsNumbers;

@property (readonly) NSDictionary<NSString *, HFByteTheme *> *byteThemes;

- (void)buildByteGroupingMenu;
- (void)buildByteThemeMenu;

@end

NS_ASSUME_NONNULL_END
