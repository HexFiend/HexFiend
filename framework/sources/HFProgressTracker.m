//
//  HFProgressTracker.m
//  HexFiend_2
//
//  Created by peter on 2/12/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFProgressTracker.h>
#include <pthread.h>

@implementation HFProgressTracker

- (void)setMaxProgress:(unsigned long long)max {
    maxProgress = max;
}

- (unsigned long long)maxProgress {
    return maxProgress;
}

- (void)setProgressIndicator:(NSProgressIndicator *)indicator {
    [indicator retain];
    [progressIndicator release];
    progressIndicator = indicator;
}

- (NSProgressIndicator *)progressIndicator {
    return progressIndicator;
}

- (void)_updateProgress:(NSTimer *)timer {
    USE(timer);
    double value;
    unsigned long long localCurrentProgress = currentProgress;
    if (maxProgress == 0 || localCurrentProgress == 0) {
        value = 0;
    }
    else {
        value = (double)((long double)localCurrentProgress / (long double)maxProgress);
    }
    if (value != lastSetValue) {
        lastSetValue = value;
        [progressIndicator setDoubleValue:lastSetValue];
        if (delegate && [delegate respondsToSelector:@selector(progressTracker:didChangeProgressTo:)]) {
            [delegate progressTracker:self didChangeProgressTo:lastSetValue];
        }
    }
}

- (void)beginTrackingProgress {
    HFASSERT(progressTimer == NULL);
    NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
    progressTimer = [[NSTimer timerWithTimeInterval:1 / 30. target:self selector:@selector(_updateProgress:) userInfo:nil repeats:YES] retain];
    [currentRunLoop addTimer:progressTimer forMode:NSDefaultRunLoopMode];
    [currentRunLoop addTimer:progressTimer forMode:NSModalPanelRunLoopMode];
    [self _updateProgress:nil];
    [progressIndicator startAnimation:self];
}

- (void)endTrackingProgress {
    HFASSERT(progressTimer != NULL);
    [progressTimer invalidate];
    [progressTimer release];
    progressTimer = nil;
    [progressIndicator stopAnimation:self];
}

- (void)requestCancel:(id)sender {
    USE(sender);
    cancelRequested = 1;
    OSMemoryBarrier();
}

- (void)dealloc {
    [progressIndicator release];
    [progressTimer invalidate];
    [progressTimer release];
    progressTimer = nil;
    [userInfo release];
    [super dealloc];
}

- (void)setDelegate:(id)val {
    delegate = val;
}

- (id)delegate {
    return delegate;
}

- (void)noteFinished:(id)sender {
    if (delegate != nil) {   
        if (! pthread_main_np()) { // [NSThread isMainThread] is not available on Tiger
            [self performSelectorOnMainThread:@selector(noteFinished:) withObject:sender waitUntilDone:NO];
        }
        else {
            if ([delegate respondsToSelector:@selector(progressTrackerDidFinish:)]) {
                [delegate progressTrackerDidFinish:self];
            }
        }
    }
}

- (void)setUserInfo:(NSDictionary *)info {
    [info retain];
    [userInfo release];
    userInfo = info;
}

- (NSDictionary *)userInfo {
    return userInfo;
}

@end
