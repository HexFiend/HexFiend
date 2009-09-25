//
//  HFRepresenterHexTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterHexTextView.h>
#import <HexFiend/HFRepresenterTextView_Internal.h>
#import <HexFiend/HFRepresenter.h>

@implementation HFRepresenterHexTextView

#define TRY_TO_USE_LIGATURES 0

#if TRY_TO_USE_LIGATURES

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
        glyphAdvancement = HFMax(glyphAdvancement, [font advancementForGlyph:glyphs[0]].width);
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
            glyphAdvancement = HFMax(glyphAdvancement, [font advancementForGlyph:glyphs[0]].width);
        }
    }

#ifndef NDEBUG
    {
        CGGlyph glyphs[GLYPH_BUFFER_SIZE];
        [textView setFont:[NSFont fontWithName:@"Monaco" size:(CGFloat)10.]];
        [textView useAllLigatures:nil];
        HFASSERT(! HFIsRunningOnLeopardOrLater() || [self _glyphsForString:@"fire" withGeneratingTextView:textView glyphs:glyphs] == 3); //fi ligature
        HFASSERT([self _glyphsForString:@"forty" withGeneratingTextView:textView glyphs:glyphs] == 5); //no ligatures
        HFASSERT(! HFIsRunningOnLeopardOrLater() || [self _glyphsForString:@"flip" withGeneratingTextView:textView glyphs:glyphs] == 3); //fl ligature
    }
#endif
    

    [textView release];
    
    spaceAdvancement = glyphAdvancement;
}

#else

- (void)generateGlyphTable {
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    [layoutManager setBackgroundLayoutEnabled:NO];
    NSTextStorage *storage = [[NSTextStorage alloc] init];
    [storage addLayoutManager:layoutManager];
    NSFont *font = [[self font] screenFont];
    
    /* We'll calculate the max glyph advancement as we go.  If this is a bottleneck, we can use the bulk getAdvancements:... method */
    glyphAdvancement = 0;

    NSUInteger nybbleValue;
    for (nybbleValue=0; nybbleValue <= 0xF; nybbleValue++) {
        NSString *string;
        NSGlyph glyphs[GLYPH_BUFFER_SIZE];
        NSUInteger glyphCount;
        string = [[NSString alloc] initWithFormat:@"%lX", nybbleValue];
        [[storage mutableString] setString:string];
        [storage addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, 1)];
        [string release];
        if (HFIsRunningOnLeopardOrLater()) [layoutManager invalidateLayoutForCharacterRange:NSMakeRange(0, 1) actualCharacterRange:NULL];
        HFASSERT([layoutManager numberOfGlyphs] == 1);
        glyphCount = [layoutManager getGlyphs:glyphs range:NSMakeRange(0, 1)];
        HFASSERT(glyphCount == 1); //How should I handle multiple glyphs for characters in [0-9A-Z]?  Are there any fonts that have them?  Doesn't seem likely.
        glyphTable[nybbleValue] = glyphs[0];
        glyphAdvancement = HFMax(glyphAdvancement, [font advancementForGlyph:glyphs[0]].width);
    }
    
    [storage release];
    [layoutManager release];
    
    spaceAdvancement = glyphAdvancement;
}

#endif

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self generateGlyphTable];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    [self generateGlyphTable];
    return self;
}

//no need for encodeWithCoder

- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(CGGlyph *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    HFASSERT(bytes != NULL);
    HFASSERT(glyphs != NULL);
    HFASSERT(numBytes <= NSUIntegerMax);
    HFASSERT(resultGlyphCount != NULL);
    const NSUInteger bytesPerColumn = [self bytesPerColumn];
    NSUInteger glyphIndex = 0, byteIndex = 0;
    NSUInteger remainingBytesInThisColumn = (bytesPerColumn ? bytesPerColumn - offsetIntoLine % bytesPerColumn : NSUIntegerMax);
    CGFloat advanceBetweenColumns = [self advanceBetweenColumns];
    while (byteIndex < numBytes) {
        unsigned char byte = bytes[byteIndex++];
        
        CGFloat glyphAdvancementPlusAnySpace = glyphAdvancement;
        if (--remainingBytesInThisColumn == 0) {
            remainingBytesInThisColumn = bytesPerColumn;
            glyphAdvancementPlusAnySpace += advanceBetweenColumns;
        }
        
        if (ligatureTable[byte] != 0) {
            advances[glyphIndex] = CGSizeMake(glyphAdvancementPlusAnySpace, 0);
            glyphs[glyphIndex++] = ligatureTable[byte];
        }
        else {
            advances[glyphIndex] = CGSizeMake(glyphAdvancement, 0);
            glyphs[glyphIndex++] = glyphTable[byte >> 4];
            advances[glyphIndex] = CGSizeMake(glyphAdvancementPlusAnySpace, 0);
            glyphs[glyphIndex++] = glyphTable[byte & 0xF];
        }
    }
    
    *resultGlyphCount = glyphIndex;
}

- (CGFloat)advancePerByte {
    return 2 * glyphAdvancement;
}

- (CGFloat)advanceBetweenColumns {
    return glyphAdvancement;
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return 2 * byteCount;
}

@end
