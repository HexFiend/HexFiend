//
//  HFRepresenterHexTextView.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "HFRepresenterHexTextView.h"
#import <HexFiend/HFHexGlyphTable.h>
#import <HexFiend/HFAssert.h>

@implementation HFRepresenterHexTextView {
    HFHexGlyphTable *glyphTable;
    
    BOOL hidesNullBytes;
}

- (void)setFont:(HFFont *)font
{
    [super setFont:font];
    glyphTable = [[HFHexGlyphTable alloc] initWithFont:font];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    glyphTable = [[HFHexGlyphTable alloc] initWithFont:self.font];
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
    const CGFloat glyphAdvancement = glyphTable.advancement;
    while (byteIndex < numBytes) {
        unsigned char byte = bytes[byteIndex++];
        
        CGFloat glyphAdvancementPlusAnySpace = glyphAdvancement;
        if (--remainingBytesInThisColumn == 0) {
            remainingBytesInThisColumn = bytesPerColumn;
            glyphAdvancementPlusAnySpace += advanceBetweenColumns;
        }
        
        BOOL useBlank = (hidesNullBytes && byte == 0);
        advances[glyphIndex] = CGSizeMake(glyphAdvancement, 0);
        glyphs[glyphIndex++] = (struct HFGlyph_t){.fontIndex = 0, .glyph = glyphTable.table[(useBlank? 16: byte >> 4)]};
        advances[glyphIndex] = CGSizeMake(glyphAdvancementPlusAnySpace, 0);
        glyphs[glyphIndex++] = (struct HFGlyph_t){.fontIndex = 0, .glyph = glyphTable.table[(useBlank? 16: byte & 0xF)]};
    }
    
    *resultGlyphCount = glyphIndex;
}

- (CGFloat)advancePerCharacter {
    return 2 * glyphTable.advancement;
}

- (CGFloat)advanceBetweenColumns {
    return glyphTable.advancement;
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return 2 * byteCount;
}

- (BOOL)hidesNullBytes {
    return hidesNullBytes;
}

- (void)setHidesNullBytes:(BOOL)flag
{
    flag = !! flag;
    if (hidesNullBytes != flag) {
        hidesNullBytes = flag;
#if TARGET_OS_IPHONE
        [self setNeedsDisplay];
#else
        [self setNeedsDisplay:YES];
#endif
    }
}

@end
