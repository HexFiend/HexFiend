//
//  HFRepresenterStringEncodingTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenterStringEncodingTextView.h>
#import <HexFiend/HFRepresenterTextView_Internal.h>

@implementation HFRepresenterStringEncodingTextView

/* Ligatures generally look not-so-hot with fixed pitch fonts.  Don't use them. */
- (void)generateGlyphTable {
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 300)];
    [textView turnOffLigatures:nil];
    NSFont *font = [[self font] screenFont];
    NSCharacterSet *coveredSet = [font coveredCharacterSet];
    [textView setFont:font];
    
    /* We'll calculate the max glyph advancement as we go.  If this is a bottleneck, we can use the bulk getAdvancements:... method */
    glyphAdvancement = 0;
    
    NSUInteger byteValue;
    bzero(glyphTable, sizeof glyphTable);
    for (byteValue = 0; byteValue < 256; byteValue++) {
        unsigned char val = byteValue;
        NSString *string = [[NSString alloc] initWithBytes:&val length:1 encoding:encoding];
        if (string != NULL && [string length] == 1 && [coveredSet characterIsMember:[string characterAtIndex:0]]) {
            CGGlyph glyphs[GLYPH_BUFFER_SIZE];
            NSUInteger glyphCount = [self _glyphsForString:string withGeneratingTextView:textView glyphs:glyphs];
            if (glyphCount == 1) {
                glyphTable[byteValue] = glyphs[0];
                glyphAdvancement = fmax(glyphAdvancement, [font advancementForGlyph:glyphs[0]].width);
            }
        }
        [string release];
    }
    
    /* Replacement glyph */
    CGGlyph glyphs[GLYPH_BUFFER_SIZE];
    [self _glyphsForString:@"." withGeneratingTextView:textView glyphs:glyphs];
    replacementGlyph = glyphs[0];
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self generateGlyphTable];
}

- (NSStringEncoding)encoding {
    return encoding;
}

- (void)setEncoding:(NSStringEncoding)val {
    encoding = val;
}

/* glyphs must have size at least numBytes */
- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes intoArray:(CGGlyph *)glyphs resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    HFASSERT(bytes != NULL);
    HFASSERT(glyphs != NULL);
    HFASSERT(numBytes <= ULONG_MAX);
    HFASSERT(resultGlyphCount != NULL);
    NSUInteger glyphIndex = 0, byteIndex = 0;
    while (byteIndex < numBytes) {
        unsigned char byte = bytes[byteIndex++];
        CGGlyph glyph = glyphTable[byte];
        if (glyph == 0) glyph = replacementGlyph;
        glyphs[glyphIndex++] = glyph;
    }
    *resultGlyphCount = glyphIndex;
}

- (void)drawGlyphs:(CGGlyph *)glyphs count:(NSUInteger)glyphCount {
    HFASSERT(glyphs != NULL);
    HFASSERT(glyphCount > 0);
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    
    NEW_ARRAY(CGSize, advances, glyphCount);
    for (NSUInteger advanceIndex = 0; advanceIndex < glyphCount; advanceIndex++) {
        advances[advanceIndex] = CGSizeMake(glyphAdvancement, 0);
    }
    
    CGContextShowGlyphsWithAdvances(ctx, glyphs, advances, glyphCount);
    
    FREE_ARRAY(advances);
}

- (void)drawRect:(NSRect)clip {
    NSUInteger bytesPerLine = [self bytesPerLine];
    if (bytesPerLine == 0) return;

    NSRect bounds = [self bounds];
    
    [super drawRect:clip];
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    
    NSData *data = [self data];
    const unsigned char *bytePtr = [data bytes];
    NSUInteger byteIndex, byteCount = [data length];
    
    NSFont *font = [[self font] screenFont];
    [font set];
    
    NSColor *textColor = [NSColor blackColor];
    
    CGFloat lineHeight = [self lineHeight];
    CGFloat horizontalContainerInset = [self horizontalContainerInset];
    
    NSRect lineRectInBoundsSpace = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), lineHeight);
    
    [self _drawLineBackgrounds:clip withLineHeight:lineHeight maxLines: MIN((byteCount + bytesPerLine - 1) / bytesPerLine, (NSUInteger)ceil(NSHeight(bounds) / lineHeight))];
    
    CGContextSaveGState(ctx);
    CGAffineTransform textTransform = CGContextGetTextMatrix(ctx);
    CGContextSetTextDrawingMode(ctx, kCGTextFill);

    /* Start us off with the horizontal inset and move the baseline down by the ascender so our glyphs just graze the top of our view */
    CGContextTranslateCTM(ctx, horizontalContainerInset, [font ascender]);
    NSUInteger lineIndex = 0;
    NEW_ARRAY(CGGlyph, glyphs, bytesPerLine);
    for (byteIndex = 0; byteIndex < byteCount; byteIndex += bytesPerLine) {
        if (byteIndex > 0) {
            CGContextSetTextMatrix(ctx, textTransform);
            CGContextTranslateCTM(ctx, 0, lineHeight);
            lineRectInBoundsSpace.origin.y += lineHeight;
        }
        if (NSIntersectsRect(lineRectInBoundsSpace, clip)) {
            NSUInteger numBytes = MIN(bytesPerLine, byteCount - byteIndex);
            NSUInteger resultGlyphCount = 0;
            [self extractGlyphsForBytes:bytePtr + byteIndex count:numBytes intoArray:glyphs resultingGlyphCount:&resultGlyphCount];
            HFASSERT(resultGlyphCount > 0);
            [textColor set];
            [self drawGlyphs:glyphs count:resultGlyphCount];
        }
        lineIndex++;
    }
    FREE_ARRAY(glyphs);
    
    CGContextRestoreGState(ctx);
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    CGFloat availableSpace = viewWidth - 2. * [self horizontalContainerInset];
    //spaceRequiredForNBytes = N * glyphAdvancement
    CGFloat fractionalBytesPerLine = availableSpace / glyphAdvancement;
    return (NSUInteger)fmax(1., floor(fractionalBytesPerLine));
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    HFASSERT(bytesPerLine > 0);
    return 2. * [self horizontalContainerInset] + bytesPerLine * glyphAdvancement;
}

@end
