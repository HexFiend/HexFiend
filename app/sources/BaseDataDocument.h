//
//  MyDocument.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DocumentWindow.h"

@class HFByteArray, HFRepresenter, HFLineCountingRepresenter, HFLayoutRepresenter, HFDocumentOperationView, DataInspectorRepresenter;

NSString * const BaseDataDocumentDidChangeStringEncodingNotification;

@interface BaseDataDocument : NSDocument <NSWindowDelegate, DragDropDelegate> {
    IBOutlet NSSplitView *containerView;
    HFController *controller;
    
    HFLineCountingRepresenter *lineCountingRepresenter;
    HFRepresenter *hexRepresenter;
    HFRepresenter *asciiRepresenter;
    HFRepresenter *scrollRepresenter;
    HFRepresenter *textDividerRepresenter;
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
    
    BOOL currentlySettingFont;
    BOOL isTransient;    
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
- (IBAction)performFindReplaceActionFromSelectedSegment:(id)sender;

- (IBAction)setOverwriteMode:sender;
- (IBAction)setInsertMode:sender;
- (IBAction)setReadOnlyMode:sender;
- (IBAction)modifyByteGrouping:sender;

- (IBAction)setBookmark:sender;
- (IBAction)deleteBookmark:sender;

- (HFByteArray *)byteArray; //accessed during diffing

- (BOOL)isTransientAndCanBeReplaced; //like TextEdit
- (void)adoptWindowController:(NSWindowController *)windowController fromTransientDocument:(BaseDataDocument *)transientDocument;

- (void)populateBookmarksMenu:(NSMenu *)menu;

- (HFDocumentOperationView *)newOperationViewForNibName:(NSString *)name displayName:(NSString *)displayName fixedHeight:(BOOL)fixedHeight;
- (void)prepareBannerWithView:(HFDocumentOperationView *)newSubview withTargetFirstResponder:(id)targetFirstResponder;
- (void)hideBannerFirstThenDo:(SEL)command;
- (NSArray *)runningOperationViews;

- (NSStringEncoding)stringEncoding;
- (void)setStringEncoding:(NSStringEncoding)encoding;
- (IBAction)setStringEncodingFromMenuItem:(NSMenuItem *)item;

- (BOOL)isTransient;
- (void)setTransient:(BOOL)flag;

/* Returns a string identifier used as an NSUserDefault prefix for storing the layout for documents of this type.  If you return nil, the layout will not be stored.  The default is to return the class name. */
+ (NSString *)layoutUserDefaultIdentifier;

- (BOOL)requiresOverwriteMode;

@end
