//
//  HFRepresenterTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFRepresenter;

/* The base class for HFTextRepresenter views - such as the hex or ASCII text view */
@interface HFRepresenterTextView : NSView {
    @private;
    HFRepresenter *representer;
    NSFont *font;
    NSData *data;
    CGFloat horizontalContainerInset;
    CGFloat defaultLineHeight;
}

- initWithRepresenter:(HFRepresenter *)rep;
- (HFRepresenter *)representer;

- (NSFont *)font;
- (void)setFont:(NSFont *)font;

- (NSData *)data;
- (void)setData:(NSData *)data;

/* The amount of padding space to inset from the left and right side. */
- (CGFloat)horizontalContainerInset;
- (void)setHorizontalContainerInset:(CGFloat)inset;

/* The background color for the line at the given index.  You may override this to return different colors.  You may return nil to draw no color in this line (and then the empty space color will appear) */
- (NSColor *)backgroundColorForLine:(NSUInteger)line;
- (NSColor *)backgroundColorForEmptySpace;

/* Cover method for [[self representer] bytesPerLine] */
- (NSUInteger)bytesPerLine;

- (CGFloat)lineHeight;

/* Returns the number of lines that could be shown in this view at its given height (expressed in its local coordinate space) */
- (NSUInteger)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight;

/* Abstract methods - must be implemented by subclasses */
- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth;
- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine;


@end
