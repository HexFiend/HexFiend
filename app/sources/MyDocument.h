//
//  MyDocument.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFRepresenter, HFLineCountingRepresenter, HFLayoutRepresenter, HFFindReplaceRepresenter, HFDocumentOperationView, DataInspectorRepresenter;

@interface MyDocument : NSDocument {
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

- (void)setFont:(NSFont *)font;
- (NSFont *)font;

- (IBAction)showFontPanel:sender;
- (IBAction)setAntialiasFromMenuItem:sender;

- (IBAction)findNext:sender;
- (IBAction)findPrevious:sender;
- (IBAction)replaceAndFind:sender;
- (IBAction)replace:sender;
- (IBAction)replaceAll:sender;

- (IBAction)toggleOverwriteMode:sender;
- (IBAction)modifyByteGrouping:sender;

@end
