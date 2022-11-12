//
//  DataInspectorPlusMinusButtonCell.m
//  HexFiend_2
//
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "DataInspectorPlusMinusButtonCell.h"
#import <HexFiend/HexFiend.h>

@implementation DataInspectorPlusMinusButtonCell

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    [self setBezelStyle:NSBezelStyleRoundRect];
    return self;
}

- (void)drawDataInspectorTitleWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    const BOOL isPlus = [[self title] isEqual:@"+"];
    const CGFloat thickness = 2;
    const CGFloat size = 8;
    const NSRect horizontalBarRect = NSMakeRect(
        cellFrame.origin.x + floor((cellFrame.size.width - size) / 2),
        cellFrame.origin.y + floor((cellFrame.size.height - thickness) / 2),
        size, thickness);
    const NSRect verticalBarRect = NSMakeRect(
        cellFrame.origin.x + floor((cellFrame.size.width - thickness) / 2),
        cellFrame.origin.y + floor((cellFrame.size.height - size) / 2),
        thickness, size);
    [[NSColor colorWithCalibratedWhite:0.45 alpha:1.0] setFill];
    [NSBezierPath fillRect:horizontalBarRect];
    if (isPlus) {
        [NSBezierPath fillRect:verticalBarRect];
    }
}

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView {
    /* Defeat title drawing by doing nothing */
    USE(title);
    USE(frame);
    USE(controlView);
    return NSZeroRect;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawWithFrame:cellFrame inView:controlView];
    [self drawDataInspectorTitleWithFrame:cellFrame inView:controlView];
}

@end
