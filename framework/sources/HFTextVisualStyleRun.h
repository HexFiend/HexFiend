//
//  HFTextVisualStyle.h
//  HexFiend_2
//
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
    NSIndexSet *bookmarkEnds;
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

- (NSIndexSet *)bookmarkStarts;
- (void)setBookmarkStarts:(NSIndexSet *)starts;

- (NSIndexSet *)bookmarkExtents;
- (void)setBookmarkExtents:(NSIndexSet *)val;

- (NSIndexSet *)bookmarkEnds;
- (void)setBookmarkEnds:(NSIndexSet *)ends;

- (void)set;

@end
