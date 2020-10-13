//
//  HFColumnRepresenter.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/1/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "HFColumnRepresenter.h"
#import <HexFiend/HFColumnView.h>
#import <HexFiend/HFUIUtils.h>

NSString *const HFColumnRepresenterViewHeightChanged = @"HFColumnRepresenterViewHeightChanged";

@implementation HFColumnRepresenter
{
    CGFloat _lineHeight;
}

- (NSView *)createView {
    NSRect frame = NSMakeRect(0, 0, 10, 16);
    HFColumnView *result = [[HFColumnView alloc] initWithFrame:frame];
    result.representer = self;
    result.autoresizingMask = NSViewWidthSizable;
    return result;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, 1);
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & HFControllerFont) {
        HFFont *font = self.controller.font;
        _lineHeight = HFLineHeightForFont(font);
        HFColumnView *view = (HFColumnView *)self.view;
        view.glyphTable = [[HFHexGlyphTable alloc] initWithFont:font];
        [view setNeedsDisplay:YES];
    }
    if (bits & (HFControllerFont|HFControllerLineHeight|HFControllerBytesPerLine|HFControllerBytesPerColumn)) {
        HFColumnView *view = (HFColumnView *)self.view;
        [view setNeedsDisplay:YES];
    }
    if (bits & (HFControllerFont|HFControllerLineHeight)) {
        HFColumnView *view = (HFColumnView *)self.view;
        NSRect frame = view.frame;
        CGFloat oldHeight = frame.size.height;
        CGFloat newHeight = self.preferredHeight;
        if (newHeight != oldHeight) {
            CGFloat change = newHeight - oldHeight;
            frame.size.height += change;
            frame.origin.y -= change;
            view.frame = frame;
            [view setNeedsDisplay:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:HFColumnRepresenterViewHeightChanged object:self];
        }
    }
}

- (void)setLineCountingWidth:(CGFloat)width {
    HFColumnView *view = (HFColumnView *)self.view;
    if (view.lineCountingWidth != width) {
        view.lineCountingWidth = width;
        [view setNeedsDisplay:YES];
    }
}

- (CGFloat)preferredHeight {
    return _lineHeight;
}

@end
