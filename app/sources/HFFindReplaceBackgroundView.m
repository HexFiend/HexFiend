//
//  HFFindReplaceBackgroundView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/24/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFFindReplaceBackgroundView.h"

static CGFloat roundTowardsInfinity(CGFloat x) {
    return HFFloor(x + (CGFloat).5);
}

@implementation HFFindReplaceBackgroundView

- (NSPoint)roundPointToPixels:(NSPoint)point {
    NSPoint windowPoint = [self convertPoint:point toView:nil];
    windowPoint.x = HFRound(windowPoint.x);
    windowPoint.y = roundTowardsInfinity(windowPoint.y);
    return [self convertPoint:windowPoint fromView:nil];
}

- (NSSize)roundSizeToPixels:(NSSize)size {
    NSSize windowSize = [self convertSize:size toView:nil];
    windowSize.width = HFRound(windowSize.width);
    windowSize.height = -roundTowardsInfinity(-windowSize.height);
    NSSize result = [self convertSize:windowSize fromView:nil];
    result.width = HFCopysign(result.width, size.width);
    result.height = HFCopysign(result.height, size.height);
    return result;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [super resizeSubviewsWithOldSize:oldSize];
    NSRect bounds = [self bounds];
    if (navigateControl) {
        NSRect navFrame = [navigateControl frame];
        navFrame.origin.y = NSMinY([self bounds]) + 3;
//        navFrame.origin.y = NSMidY([self bounds]) - NSHeight(navFrame)/2;
        navFrame.origin = [self roundPointToPixels:navFrame.origin];
        [navigateControl setFrameOrigin:navFrame.origin];
    }
    if (replaceField) {
        NSRect replaceFrame = [replaceField frame];
        replaceFrame.size.height = HFMax(NSHeight(bounds) / 2 - 4, 0);
        replaceFrame.origin.y = NSMinY([self bounds]) + 2;
        replaceFrame.origin = [self roundPointToPixels:replaceFrame.origin];
        replaceFrame.size = [self roundSizeToPixels:replaceFrame.size];
        [replaceField setFrame:replaceFrame];
    }
    if (searchField) {
        NSRect searchFrame = [searchField frame];
        searchFrame.size.height = HFMax(NSHeight(bounds) / 2 - 4, 0);
        searchFrame.origin.y = NSMaxY([self bounds]) - 2 - searchFrame.size.height;
        searchFrame.origin = [self roundPointToPixels:searchFrame.origin];
        searchFrame.size = [self roundSizeToPixels:searchFrame.size];
        [searchField setFrame:searchFrame];
    }
    if (searchLabel && searchField) {
        NSRect findFrame = [searchLabel frame];
        findFrame.origin.y = NSMaxY([searchField frame]) - NSHeight(findFrame);
        [searchLabel setFrameOrigin:findFrame.origin];
    }
    if (replaceLabel && replaceField) {
        NSRect replaceFrame = [replaceLabel frame];
        replaceFrame.origin.y = NSMaxY([replaceField frame]) - NSHeight(replaceFrame);
        [replaceLabel setFrameOrigin:replaceFrame.origin];
    }
}

- (HFTextField *)searchField {
    return searchField;
}

- (HFTextField *)replaceField {
    return replaceField;
}

- (NSSegmentedControl *)navigateControl {
    return navigateControl;
}

- (NSProgressIndicator *)progressIndicator {
    return progressIndicator;
}

- (NSButton *)cancelButton {
    return cancelButton;
}

- initWithFrame:(NSRect)rect {
    [super initWithFrame:rect];
    defaultHeight = NSHeight(rect);
    return self;
}

- (CGFloat)defaultHeight {
    return defaultHeight;
}

@end
