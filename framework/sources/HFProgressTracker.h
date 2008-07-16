//
//  HFProgressTracker.h
//  HexFiend_2
//
//  Created by peter on 2/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* A class for showing progress and cancelling longrunning threaded operations.  The thread is expected to write directly into currentProgress (with atomic functions) as it makes progress.  Once beginTrackingProgress is called, the HFProgressTracker will poll currentProgress until endTrackingProgress is called.  The thread is also expected to read directly from cancelRequested, which is set by the requestCancel method.
*/

@interface HFProgressTracker : NSObject {
    @public
    volatile unsigned long long currentProgress;
    volatile int cancelRequested;
    @private
    unsigned long long maxProgress;
    NSProgressIndicator *progressIndicator;
    NSTimer *progressTimer;
    double lastSetValue;
    NSDictionary *userInfo;
    id delegate;
}

- (void)setMaxProgress:(unsigned long long)max;
- (unsigned long long)maxProgress;

- (void)setUserInfo:(NSDictionary *)info;
- (NSDictionary *)userInfo;

- (void)setProgressIndicator:(NSProgressIndicator *)indicator;
- (NSProgressIndicator *)progressIndicator;

- (void)beginTrackingProgress;
- (void)endTrackingProgress;

/* Reflects onto the main thread if called from a different thread */
- (void)noteFinished:(id)sender;

- (void)requestCancel:(id)sender;

- (void)setDelegate:(id)delegate;
- (id)delegate;

@end

@interface NSObject (HFProgressTrackerDelegate)

- (void)progressTracker:(HFProgressTracker *)tracker didChangeProgressTo:(double)fraction;
- (void)progressTrackerDidFinish:(HFProgressTracker *)tracker;

@end

