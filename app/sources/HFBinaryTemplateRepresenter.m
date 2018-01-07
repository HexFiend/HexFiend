//
//  HFBinaryTemplateRepresenter.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/6/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFBinaryTemplateRepresenter.h"

@implementation HFBinaryTemplateRepresenter

- (NSView *)createView {
    NSView *view = [[NSView alloc] initWithFrame:NSZeroRect];
    view.autoresizingMask = NSViewHeightSizable;
    return view;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(3, 0);
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    return bytesPerLine * 10;
}

@end
