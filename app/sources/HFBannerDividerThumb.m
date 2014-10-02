//
//  HFBannerDividerThumb.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFBannerDividerThumb.h"


@implementation HFBannerDividerThumb

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
    USE(rect);
    NSRect bounds = [self bounds];
    CGFloat y;
    y = NSMinY(bounds) + 3;
    NSUInteger i;
    [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
    [[NSColor colorWithCalibratedWhite:(CGFloat).8 alpha:(CGFloat).5] set];
    for (i = 0; i < 3; i++) {
        NSRectFillUsingOperation(NSMakeRect(NSMinX(bounds), y, NSWidth(bounds), 1), NSCompositeSourceOver);
        y += 3;
    }
    y = NSMinY(bounds) + 4;
    [[NSColor colorWithCalibratedWhite:(CGFloat).2 alpha:(CGFloat).5] set];
    for (i = 0; i < 3; i++) {
        NSRectFillUsingOperation(NSMakeRect(NSMinX(bounds), y, NSWidth(bounds), 1), NSCompositeSourceOver);
        y += 3;
    }    
}

@end
