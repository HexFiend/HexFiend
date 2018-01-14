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
    BOOL awokenFromNib;
    id threadResult;
    dispatch_group_t waitGroup;

    void (^completionHandler)(id result);
    
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *cancelButton;
    HFProgressTracker *tracker;
    NSArray *otherTopLevelObjects;
    double progress;
    BOOL operationIsCancelling;
}

- (void)setOtherTopLevelObjects:(NSArray *)objects;

+ (HFDocumentOperationView *)viewWithNibNamed:(NSString *)name owner:(id)owner;

- (NSView *)viewNamed:(NSString *)name;

- (CGFloat)defaultHeight;

@property (nonatomic, copy) NSString *displayName;

- (IBAction)cancelViewOperation:sender;

/* KVO compliant */
- (BOOL)operationIsRunning;

/* KVO compliant, in the range [0, 1], or -1 to mean not running */
- (double)progress;

- (void)startOperation:(id (^)(HFProgressTracker *tracker))block completionHandler:(void (^)(id result))completionHandler;

- (HFProgressTracker *)progressTracker;

@end
