//
//  HFTextSelectionPulseView.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFTextSelectionPulseView.h"
#import "HFFunctions.h"


@implementation HFTextSelectionPulseView

- (void)drawRect:(NSRect)rect {
    USE(rect);
    CGContextSetInterpolationQuality(HFGraphicsGetCurrentContext(), kCGInterpolationHigh);
    [image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:(CGFloat)1.];
}

- (void)setImage:(NSImage *)val {
    if (val != image) {
        image = val;
    }
    [self setNeedsDisplay:YES];
}

@end
