//
//  DiffOverlayView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/26/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "DiffOverlayView.h"


@implementation DiffOverlayView

- (void)drawRect:(NSRect)rect {
    NSPoint lowerLeft, upperRight;
    lowerLeft.x = MIN(NSMinX(leftRect), NSMinX(rightRect));
    lowerLeft.y = MIN(NSMinY(leftRect), NSMinY(rightRect));
    upperRight.x = MAX(NSMaxX(leftRect), NSMaxX(rightRect));
    upperRight.y = MAX(NSMaxY(leftRect), NSMaxY(rightRect));
    NSRect unionRect;
    unionRect.origin = lowerLeft;
    unionRect.size.width = upperRight.x - lowerLeft.x;
    unionRect.size.height = upperRight.y - lowerLeft.y;
    [[NSColor colorWithCalibratedRed:0. green:0. blue:1. alpha:.5] set];
    NSRectFillUsingOperation(unionRect, NSCompositeSourceOver);
}

- (void)setLeftRect:(NSRect)rect {
    leftRect = rect;
    [self setNeedsDisplay:YES];
}

- (void)setRightRect:(NSRect)rect {
    rightRect = rect;
    [self setNeedsDisplay:YES];
}

- (NSView *)hitTest:(NSPoint)point {
    USE(point);
    return nil; //we cannot be hit!
}

@end
