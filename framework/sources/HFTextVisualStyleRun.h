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
    CGFloat scale;
    BOOL shouldDraw;
    NSIndexSet *bookmarkStarts;
    NSIndexSet *bookmarkExtents;
}

- (NSColor *)foregroundColor;
- (void)setForegroundColor:(NSColor *)theForegroundColor;

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)theBackgroundColor;

- (NSRange)range;
- (void)setRange:(NSRange)theRange;

- (BOOL)shouldDraw;
- (void)setShouldDraw:(BOOL)val;

- (CGFloat)scale;
- (void)setScale:(CGFloat)val;

- (NSIndexSet *)bookmarkStarts:(NSIndexSet *)bookmarksStarts;
- (void)setBookmarkStarts:(NSIndexSet *)starts;

- (NSIndexSet *)bookmarkExtents;
- (void)setBookmarkExtents:(NSIndexSet *)val;

- (void)set;

@end
