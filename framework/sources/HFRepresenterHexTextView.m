//
//  HFRepresenterHexTextView.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterHexTextView.h>
#import <HexFiend/HFRepresenterTextView_Internal.h>
#import <HexFiend/HFRepresenter.h>

@implementation HFRepresenterHexTextView

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

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self generateGlyphTable];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    [self generateGlyphTable];
    return self;
}

//no need for encodeWithCoder

- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(struct HFGlyph_t *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
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
        
        advances[glyphIndex] = CGSizeMake(glyphAdvancement, 0);
        glyphs[glyphIndex++] = (struct HFGlyph_t){.fontIndex = 0, .glyph = glyphTable[byte >> 4]};
        advances[glyphIndex] = CGSizeMake(glyphAdvancementPlusAnySpace, 0);
        glyphs[glyphIndex++] = (struct HFGlyph_t){.fontIndex = 0, .glyph = glyphTable[byte & 0xF]};
    }
    
    *resultGlyphCount = glyphIndex;
}

- (CGFloat)advancePerCharacter {
    return 2 * glyphAdvancement;
}

- (CGFloat)advanceBetweenColumns {
    return glyphAdvancement;
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return 2 * byteCount;
}

@end
