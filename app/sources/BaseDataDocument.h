//
//  MyDocument.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFByteArray, HFRepresenter, HFLineCountingRepresenter, HFLayoutRepresenter, HFFindReplaceRepresenter, HFDocumentOperationView, DataInspectorRepresenter;

@interface BaseDataDocument : NSDocument {
    IBOutlet NSSplitView *containerView;
    HFController *controller;
    
    HFLineCountingRepresenter *lineCountingRepresenter;
    HFRepresenter *hexRepresenter;
    HFRepresenter *asciiRepresenter;
    HFRepresenter *scrollRepresenter;
    HFLayoutRepresenter *layoutRepresenter;
    DataInspectorRepresenter *dataInspectorRepresenter;
    HFStatusBarRepresenter *statusBarRepresenter;
    NSResponder *savedFirstResponder;
    
    HFDocumentOperationView *operationView;
    
    HFDocumentOperationView *findReplaceView;
    HFDocumentOperationView *moveSelectionByView;
    HFDocumentOperationView *jumpToOffsetView;
    HFDocumentOperationView *saveView;
    NSTimer *showSaveViewAfterDelayTimer;
    
    BOOL bannerIsShown;
    BOOL bannerGrowing;
    BOOL willRemoveBannerIfSufficientlyShortAfterDrag;
    NSView *bannerView;
    NSView *bannerDividerThumb;
    NSTimer *bannerResizeTimer;
    CGFloat bannerTargetHeight;
    CFAbsoluteTime bannerStartTime;
    id targetFirstResponderInBanner;
    SEL commandToRunAfterBannerIsDoneHiding;
    
    BOOL saveInProgress;
    NSInteger saveResult;
    NSError *saveError;
    
    BOOL currentlySettingFont;
}

- (void)moveSelectionForwards:(NSMenuItem *)sender;
- (void)extendSelectionForwards:(NSMenuItem *)sender;
- (void)jumpToOffset:(NSMenuItem *)sender;

- (IBAction)moveSelectionByAction:(id)sender;

- (void)setFont:(NSFont *)font registeringUndo:(BOOL)undo;
- (NSFont *)font;

- (IBAction)increaseFontSize:(id)sender;
- (IBAction)decreaseFontSize:(id)sender;

- (NSWindow *)window;

- (IBAction)showFontPanel:sender;
- (IBAction)setAntialiasFromMenuItem:sender;

- (IBAction)findNext:sender;
- (IBAction)findPrevious:sender;
- (IBAction)replaceAndFind:sender;
- (IBAction)replace:sender;
- (IBAction)replaceAll:sender;

- (IBAction)toggleOverwriteMode:sender;
- (IBAction)modifyByteGrouping:sender;

- (IBAction)setBookmark:sender;
- (IBAction)deleteBookmark:sender;

- (HFByteArray *)byteArray; //accessed during diffing

- (void)populateBookmarksMenu:(NSMenu *)menu;

/* Returns a string identifier used as an NSUserDefault prefix for storing the layout for documents of this type.  If you return nil, the layout will not be stored.  The default is to return the class name. */
+ (NSString *)layoutUserDefaultIdentifier;

@end
