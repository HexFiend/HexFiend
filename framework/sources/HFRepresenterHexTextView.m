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
    const UniChar hexchars[16] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'};
    _Static_assert(sizeof(CGGlyph[16]) == sizeof(glyphTable), "glyphTable is the wrong type");
    NSFont *font = [[self font] screenFont];
    
    bool t = CTFontGetGlyphsForCharacters((CTFontRef)font, hexchars, glyphTable, 16);
    HFASSERT(t); // We don't take kindly to strange fonts around here.
    
    CGFloat maxAdv = 0.0;
    for(int i = 0; i < 16; i++) maxAdv = HFMax(maxAdv, [font advancementForGlyph:glyphTable[0]].width);
    glyphAdvancement = maxAdv;
    spaceAdvancement = maxAdv;
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self generateGlyphTable];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
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
