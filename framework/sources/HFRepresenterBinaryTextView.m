//
//  HFRepresenterBinaryTextView.m
//  HexFiend_2
//
//  Copyright 2020 ridiculous_fish. All rights reserved.
//

#import "HFRepresenterBinaryTextView.h"
#import <HexFiend/HFBinaryGlyphTable.h>
#import <HexFiend/HFAssert.h>

static const CGFloat kHFBitAdvancementFactor = 1.25;

@implementation HFRepresenterBinaryTextView {
    HFBinaryGlyphTable *glyphTable;
}

- (void)setFont:(HFFont *)font
{
    [super setFont:font];
    glyphTable = [[HFBinaryGlyphTable alloc] initWithFont:font];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    glyphTable = [[HFBinaryGlyphTable alloc] initWithFont:self.font];
    return self;
}

- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(struct HFGlyph_t *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    HFASSERT(bytes != NULL);
    HFASSERT(glyphs != NULL);
    HFASSERT(numBytes <= NSUIntegerMax);
    HFASSERT(resultGlyphCount != NULL);
    const NSUInteger bytesPerColumn = [self bytesPerColumn];
    NSUInteger glyphIndex = 0, byteIndex = 0;
    NSUInteger remainingBytesInThisColumn = (bytesPerColumn ? bytesPerColumn - offsetIntoLine % bytesPerColumn : NSUIntegerMax);
    const CGFloat advanceBetweenColumns = [self advanceBetweenColumns];
    const CGFloat glyphAdvancement = glyphTable.advancement * kHFBitAdvancementFactor;
    while (byteIndex < numBytes) {
        const uint8_t byte = bytes[byteIndex++];
        
        CGFloat glyphAdvancementPlusAnySpace = glyphAdvancement;
        if (--remainingBytesInThisColumn == 0) {
            remainingBytesInThisColumn = bytesPerColumn;
            glyphAdvancementPlusAnySpace += advanceBetweenColumns;
        }

        for (uint8_t bit = 0x80; bit > 0; bit >>= 1) {
            advances[glyphIndex] = CGSizeMake(bit == 1 ? glyphAdvancementPlusAnySpace : glyphAdvancement, 0);
            const size_t glyphTableIndex = (byte & bit) != 0 ? 1 : 0;
            glyphs[glyphIndex++] = (struct HFGlyph_t){.fontIndex = 0, .glyph = glyphTable.table[glyphTableIndex]};
        }
    }
    
    *resultGlyphCount = glyphIndex;
}

- (CGFloat)advancePerCharacter {
    return (8 * glyphTable.advancement) * kHFBitAdvancementFactor;
}

- (CGFloat)advanceBetweenColumns {
    return glyphTable.advancement;
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return 8 * byteCount;
}

@end
