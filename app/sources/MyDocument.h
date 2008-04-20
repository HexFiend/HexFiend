//
//  MyDocument.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFRepresenter, HFLineCountingRepresenter, HFLayoutRepresenter, HFFindReplaceRepresenter, HFDocumentOperationView;

@interface MyDocument : NSDocument {
    IBOutlet NSSplitView *containerView;
    HFController *controller;
    
    HFLineCountingRepresenter *lineCountingRepresenter;
    HFRepresenter *hexRepresenter;
    HFRepresenter *asciiRepresenter;
    HFRepresenter *scrollRepresenter;
    HFLayoutRepresenter *layoutRepresenter;
    HFStatusBarRepresenter *statusBarRepresenter;
    
    NSResponder *savedFirstResponder;
    
    HFDocumentOperationView *findReplaceView;
    HFDocumentOperationView *navigateView;
    HFDocumentOperationView *saveView;
    
    HFDocumentOperationView *operationView;
    BOOL bannerIsShown;
    BOOL bannerGrowing;
    NSView *bannerView;
    NSView *bannerDividerThumb;
    NSTimer *bannerResizeTimer;
    CGFloat bannerTargetHeight;
    CFAbsoluteTime bannerStartTime;
    id targetFirstResponderInBanner;
    SEL commandToRunAfterBannerIsDoneHiding;
    
    NSInteger saveResult;
    
}

- (void)moveSelectionForwards:(NSMenuItem *)sender;
- (void)moveSelectionBackwards:(NSMenuItem *)sender;
- (void)extendSelectionForwards:(NSMenuItem *)sender;
- (void)extendSelectionBackwards:(NSMenuItem *)sender;

- (void)setFont:(NSFont *)font;
- (NSFont *)font;

- (IBAction)showFontPanel:sender;
- (IBAction)setAntialiasFromMenuItem:sender;

- (IBAction)findNext:sender;
- (IBAction)findPrevious:sender;
- (IBAction)replaceAndFind:sender;
- (IBAction)replace:sender;
- (IBAction)replaceAll:sender;

@end
