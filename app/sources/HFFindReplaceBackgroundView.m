//
//  HFFindReplaceBackgroundView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "HFFindReplaceBackgroundView.h"


@implementation HFFindReplaceBackgroundView

- (void)drawRect:(NSRect)rect {
    [[NSColor orangeColor] set];
//    NSRectFill(rect);
}

- (void)setLayoutRepresenterView:(NSView *)view {
    [view retain];
    [layoutRepresenterView release];
    layoutRepresenterView = view;
}

- (NSView *)layoutRepresenterView {
    return layoutRepresenterView;
}

- (NSPoint)roundPointToPixels:(NSPoint)point {
    NSPoint windowPoint = [self convertPoint:point toView:nil];
    windowPoint.x = HFRound(windowPoint.x);
    windowPoint.y = HFRound(windowPoint.y);
    return [self convertPoint:windowPoint fromView:nil];
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [super resizeSubviewsWithOldSize:oldSize];
    NSRect bounds = [self bounds];
    if (navigateControl) {
        NSRect navFrame = [navigateControl frame];
        navFrame.origin.y = NSMinY([self bounds]) + 2;
        navFrame.origin = [self roundPointToPixels:navFrame.origin];
        [navigateControl setFrameOrigin:navFrame.origin];
    }
    if (layoutRepresenterView) {
        NSRect layFrame = [layoutRepresenterView frame];
        layFrame.size.height = HFMax(NSHeight(bounds) - 8, 0);
        layFrame.origin.y = NSMidY([self bounds]) - layFrame.size.height / 2;
        layFrame.origin = [self roundPointToPixels:layFrame.origin];
        [layoutRepresenterView setFrame:layFrame];
    }
}

@end
