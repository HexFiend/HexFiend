//
//  HFTextVisualStyleRun.m
//  HexFiend_2
//
//  Created by Peter Ammon on 8/29/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "HFTextVisualStyleRun.h"


@implementation HFTextVisualStyleRun

- (void)dealloc {
    [foregroundColor release];
    [backgroundColor release];
    [super dealloc];
}


- (NSColor *)foregroundColor {
    return [[foregroundColor retain] autorelease]; 
}

- (void)setForegroundColor:(NSColor *)theForegroundColor {
    if (foregroundColor != theForegroundColor) {
        [foregroundColor release];
        foregroundColor = [theForegroundColor retain];
    }
}

- (NSColor *)backgroundColor {
    return [[backgroundColor retain] autorelease]; 
}

- (void)setBackgroundColor:(NSColor *)theBackgroundColor {
    if (backgroundColor != theBackgroundColor) {
        [backgroundColor release];
        backgroundColor = [theBackgroundColor retain];
    }
}

- (NSRange)range {
    return range;
}

- (void)setRange:(NSRange)theRange {
    range = theRange;
}

@end
