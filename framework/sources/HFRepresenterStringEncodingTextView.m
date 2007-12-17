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
                glyphAdvancement = HFMax(glyphAdvancement, [font advancementForGlyph:glyphs[0]].width);
            }
        }
        [string release];
    }
    
    /* Replacement glyph */
    CGGlyph glyphs[GLYPH_BUFFER_SIZE];
    unichar replacementChar = '.';
    [self _glyphsForString:[NSString stringWithCharacters:&replacementChar length:1] withGeneratingTextView:textView glyphs:glyphs];
    replacementGlyph = glyphs[0];
//    replacementGlyph = 0;
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
    HFASSERT(numBytes <= NSUIntegerMax);
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

- (CGFloat)spaceBetweenBytes {
    return 0;
}

- (CGFloat)advancePerByte {
    return glyphAdvancement;
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

- (void)drawTextWithClip:(NSRect)clip {
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGAffineTransform textTransform = CGContextGetTextMatrix(ctx);
    CGContextSetTextDrawingMode(ctx, kCGTextFill);

    NSRect bounds = [self bounds];
    NSData *data = [self data];
    const unsigned char *bytePtr = [data bytes];
    NSUInteger byteIndex, byteCount = [data length];
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSFont *font = [[self font] screenFont];
    [font set];

    CGFloat lineHeight = [self lineHeight];
    
    NSRect lineRectInBoundsSpace = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), lineHeight);
    
    /* Start us off with the horizontal inset and move the baseline down by the ascender so our glyphs just graze the top of our view */
    textTransform.tx += [self horizontalContainerInset];
    textTransform.ty += [font ascender];
    NSUInteger lineIndex = 0;
    NEW_ARRAY(CGGlyph, glyphs, bytesPerLine);
    for (byteIndex = 0; byteIndex < byteCount; byteIndex += bytesPerLine) {
        if (byteIndex > 0) {
            textTransform.ty += lineHeight;
            lineRectInBoundsSpace.origin.y += lineHeight;
        }
        if (NSIntersectsRect(lineRectInBoundsSpace, clip)) {
            NSUInteger numBytes = MIN(bytesPerLine, byteCount - byteIndex);
            NSUInteger resultGlyphCount = 0;
            [self extractGlyphsForBytes:bytePtr + byteIndex count:numBytes intoArray:glyphs resultingGlyphCount:&resultGlyphCount];
            HFASSERT(resultGlyphCount > 0);
            CGContextSetTextMatrix(ctx, textTransform);
            [self drawGlyphs:glyphs count:resultGlyphCount];
        }
        else if (NSMinY(lineRectInBoundsSpace) > NSMaxY(clip)) {
            break;
        }
        lineIndex++;
    }
    FREE_ARRAY(glyphs);
}

@end
