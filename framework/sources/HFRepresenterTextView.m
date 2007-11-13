//
//  HFRepresenterTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView_Internal.h>
#import <HexFiend/HFRepresenterTextLayoutManager.h>
#import <HexFiend/HFRepresenterHexTypesetter.h>
#import <HexFiend/HFRepresenter.h>

@implementation HFRepresenterTextView

/* Returns the glyphs for the given string, using the given text view, and generating the glyphs if the glyphs parameter is not NULL */
- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingTextView:(NSTextView *)textView glyphs:(CGGlyph *)glyphs {
    NSUInteger glyphIndex, glyphCount;
    HFASSERT(string != NULL);
    HFASSERT(textView != NULL);
    NSGlyph nsglyphs[GLYPH_BUFFER_SIZE];
    [textView setString:string];
    [textView setNeedsDisplay:YES]; //ligature generation doesn't seem to happen without this, for some reason.  This seems very fragile!  We should find a better way to get this ligature information!!
    glyphCount = [[textView layoutManager] getGlyphs:nsglyphs range:NSMakeRange(0, GLYPH_BUFFER_SIZE)];
    if (glyphs != NULL) {
        /* Convert from unsigned int NSGlyphs to unsigned short CGGlyphs */
        for (glyphIndex = 0; glyphIndex < glyphCount; glyphIndex++) {
            HFASSERT(nsglyphs[glyphIndex] <= USHRT_MAX);
            glyphs[glyphIndex] = (CGGlyph)nsglyphs[glyphIndex];
        }
    }
    return glyphCount;
}

- initWithRepresenter:(HFRepresenter *)rep {
    [super initWithFrame:NSMakeRect(0, 0, 1, 1)];
    horizontalContainerInset = 4;
    representer = rep;
    return self;
}

- (CGFloat)horizontalContainerInset {
    return horizontalContainerInset;
}

- (void)setHorizontalContainerInset:(CGFloat)inset {
    horizontalContainerInset = inset;
}

- (void)setFont:(NSFont *)val {
    if (val != font) {
        [font release];
        font = [val retain];
        NSLayoutManager *manager = [[NSLayoutManager alloc] init];
        defaultLineHeight = [manager defaultLineHeightForFont:font];
        [manager release];
    }
}

- (CGFloat)lineHeight {
    return defaultLineHeight;
}

- (NSFont *)font {
    return font;
}

- (NSData *)data {
    return data;
}

- (void)setData:(NSData *)val {
    if (val != data) {
        [data release];
        data = [val copy];
    }
}

- (BOOL)isFlipped {
    return YES;
}

- (HFRepresenter *)representer {
    return representer;
}

- (void)dealloc {
    [font release];
    [data release];
    [super dealloc];
}

- (NSColor *)backgroundColorForEmptySpace {
    return [[NSColor controlAlternatingRowBackgroundColors] objectAtIndex:0];
}

- (NSColor *)backgroundColorForLine:(NSUInteger)line {
    NSArray *colors = [NSColor controlAlternatingRowBackgroundColors];
    NSUInteger colorCount = [colors count];
    NSUInteger colorIndex = line % colorCount;
    if (colorIndex == 0) return nil; //will be drawn by empty space
    else return [colors objectAtIndex:colorIndex]; 
}

- (NSUInteger)bytesPerLine {
    return [[self representer] bytesPerLine];
}


- (void)_drawLineBackgrounds:(NSRect)clip withLineHeight:(CGFloat)lineHeight maxLines:(NSUInteger)maxLines {
    NSRect bounds = [self bounds];
    NSUInteger lineIndex;
    NSRect lineRect = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), lineHeight);
    NSUInteger drawableLineIndex = 0;
    NEW_ARRAY(NSRect, lineRects, maxLines);
    NEW_ARRAY(NSColor*, lineColors, maxLines);
    for (lineIndex = 0; lineIndex < maxLines; lineIndex++) {
        NSRect clippedLineRect = NSIntersectionRect(lineRect, clip);
        if (! NSIsEmptyRect(clippedLineRect)) {
            NSColor *lineColor = [self backgroundColorForLine:lineIndex];
            if (lineColor) {
                lineColors[drawableLineIndex] = lineColor;
                lineRects[drawableLineIndex] = clippedLineRect;
                drawableLineIndex++;
            }
        }
        lineRect.origin.y += lineHeight;
    }
    
    if (drawableLineIndex > 0) {
        NSRectFillListWithColorsUsingOperation(lineRects, lineColors, drawableLineIndex, NSCompositeSourceOver);
    }
    
    FREE_ARRAY(lineRects);
    FREE_ARRAY(lineColors);
}

- (void)drawRect:(NSRect)clip {
    [[self backgroundColorForEmptySpace] set];
    NSRectFill(clip);
}

- (NSUInteger)availableLineCount {
    CGFloat result = ceil(NSHeight([self bounds]) / [self lineHeight]);
    HFASSERT(result >= 0.);
    HFASSERT(result <= ULONG_MAX);
    return (NSUInteger)result;
}

- (NSUInteger)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
    CGFloat result = ceil(viewHeight / [self lineHeight]);
    HFASSERT(result >= 0.);
    HFASSERT(result <= ULONG_MAX);
    return (NSUInteger)result;
}

- (void)setFrameSize:(NSSize)size {
    NSUInteger currentBytesPerLine = [self bytesPerLine];
    NSUInteger currentLineCount = [self maximumAvailableLinesForViewHeight:NSHeight([self bounds])];
    [super setFrameSize:size];
    NSUInteger newBytesPerLine = [self maximumBytesPerLineForViewWidth:size.width];
    NSUInteger newLineCount = [self maximumAvailableLinesForViewHeight:NSHeight([self bounds])];
    HFControllerPropertyBits bits = 0;
    if (newBytesPerLine != currentBytesPerLine) bits |= HFControllerBytesPerLine;
    if (newLineCount != currentLineCount) bits |= HFControllerDisplayedRange;
    if (bits) [[self representer] viewChangedProperties:bits];
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    USE(viewWidth);
    UNIMPLEMENTED();
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    USE(bytesPerLine);
    UNIMPLEMENTED();
}

@end
