//
//  HFTextVisualStyle.h
//  HexFiend_2
//
//  Created by Peter Ammon on 8/29/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HFTextVisualStyleRun : NSObject {
    NSColor *foregroundColor;
    NSColor *backgroundColor;
    NSRange range;
    BOOL shouldDraw;
}

- (NSColor *)foregroundColor;
- (void)setForegroundColor:(NSColor *)theForegroundColor;

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)theBackgroundColor;

- (NSRange)range;
- (void)setRange:(NSRange)theRange;

- (BOOL)shouldDraw;
- (void)setShouldDraw:(BOOL)val;

- (void)set;

@end
