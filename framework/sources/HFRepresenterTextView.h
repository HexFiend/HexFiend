//
//  HFRepresenterTextView.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFGlyphTrie.h>

/*  Bytes per column philosophy

    _hftvflags.bytesPerColumn is the number of bytes that should be displayed consecutively, as one column. A space separates one column from the next. HexFiend 1.0 displayed 1 byte per column, and setting bytesPerColumn to 1 in this version reproduces that behavior. The vertical guidelines displayed by HexFiend 1.0 are only drawn when bytesPerColumn is set to 1.

    We use some number of bits to hold the number of bytes per column, so the highest value we can store is ((2 ^ numBits) - 1). We can't tell the user that the max is not a power of 2, so we pin the value to the highest representable power of 2, or (2 ^ (numBits - 1)). We allow integral values from 0 to the pinned maximum, inclusive; powers of 2 are not required. The setter method uses HFTV_BYTES_PER_COLUMN_MAX_VALUE to stay within the representable range.

    Since a value of zero is nonsensical, we can use it to specify no spaces at all.
*/

#define HFTV_BYTES_PER_COLUMN_MAX_VALUE (1 << (HFTV_BYTES_PER_COLUMN_BITFIELD_SIZE - 1))

@class HFTextRepresenter;


/* The base class for HFTextRepresenter views - such as the hex or ASCII text view */
@interface HFRepresenterTextView : NSView {
@private;
    HFTextRepresenter *representer;
    NSArray *cachedSelectedRanges;
    NSFont *font;
    NSData *data;
    NSArray *styles;
    CGFloat verticalOffset;
    CGFloat horizontalContainerInset;
    CGFloat defaultLineHeight;
    CFAbsoluteTime pulseStartTime;
    NSTimer *pulseTimer;
    NSTimer *caretTimer;
    NSWindow *pulseWindow;
    NSRect pulseWindowBaseFrameInScreenCoordinates;
    NSRect lastDrawnCaretRect;
    NSRect caretRectToDraw;
    NSUInteger bytesBetweenVerticalGuides;
    NSUInteger startingLineBackgroundColorIndex;
    NSArray *rowBackgroundColors;
    NSMutableDictionary *callouts;
    
    struct  {
        unsigned antialias:1;
        unsigned editable:1;
        unsigned caretVisible:1;
        unsigned registeredForAppNotifications:1;
        unsigned withinMouseDown:1;
        unsigned receivedMouseUp:1;
        unsigned reserved1:26;
        unsigned reserved2:32;
    } _hftvflags;
}

- (id)initWithRepresenter:(HFTextRepresenter *)rep;
- (void)clearRepresenter;

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

- (NSArray *)styles;
- (void)setStyles:(NSArray *)theStyles;

- (BOOL)shouldAntialias;
- (void)setShouldAntialias:(BOOL)val;

- (BOOL)behavesAsTextField;
- (BOOL)showsFocusRing;
- (BOOL)isWithinMouseDown;

- (NSRect)caretRect;

- (void)setBookmarks:(NSDictionary *)bookmarks;

- (NSPoint)originForCharacterAtByteIndex:(NSInteger)index;
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

/* For font substitution.  An index of 0 means the default (base) font. */
- (NSFont *)fontAtSubstitutionIndex:(uint16_t)idx;

/* Uniformly "rounds" the byte range so that it contains an integer number of characters.  The algorithm is to "floor:" any character intersecting the min of the range are included, and any character extending beyond the end of the range is excluded. If both the min and the max are within a single character, then an empty range is returned. */
- (NSRange)roundPartialByteRange:(NSRange)byteRange;

- (void)drawTextWithClip:(NSRect)clipRect restrictingToTextInRanges:(NSArray *)restrictingToRanges;

/* Must be overridden */
- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(struct HFGlyph_t *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount;

- (void)extractGlyphsForBytes:(const unsigned char *)bytePtr range:(NSRange)byteRange intoArray:(struct HFGlyph_t *)glyphs advances:(CGSize *)advances withInclusionRanges:(NSArray *)restrictingToRanges initialTextOffset:(CGFloat *)initialTextOffset resultingGlyphCount:(NSUInteger *)resultingGlyphCount;

/* Must be overridden - returns the max number of glyphs for a given number of bytes */
- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount;

- (void)updateSelectedRanges;
- (void)updateSelectionPulse;
- (void)terminateSelectionPulse; // Start fading the pulse.

/* Given a rect edge, return an NSRect representing the maximum edge in that direction.  The dimension in the direction of the edge is 0 (so if edge is NSMaxXEdge, the resulting width is 0).  The returned rect is in the coordinate space of the receiver's view.  If the byte range is not displayed, returns NSZeroRect.
 */
- (NSRect)furthestRectOnEdge:(NSRectEdge)edge forRange:(NSRange)range;

/* The background color for the line at the given index.  You may override this to return different colors.  You may return nil to draw no color in this line (and then the empty space color will appear) */
- (NSColor *)backgroundColorForLine:(NSUInteger)line;
- (NSColor *)backgroundColorForEmptySpace;

/* Defaults to 1, may override */
- (NSUInteger)bytesPerCharacter;

/* Cover method for [[self representer] bytesPerLine] and [[self representer] bytesPerColumn] */
- (NSUInteger)bytesPerLine;
- (NSUInteger)bytesPerColumn;

- (CGFloat)lineHeight;

/* Following two must be overridden */
- (CGFloat)advanceBetweenColumns;
- (CGFloat)advancePerCharacter;

- (CGFloat)advancePerColumn;
- (CGFloat)totalAdvanceForBytesInRange:(NSRange)range;

/* Returns the number of lines that could be shown in this view at its given height (expressed in its local coordinate space) */
- (double)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight;

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth;
- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine;

- (IBAction)selectAll:sender;


@end
