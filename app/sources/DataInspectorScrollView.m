//
//  DataInspectorScrollView.m
//  HexFiend_2
//
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "DataInspectorScrollView.h"
#import <HexFiend/HexFiend.h>

@implementation DataInspectorScrollView

- (void)drawDividerWithClip:(NSRect)clipRect {
    NSColor *separatorColor = [NSColor lightGrayColor];
    if (HFDarkModeEnabled()) {
        if (@available(macOS 10.14, *)) {
            separatorColor = [NSColor separatorColor];
        }
    }
    [separatorColor set];
    NSRect bounds = [self bounds];
    NSRect lineRect = bounds;
    lineRect.size.height = 1;
    NSRectFillUsingOperation(NSIntersectionRect(lineRect, clipRect), NSCompositingOperationSourceOver);
}

- (void)drawRect:(NSRect)__unused dirtyRect {
    NSRect rect = self.bounds;
    if (!HFDarkModeEnabled()) {
        [[NSColor colorWithCalibratedWhite:(CGFloat).91 alpha:1] set];
        NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
    }
    
    if (HFDarkModeEnabled()) {
        [[NSColor colorWithCalibratedWhite:(CGFloat).09 alpha:1] set];
    } else {
        [[NSColor colorWithCalibratedWhite:(CGFloat).91 alpha:1] set];
    }
    NSRectFillUsingOperation(rect, NSCompositingOperationSourceOver);
    [self drawDividerWithClip:rect];
}

@end
