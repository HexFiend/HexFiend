//
//  BaseDocument.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HexFiend.h>
#import "DocumentWindow.h"

@class HFByteArray, HFRepresenter, HFHexTextRepresenter, HFLineCountingRepresenter, HFLayoutRepresenter, HFDocumentOperationView, DataInspectorRepresenter;
@class HFBinaryTemplateRepresenter;
@class HFColumnRepresenter;
@class HFBinaryTextRepresenter;

extern NSString * const BaseDataDocumentDidChangeStringEncodingNotification;

@interface BaseDataDocument : NSDocument <NSWindowDelegate, DragDropDelegate> {
    IBOutlet NSView *containerView;
    HFController *controller;
    
    HFColumnRepresenter *columnRepresenter;
    HFLineCountingRepresenter *lineCountingRepresenter;
    HFBinaryTextRepresenter *binaryRepresenter;
    HFHexTextRepresenter *hexRepresenter;
    HFRepresenter *asciiRepresenter;
    HFRepresenter *scrollRepresenter;
    HFRepresenter *textDividerRepresenter;
    HFLayoutRepresenter *layoutRepresenter;
    DataInspectorRepresenter *dataInspectorRepresenter;
    HFStatusBarRepresenter *statusBarRepresenter;
    HFBinaryTemplateRepresenter *binaryTemplateRepresenter;

    NSResponder *savedFirstResponder;
    
    HFDocumentOperationView *operationView;
    
    HFDocumentOperationView *findReplaceView;
    HFDocumentOperationView *moveSelectionByView;
    HFDocumentOperationView *jumpToOffsetView;
    HFDocumentOperationView *saveView;
    NSTimer *showSaveViewAfterDelayTimer;
    
    BOOL bannerIsShown;
    BOOL bannerGrowing;
    NSView *bannerView;
    NSTimer *bannerResizeTimer;
    CGFloat bannerTargetHeight;
    CFAbsoluteTime bannerStartTime;
    id targetFirstResponderInBanner;
    dispatch_block_t commandToRunAfterBannerIsDoneHiding;
    dispatch_block_t commandToRunAfterBannerPrepared;
    
    BOOL saveInProgress;
    
    BOOL currentlySettingFont;
    BOOL isTransient;
    
    BOOL shouldLiveReload;
    NSDate *liveReloadDate;
    NSTimer *liveReloadTimer;
    
    NSUInteger cleanGenerationCount;

    BOOL loadingWindow;
    BOOL hideTextDividerOverride;
}

- (void)moveSelectionForwards:(NSMenuItem *)sender;
- (void)extendSelectionForwards:(NSMenuItem *)sender;
- (void)jumpToOffset:(NSMenuItem *)sender;

- (IBAction)moveSelectionByAction:(id)sender;

@property (nonatomic, copy) NSFont *font;
- (void)setFont:(NSFont *)font registeringUndo:(BOOL)undo;

- (IBAction)increaseFontSize:(id)sender;
- (IBAction)decreaseFontSize:(id)sender;

- (NSWindow *)window;

- (IBAction)showFontPanel:sender;
- (IBAction)setColorBytesFromMenuItem:sender;

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
- (IBAction)customByteGrouping:(id)sender;
- (IBAction)setLineNumberFormat:(id)sender;
- (IBAction)setByteThemeFromMenuItem:(NSMenuItem *)sender;

- (IBAction)setBookmark:sender;
- (IBAction)deleteBookmark:sender;

+ (HFByteArray *)byteArrayfromURL:(NSURL *)absoluteURL error:(NSError **)outError;
- (HFByteArray *)byteArray; //accessed during diffing

- (BOOL)isTransientAndCanBeReplaced; //like TextEdit
- (void)adoptWindowController:(NSWindowController *)windowController fromTransientDocument:(BaseDataDocument *)transientDocument;

- (NSArray *)copyBookmarksMenuItems;

- (HFDocumentOperationView *)newOperationViewForNibName:(NSString *)name displayName:(NSString *)displayName;
- (void)prepareBannerWithView:(HFDocumentOperationView *)newSubview withTargetFirstResponder:(id)targetFirstResponder;
- (void)hideBannerFirstThenDo:(dispatch_block_t)command;
- (NSArray *)runningOperationViews;

@property (nonatomic) HFStringEncoding *stringEncoding;
- (IBAction)setStringEncodingFromMenuItem:(NSMenuItem *)item;

@property (nonatomic, getter=isTransient) BOOL transient;

/* Returns a string identifier used as an NSUserDefault prefix for storing the layout for documents of this type.  If you return nil, the layout will not be stored.  The default is to return the class name. */
+ (NSString *)layoutUserDefaultIdentifier;

- (BOOL)requiresOverwriteMode;

@property (nonatomic) BOOL shouldLiveReload;
- (IBAction)setLiveReloadFromMenuItem:sender;

- (void)insertData:(NSData *)data;

- (void)lineCountingRepCycledLineNumberFormat:(NSNotification*)note;
- (void)columnRepresenterViewHeightChanged:(NSNotification *)note;
- (void)lineCountingViewChangedWidth:(NSNotification *)note;
- (void)dataInspectorChangedRowCount:(NSNotification *)note;
- (void)dataInspectorDeletedAllRows:(NSNotification *)note;

- (BOOL)setByteGrouping:(NSUInteger)newBytesPerColumn;

- (BOOL)shouldSaveWindowState;

@end
