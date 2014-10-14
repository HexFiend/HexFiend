//
//  HFTextSelectionPulseView.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextSelectionPulseView.h>


@implementation HFTextSelectionPulseView

- (void)drawRect:(NSRect)rect {
    USE(rect);
    CGContextSetInterpolationQuality([[NSGraphicsContext currentContext] graphicsPort], kCGInterpolationHigh);
    [image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:(CGFloat)1.];
}

- (void)setImage:(NSImage *)val {
    if (val != image) {
        [val retain];
        [image release];
        image = val;
    }
    [self setNeedsDisplay:YES];
}

- (void)dealloc
{
    [image release];
    [super dealloc];
}

@end
