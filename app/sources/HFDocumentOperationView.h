//
//  HFDocumentOperationView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 2/26/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFResizingView.h"

@class HFProgressTracker;

struct HFDocumentOperationCallbacks {
    id target;
    NSDictionary *userInfo; // set on the HFProgressTracker
    SEL startSelector; // - (void)beginThread:(HFProgressTracker *)tracker; delivered on child thread
    SEL endSelector; // - (void)threadDidEnd:(id)result; delivered on main thread
};

@interface HFDocumentOperationView : HFResizingView {
    NSMutableDictionary *views;
    NSString *nibName;
    NSString *displayName;
    BOOL awokenFromNib;
    pthread_t thread;
    
    HFProgressTracker *tracker;
    id target;
    SEL startSelector;
    SEL endSelector;
    NSArray *otherTopLevelObjects;
    double progress;
}

- (void)setOtherTopLevelObjects:(NSArray *)objects;

+ viewWithNibNamed:(NSString *)name owner:(id)owner;
- viewNamed:(NSString *)name;
- (CGFloat)defaultHeight;

- (NSString *)displayName;
- (void)setDisplayName:(NSString *)name;

- (IBAction)cancelViewOperation:sender;
- (BOOL)operationIsRunning;

/* KVO compliant, in the range [0, 1], or -1 to mean not running */
- (double)progress;

- (void)startOperationWithCallbacks:(struct HFDocumentOperationCallbacks)callbacks;

- (HFProgressTracker *)progressTracker;

@end
