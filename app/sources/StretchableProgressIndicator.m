//
//  StretchableProgressIndicator.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/13/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "StretchableProgressIndicator.h"

static CGFloat norm(unsigned char x) {
    return x / (CGFloat)255.;
}

@implementation StretchableProgressIndicator

- (BOOL)isFlipped {
    return YES;
}

- (void)drawRect:(NSRect)rect {
    USE(rect);
    NSRect bounds = [self bounds];
    
    double percent = [self doubleValue]     ;
    NSRect rectToFill = bounds;
    rectToFill.size.width *= percent;
    [NSBezierPath clipRect:rectToFill];
    
    [gradient drawFromPoint:(NSPoint){NSMinX(bounds), NSMinY(bounds)} toPoint:(NSPoint){NSMinX(bounds), NSMaxY(bounds)} options:0];
    
    /* Draw dark top and bottom lines */
    CGFloat lineHeight = 1;
    NSRect edgeRect = NSMakeRect(NSMinX(bounds), 0, NSWidth(bounds), lineHeight);
    [[NSColor colorWithCalibratedWhite:.5 alpha:.5] set];
    NSRectFillUsingOperation(edgeRect, NSCompositeSourceOver);
}

- (void)setDoubleValue:(double)newValue {
    /* Mark us as needing in the rect that changed */
    double currentValue = [self doubleValue];
    NSRect bounds = [self bounds];
    NSRect redisplayRect = bounds;
    redisplayRect.origin.x = fmin(newValue, currentValue) * bounds.size.width;
    redisplayRect.size.width *= fabs(newValue - currentValue);
    [self setNeedsDisplayInRect:redisplayRect];
    [super setDoubleValue:newValue];
}

/* override these to do nothing, since we don't animate */
- (void)startAnimation:(id)sender { USE(sender); }
- (void)stopAnimation:(id)sender { USE(sender); }

- (id)initWithFrame:(NSRect)frame {
    [super initWithFrame:frame];
    NSColor *colors[3];
    colors[0] = [NSColor colorWithCalibratedRed:norm(163) green:norm(207) blue:norm(246) alpha:1];
    colors[1] = [NSColor colorWithCalibratedRed:norm(119) green:norm(196) blue:norm(248) alpha:1];
    colors[2] = colors[0];
    gradient = [[NSGradient alloc] initWithColors:[NSArray arrayWithObjects:colors count:sizeof colors / sizeof *colors]];
    
    /* We always have a value in [0, 1] */
    [self setMaxValue:1.];
    return self;
}

- (void)dealloc {
    [gradient release];
    [super dealloc];
}

@end
