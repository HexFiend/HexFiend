//
//  HFRepresenterHexTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenterHexTextView.h>
#import <HexFiend/HFRepresenterTextView_Internal.h>
#import <HexFiend/HFRepresenter.h>

@implementation HFRepresenterHexTextView

- (void)generateGlyphTable {
    /* Ligature generation is context dependent.  Rather than trying to parse the font tables ourselves, we make an NSTextView and stick it in a window, and then ask it to generate the glyphs for the hex representation of all 256 possible bytes.  Note that for this to work, the text view must be told to redisplay and it must be sufficiently wide so that it does not try to break the two-character hex across lines. */

    /* It is not strictly necessary to put the text view in a window.  But if NSView were to ever optimize setNeedsDisplay: to check for a nil window (it does not), then our crazy hack for generating ligatures might fail. */
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 300)];
    [textView useAllLigatures:nil];
    NSFont *font = [[self font] screenFont];
    [textView setFont:font];

    /* We'll calculate the max glyph advancement as we go.  If this is a bottleneck, we can use the bulk getAdvancements:... method */
    glyphAdvancement = 0;

    NSUInteger nybbleValue, byteValue;
    for (nybbleValue=0; nybbleValue <= 0xF; nybbleValue++) {
        NSString *string;
        CGGlyph glyphs[GLYPH_BUFFER_SIZE];
        NSUInteger glyphCount;
        string = [[NSString alloc] initWithFormat:@"%lX", nybbleValue];
        glyphCount = [self _glyphsForString:string withGeneratingTextView:textView glyphs:glyphs];
        [string release];
        HFASSERT(glyphCount == 1); //How should I handle multiple glyphs for characters in [0-9A-Z]?  Are there any fonts that have them?  Doesn't seem likely.
        glyphTable[nybbleValue] = glyphs[0];
        glyphAdvancement = fmax(glyphAdvancement, [font advancementForGlyph:glyphs[0]].width);
    }
    
    /* As far as I know, there are no ligatures for any of the byte values.  But we try to do it anyways. */
    bzero(ligatureTable, sizeof ligatureTable);
    for (byteValue=0; byteValue <= 0xFF; byteValue++) {
        NSString *string;
        CGGlyph glyphs[GLYPH_BUFFER_SIZE];
        NSUInteger glyphCount;
        string = [[NSString alloc] initWithFormat:@"%02lX", byteValue];
        glyphCount = [self _glyphsForString:string withGeneratingTextView:textView glyphs:glyphs];
        [string release];
        if (glyphCount == 1) {
            ligatureTable[byteValue] = glyphs[0];
            glyphAdvancement = fmax(glyphAdvancement, [font advancementForGlyph:glyphs[0]].width);
        }
    }

#ifndef NDEBUG
    {
        CGGlyph glyphs[GLYPH_BUFFER_SIZE];
        [textView setFont:[NSFont fontWithName:@"Monaco" size:10.]];
        [textView useAllLigatures:nil];
        HFASSERT([self _glyphsForString:@"fire" withGeneratingTextView:textView glyphs:glyphs] == 3); //fi ligature
        HFASSERT([self _glyphsForString:@"forty" withGeneratingTextView:textView glyphs:glyphs] == 5); //no ligatures
        HFASSERT([self _glyphsForString:@"flip" withGeneratingTextView:textView glyphs:glyphs] == 3); //fl ligature
    }
#endif
    

    [textView release];
    
    spaceAdvancement = glyphAdvancement;
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self generateGlyphTable];
}

/* glyphs must have size at least 2 * numBytes */
- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes intoArray:(CGGlyph *)glyphs resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    HFASSERT(bytes != NULL);
    HFASSERT(glyphs != NULL);
    HFASSERT(numBytes <= ULONG_MAX);
    HFASSERT(resultGlyphCount != NULL);
    NSUInteger glyphIndex = 0, byteIndex = 0;
    while (byteIndex < numBytes) {
        unsigned char byte = bytes[byteIndex++];
        if (ligatureTable[byte] != 0) {
            glyphs[glyphIndex++] = ligatureTable[byte];
            NSLog(@"Ligature for %u", byte);
        }
        else {
            glyphs[glyphIndex++] = glyphTable[byte >> 4];
            glyphs[glyphIndex++] = glyphTable[byte & 0xF];
        }
    }
    *resultGlyphCount = glyphIndex;
}

- (void)drawGlyphs:(CGGlyph *)glyphs count:(NSUInteger)glyphCount {
    HFASSERT(glyphs != NULL);
    HFASSERT(glyphCount > 0);
    HFASSERT((glyphCount & 1) == 0); //we should only ever be asked to draw an even number of glyphs
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    
    NEW_ARRAY(CGSize, advances, glyphCount);
    for (NSUInteger advanceIndex = 0; advanceIndex < glyphCount; advanceIndex++) {
        CGFloat horizontalAdvance;
        if (advanceIndex & 1) horizontalAdvance = spaceAdvancement + glyphAdvancement;
        else horizontalAdvance = glyphAdvancement;
        advances[advanceIndex] = CGSizeMake(horizontalAdvance, 0);
    }
    
    CGContextShowGlyphsWithAdvances(ctx, glyphs, advances, glyphCount);
    
    FREE_ARRAY(advances);
}

/* Draw vertical guidelines every four bytes */
- (void)drawVerticalGuideLines:(NSRect)clip {
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSRect bounds = [self bounds];
    CGFloat advanceAmount = (2 * glyphAdvancement + spaceAdvancement) * 4;
    CGFloat lineOffset = NSMinX(bounds) + [self horizontalContainerInset] + advanceAmount - spaceAdvancement / 2.;
    CGFloat endOffset = NSMaxX(bounds) - [self horizontalContainerInset];
    
    NSUInteger bytesConsumed = 4; //trick to avoid drawing the last one
    [[NSColor colorWithCalibratedWhite:.8 alpha:1.f] set];
    while (lineOffset < endOffset && bytesConsumed < bytesPerLine) {
        NSRect lineRect = NSMakeRect(lineOffset - 1, NSMinY(bounds), 1, NSHeight(bounds));
        NSRect clippedLineRect = NSIntersectionRect(lineRect, clip);
        if (! NSIsEmptyRect(clippedLineRect)) NSRectFillUsingOperation(clippedLineRect, NSCompositePlusDarker);
        lineOffset += advanceAmount;
        bytesConsumed += 4;
    }
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
    NEW_ARRAY(CGGlyph, glyphs, bytesPerLine*2);
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
    
    [self drawVerticalGuideLines:clip];
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    CGFloat availableSpace = viewWidth - 2. * [self horizontalContainerInset];
    //spaceRequiredForNBytes = N * (2 * glyphAdvancement + spaceAdvancement) - spaceAdvancement
    CGFloat fractionalBytesPerLine = (availableSpace + spaceAdvancement) / (2 * glyphAdvancement + spaceAdvancement);
    return (NSUInteger)fmax(1., floor(fractionalBytesPerLine));
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    HFASSERT(bytesPerLine > 0);
    return 2. * [self horizontalContainerInset] + bytesPerLine * (2 * glyphAdvancement + spaceAdvancement);
}

@end
