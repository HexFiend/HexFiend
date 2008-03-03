//
//  HFProgressTracker.m
//  HexFiend_2
//
//  Created by peter on 2/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFProgressTracker.h>

NSString *const HFProgressTrackerDidFinishNotification = @"HFProgressTrackerDidFinishNotification";

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
    }
}

- (void)beginTrackingProgress {
    HFASSERT(progressTimer == NULL);
    progressTimer = [[NSTimer scheduledTimerWithTimeInterval:1 / 30. target:self selector:@selector(_updateProgress:) userInfo:nil repeats:YES] retain];
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

- (void)noteFinished:(id)sender {
    if (! [NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(noteFinished:) withObject:sender waitUntilDone:NO];
    }
    else {
        [[NSNotificationCenter defaultCenter] postNotificationName:HFProgressTrackerDidFinishNotification object:self userInfo:nil];
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
