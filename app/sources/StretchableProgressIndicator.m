//
//  StretchableProgressIndicator.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "StretchableProgressIndicator.h"
#import <HexFiend/HexFiend.h>

static CGFloat norm(unsigned char x) {
    return x / (CGFloat)255.;
}

#define EDGE_WIDTH 1

#define kStretchableProgressIndicatorIdentifier @"progressIndicator"

@interface NSObject (BackwardCompatibleDeclarations)
- (void)setUserInterfaceItemIdentifier:(NSString *)val;
@end


@implementation StretchableProgressIndicator

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)rect {
    USE(rect);
    NSRect bounds = [self bounds];
    
    double percent = [self doubleValue];
    NSRect rectToFill = bounds;
    rectToFill.size.width *= percent;
    NSRect baseRectToFill = [self convertRectToBacking:rectToFill];
    baseRectToFill.size.width = round(baseRectToFill.size.width);
    rectToFill = [self convertRectFromBacking:baseRectToFill];
    
    
    [NSBezierPath clipRect:rectToFill];
    
    [gradient drawFromPoint:(NSPoint){NSMinX(bounds), NSMinY(bounds)} toPoint:(NSPoint){NSMinX(bounds), NSMaxY(bounds)} options:0];
        
    /* Draw dark top and bottom lines */
    CGFloat lineHeight = 1;
    NSRect edgeRect = NSMakeRect(NSMinX(bounds), 0, NSWidth(bounds), lineHeight);
    [[NSColor colorWithCalibratedWhite:.5 alpha:.5] set];
    NSRectFillUsingOperation(edgeRect, NSCompositingOperationSourceOver);
    
    /* Draw right edge line */
    [[NSColor colorWithCalibratedRed:0. green:0. blue:1. alpha:.15] set];
    NSRect baseRightEdge = NSMakeRect(ceil(NSMaxX(baseRectToFill) - EDGE_WIDTH), NSMinY(baseRectToFill), EDGE_WIDTH, NSHeight(baseRectToFill));
    NSRect localRightEdge = [self convertRectFromBacking:baseRightEdge];
    NSRectFillUsingOperation(localRightEdge, NSCompositingOperationSourceOver);
}

- (void)setDoubleValue:(double)newValue {
    /* Mark us as needing in the rect that changed */
    double currentValue = [self doubleValue];
    NSRect bounds = [self bounds];
    NSRect redisplayRect = bounds;
    redisplayRect.origin.x = fmin(newValue, currentValue) * bounds.size.width - EDGE_WIDTH - 1;
    redisplayRect.size.width *= fabs(newValue - currentValue) + EDGE_WIDTH + 1;
    [self setNeedsDisplayInRect:redisplayRect];
    [super setDoubleValue:newValue];
}

/* override these to do nothing, since we don't animate */
- (void)startAnimation:(id)sender { USE(sender); }
- (void)stopAnimation:(id)sender { USE(sender); }

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    
    if ([self respondsToSelector:@selector(setIdentifier:)]) {
        [self setIdentifier:kStretchableProgressIndicatorIdentifier];
    } else if ([self respondsToSelector:@selector(setUserInterfaceItemIdentifier:)]) {
        [self setUserInterfaceItemIdentifier:kStretchableProgressIndicatorIdentifier];
    }
    
    NSColor *colors[3];
#if 1
    // Aqua gradient */
    colors[0] = [NSColor colorWithCalibratedRed:norm(163) green:norm(207) blue:norm(246) alpha:1];
    colors[1] = [NSColor colorWithCalibratedRed:norm(119) green:norm(196) blue:norm(248) alpha:1];
#else
    // Gray gradient
    colors[0] = [NSColor colorWithCalibratedRed:norm(207) green:norm(207) blue:norm(207) alpha:1];
    colors[1] = [NSColor colorWithCalibratedRed:norm(155) green:norm(155) blue:norm(155) alpha:1];
#endif
    colors[2] = colors[0];
    gradient = [[NSGradient alloc] initWithColors:[NSArray arrayWithObjects:colors count:sizeof colors / sizeof *colors]];
    
    /* We always have a value in [0, 1] */
    [self setMaxValue:1.];
    return self;
}

@end
