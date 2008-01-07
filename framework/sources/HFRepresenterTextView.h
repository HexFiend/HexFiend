//
//  HFRepresenterTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFTextRepresenter;

/* The base class for HFTextRepresenter views - such as the hex or ASCII text view */
@interface HFRepresenterTextView : NSView {
    @private;
    HFTextRepresenter *representer;
    NSArray *cachedSelectedRanges;
    NSFont *font;
    NSData *data;
    CGFloat verticalOffset;
    CGFloat horizontalContainerInset;
    CGFloat defaultLineHeight;
    NSTimer *caretTimer;
    NSRect lastDrawnCaretRect;
    NSRect caretRectToDraw;
    NSUInteger bytesBetweenVerticalGuides;
    NSUInteger startingLineBackgroundColorIndex;
    
    struct  {
        unsigned editable:1;
        unsigned caretVisible:1;
        unsigned registeredForAppNotifications:1;
        unsigned withinMouseDown:1;
        unsigned receivedMouseUp:1;
        unsigned reserved1:27;
        unsigned reserved2:32;
    } _hftvflags;
}

- initWithRepresenter:(HFTextRepresenter *)rep;
- (HFTextRepresenter *)representer;

- (NSFont *)font;
- (void)setFont:(NSFont *)font;

/* Set and get data.  setData: will invalidate the correct regions (perhaps none) */
- (NSData *)data;
- (void)setData:(NSData *)data;

- (CGFloat)verticalOffset;
- (void)setVerticalOffset:(CGFloat)val;

- (NSUInteger)startingLineBackgroundColorIndex;
- (void)setStartingLineBackgroundColorIndex:(NSUInteger)val;

- (BOOL)isEditable;
- (void)setEditable:(BOOL)val;

- (NSRect)caretRect;

- (NSPoint)originForCharacterAtIndex:(NSUInteger)index;
- (NSUInteger)indexOfCharacterAtPoint:(NSPoint)point;

/* The amount of padding space to inset from the left and right side. */
- (CGFloat)horizontalContainerInset;
- (void)setHorizontalContainerInset:(CGFloat)inset;

/* Set the number of bytes between vertical guides.  Pass 0 to not draw the guides. */
- (void)setBytesBetweenVerticalGuides:(NSUInteger)val;
- (NSUInteger)bytesBetweenVerticalGuides;

/* To be invoked from drawRect:. */
- (void)drawCaretIfNecessaryWithClip:(NSRect)clipRect;
- (void)drawSelectionIfNecessaryWithClip:(NSRect)clipRect;

- (void)updateSelectedRanges;

/* The background color for the line at the given index.  You may override this to return different colors.  You may return nil to draw no color in this line (and then the empty space color will appear) */
- (NSColor *)backgroundColorForLine:(NSUInteger)line;
- (NSColor *)backgroundColorForEmptySpace;

/* Cover method for [[self representer] bytesPerLine] */
- (NSUInteger)bytesPerLine;

- (CGFloat)lineHeight;

- (CGFloat)advancePerByte;
- (CGFloat)spaceBetweenBytes;

/* Returns the number of lines that could be shown in this view at its given height (expressed in its local coordinate space) */
- (double)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight;

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth;
- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine;

- (IBAction)selectAll:sender;

@end
