//
//  HFTextSelectionPulseView.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#if !__has_feature(objc_arc)
#error ARC required
#endif

#import <HexFiend/HFTextSelectionPulseView.h>


@implementation HFTextSelectionPulseView

- (void)drawRect:(NSRect)rect {
    USE(rect);
    CGContextSetInterpolationQuality([[NSGraphicsContext currentContext] graphicsPort], kCGInterpolationHigh);
    [image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:(CGFloat)1.];
}

- (void)setImage:(NSImage *)val {
    if (val != image) {
        image = val;
    }
    [self setNeedsDisplay:YES];
}

@end
