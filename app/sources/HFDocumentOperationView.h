//
//  HFDocumentOperationView.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFResizingView.h"

@class HFProgressTracker;

@interface HFDocumentOperationView : HFResizingView {
    NSString *nibName;
    NSString *displayName;
    BOOL awokenFromNib;
    id threadResult;
    dispatch_group_t waitGroup;

    id (^startBlock)(HFProgressTracker *tracker);
    void (^completionHandler)(id result);
    
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *cancelButton;
    HFProgressTracker *tracker;
    NSArray *otherTopLevelObjects;
    double progress;
    BOOL isFixedHeight;
    BOOL operationIsCancelling;
}

- (void)setOtherTopLevelObjects:(NSArray *)objects;

+ viewWithNibNamed:(NSString *)name owner:(id)owner;

- viewNamed:(NSString *)name;

- (CGFloat)defaultHeight;

- (BOOL)isFixedHeight;
- (void)setIsFixedHeight:(BOOL)val;

- (NSString *)displayName;
- (void)setDisplayName:(NSString *)name;

- (IBAction)cancelViewOperation:sender;

/* KVO compliant */
- (BOOL)operationIsRunning;

/* KVO compliant, in the range [0, 1], or -1 to mean not running */
- (double)progress;

- (void)startOperation:(id (^)(HFProgressTracker *tracker))block completionHandler:(void (^)(id result))completionHandler;

- (HFProgressTracker *)progressTracker;

@end
