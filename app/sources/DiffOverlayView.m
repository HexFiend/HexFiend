//
//  DiffOverlayView.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "DiffOverlayView.h"
#import <HexFiend/HexFiend.h>

@implementation DiffOverlayView

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)rect {
    USE(rect);
    if (! leftView || ! rightView) return;    
    CGFloat x, y, bottom, top;
    CGFloat lineHeight = 14;
    const NSRect leftViewBounds = [self convertRect:[leftView bounds] fromView:leftView];
    const NSRect rightViewBounds = [self convertRect:[rightView bounds] fromView:rightView];
    const CGFloat xMiddle = (NSMaxX(leftViewBounds) + NSMinX(rightViewBounds)) / 2;
    
    /* Clip to the bounds of our left and right views so we don't draw into the content region below */
    [NSBezierPath clipRect:NSUnionRect(leftViewBounds, rightViewBounds)];
    
    CGContextRef ctx = HFGraphicsGetCurrentContext();
    CGMutablePathRef path = CGPathCreateMutable();
    const CGAffineTransform transform = CGAffineTransformIdentity;
    
    x = NSMaxX(leftRect);
    y = NSMidY(leftRect);
    bottom = ([self isFlipped] ? NSMaxY : NSMinY)(leftViewBounds);
    top = ([self isFlipped] ? NSMinY : NSMaxY)(leftViewBounds);
    
    /* Left half */
    if (leftRangeType == DiffOverlayViewRangeIsAbove) {
        /* Come from the top */
        CGPathMoveToPoint(path, &transform, xMiddle, top);	
    }
    else if (leftRangeType == DiffOverlayViewRangeIsBelow) {
        /* Come from the bottom */
        CGPathMoveToPoint(path, &transform, xMiddle, bottom);		
    }
    else {
        /* Left side vertical */
        CGPathMoveToPoint(path, &transform, x, y + lineHeight / 2);
        CGPathAddLineToPoint(path, &transform, x, y - lineHeight / 2);
        
        /* Go from the center of the left rect to the center */
        CGPathMoveToPoint(path, &transform, NSMaxX(leftRect), NSMidY(leftRect));
        CGPathAddLineToPoint(path, &transform, NSMaxX(leftViewBounds), NSMidY(leftRect));
    }    
    
    /* Right half */
    if (rightRangeType == DiffOverlayViewRangeIsAbove) {
        /* Go off the top */
        CGPathAddLineToPoint(path, &transform, xMiddle, top);	
    }
    else if (rightRangeType == DiffOverlayViewRangeIsBelow) {
        /* Go off the bottom */
        CGPathAddLineToPoint(path, &transform, xMiddle, bottom);
    }
    else {
        /* Now go to the right */
        CGPathAddLineToPoint(path, &transform, NSMinX(rightViewBounds), NSMidY(rightRect));
        
        x = NSMinX(rightRect);
        y = NSMidY(rightRect);
        CGPathAddLineToPoint(path, &transform, x, y);
        
        /* Add vertical line to end */
        CGPathAddLineToPoint(path, &transform, x, y + lineHeight / 2);
        CGPathAddLineToPoint(path, &transform, x, y - lineHeight / 2);
    }
    
    CGContextAddPath(ctx, path);
    NSColor *color = NSColor.systemRedColor;
    [[color colorWithAlphaComponent:0.5] set];
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    CGContextSetLineWidth(ctx, 2.);
    CGContextStrokePath(ctx);
    CGPathRelease(path);
    
    //    CGContextAddPath(ctx, path);
    //    [[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:.75] set];
    //    CGContextStrokePath(ctx);    
}

- (void)setLeftRangeType:(enum DiffOverlayViewRangeType_t)type rect:(NSRect)rect {
    if (leftRangeType != type || ! NSEqualRects(rect, leftRect)) {
        leftRangeType = type;
        leftRect = rect;
        [self setNeedsDisplay:YES];
    }
}

- (void)setRightRangeType:(enum DiffOverlayViewRangeType_t)type rect:(NSRect)rect {
    if (rightRangeType != type || ! NSEqualRects(rect, rightRect)) {
        rightRangeType = type;
        rightRect = rect;
        [self setNeedsDisplay:YES];
    }
}

- (NSView *)hitTest:(NSPoint)point {
    USE(point);
    return nil; //we cannot be hit!
}

- (void)setLeftView:(NSView *)view {
    leftView = view;
}

- (void)setRightView:(NSView *)view {
    rightView = view;
}

@end
