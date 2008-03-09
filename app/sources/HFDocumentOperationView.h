//
//  HFDocumentOperationView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 2/26/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
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
    BOOL awokenFromNib;
    pthread_t thread;
    
    HFProgressTracker *tracker;
    id target;
    SEL startSelector;
    SEL endSelector;
}

+ viewWithNibNamed:(NSString *)name;
- viewNamed:(NSString *)name;
- (CGFloat)defaultHeight;

- (IBAction)cancelViewOperation:sender;
- (BOOL)operationIsRunning;

- (void)startOperationWithCallbacks:(struct HFDocumentOperationCallbacks)callbacks;

- (HFProgressTracker *)progressTracker;

@end
