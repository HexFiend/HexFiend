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
    if (! leftView || ! rightView) return;
    CGFloat x, y;
    CGFloat lineHeight = 14;
    const NSRect bounds = [self bounds];
    const NSRect leftViewBounds = [self convertRect:[leftView bounds] fromView:leftView];
    const NSRect rightViewBounds = [self convertRect:[rightView bounds] fromView:rightView];
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGMutablePathRef path = CGPathCreateMutable();
    CGAffineTransform transform = CGContextGetCTM(ctx);
    
    x = NSMaxX(leftRect);
    y = NSMidY(leftRect);
    
    /* Left side vertical */
    CGPathMoveToPoint(path, &transform, x, y + lineHeight / 2);
    CGPathAddLineToPoint(path, &transform, x, y - lineHeight / 2);
    
    /* Go from the center of the left rect to the center */
    CGPathMoveToPoint(path, &transform, NSMaxX(leftRect), NSMidY(leftRect));
    CGPathAddLineToPoint(path, &transform, NSMaxX(leftViewBounds), NSMidY(leftRect));
    
    /* Now go to the right */
    CGPathAddLineToPoint(path, &transform, NSMinX(rightViewBounds), NSMidY(rightRect));
    
    x = NSMinX(rightRect), y = NSMidY(rightRect);
    CGPathAddLineToPoint(path, &transform, x, y);
    
    /* Add vertical line to end */
    CGPathAddLineToPoint(path, &transform, x, y + lineHeight / 2);
    CGPathAddLineToPoint(path, &transform, x, y - lineHeight / 2);
    
    CGContextAddPath(ctx, path);
    [[NSColor colorWithCalibratedRed:1. green:0. blue:0. alpha:.5] set];
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    CGContextSetLineWidth(ctx, 2.);
    CGContextStrokePath(ctx);
    CGPathRelease(path);
    
    //    CGContextAddPath(ctx, path);
    //    [[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:.75] set];
    //    CGContextStrokePath(ctx);    
}


- (void)drawRectSlightlyLessOld:(NSRect)rect {
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGMutablePathRef path = CGPathCreateMutable();
    CGAffineTransform transform = CGContextGetCTM(ctx);
    
    /* Find the midpoint of our two lines */
    CGPoint mid1, mid2;
    mid1.x = (NSMaxX(leftRect) + NSMinX(rightRect)) / 2;
    mid1.y = (NSMinY(leftRect) + NSMinY(rightRect)) / 2;
    
    mid2.x = (NSMaxX(leftRect) + NSMinX(rightRect)) / 2;
    mid2.y = (NSMaxY(leftRect) + NSMaxY(rightRect)) / 2;
    
    /* Find the midpoint of the line connecting the midpoints */
    CGPoint secondMid;
    secondMid.x = (mid1.x + mid2.x) / 2;
    secondMid.y = (mid1.y + mid2.y) / 2;
    
    /* Use it as a control point */
    if (1) {
	CGPathMoveToPoint(path, &transform, NSMaxX(leftRect), NSMinY(leftRect));
	CGPathAddLineToPoint(path, &transform, NSMaxX(leftRect), NSMaxY(leftRect));
	CGPathAddQuadCurveToPoint(path, &transform, secondMid.x, secondMid.y, NSMinX(rightRect), NSMaxY(rightRect));
	CGPathAddLineToPoint(path, &transform, NSMinX(rightRect), NSMinY(rightRect));
	CGPathAddQuadCurveToPoint(path, &transform, secondMid.x, secondMid.y, NSMaxX(leftRect), NSMinY(leftRect));
	CGPathCloseSubpath(path);
    }
    else {
	CGPathMoveToPoint(path, &transform, NSMaxX(leftRect), NSMinY(leftRect));
	CGPathAddLineToPoint(path, &transform, NSMaxX(leftRect), NSMaxY(leftRect));
	CGPathAddLineToPoint(path, &transform, NSMinX(rightRect), NSMaxY(rightRect));
	CGPathAddLineToPoint(path, &transform, NSMinX(rightRect), NSMinY(rightRect));
	CGPathCloseSubpath(path);
    }
    
    
    
    CGContextAddPath(ctx, path);
    [[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:.15] set];
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    CGContextFillPath(ctx);
    CGPathRelease(path);
    
    //    CGContextAddPath(ctx, path);
    //    [[NSColor colorWithCalibratedRed:0. green:0. blue:0. alpha:.75] set];
    //    CGContextStrokePath(ctx);    
}

- (void)drawRectOld:(NSRect)rect {
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

- (void)setLeftView:(NSView *)view {
    leftView = view;
}

- (void)setRightView:(NSView *)view {
    rightView = view;
}


@end
