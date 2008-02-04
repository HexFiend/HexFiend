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
        navFrame.origin.y = NSMinY([self bounds]) + 3;
        navFrame.origin = [self roundPointToPixels:navFrame.origin];
        [navigateControl setFrameOrigin:navFrame.origin];
    }
    if (searchField) {
        NSRect searchFrame = [searchField frame];
        searchFrame.size.height = HFMax(NSHeight(bounds) - 10, 0);
        searchFrame.origin.y = NSMidY([self bounds]) - searchFrame.size.height / 2;
        searchFrame.origin = [self roundPointToPixels:searchFrame.origin];
        [searchField setFrame:searchFrame];
    }
}

- (HFTextField *)searchField {
    return searchField;
}

@end
