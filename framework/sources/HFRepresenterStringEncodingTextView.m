//
//  HFRepresenterStringEncodingTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterStringEncodingTextView.h>
#import <HexFiend/HFRepresenterTextView_Internal.h>

@implementation HFRepresenterStringEncodingTextView


/* Ligatures generally look not-so-hot with fixed pitch fonts.  Don't use them. */
- (void)generateGlyphTable {
    if ([self font] == nil || encoding == 0) {
        bzero(glyphTable, sizeof glyphTable);
        replacementGlyph = 0;
        glyphAdvancement = 0;
        return;
    }
    
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
    [textView release];
}

- (void)setFont:(NSFont *)font {
    [super setFont:font];
    [self generateGlyphTable];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    encoding = (NSStringEncoding)[coder decodeInt64ForKey:@"HFStringEncoding"];
    [self generateGlyphTable];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeInt64:encoding forKey:@"HFStringEncoding"];
}

- (NSStringEncoding)encoding {
    return encoding;
}

- (void)setEncoding:(NSStringEncoding)val {
    if (encoding != val) {
	encoding = val;
	[self generateGlyphTable];
    }
}

- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(CGGlyph *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    HFASSERT(bytes != NULL);
    HFASSERT(glyphs != NULL);
    HFASSERT(resultGlyphCount != NULL);
    HFASSERT(advances != NULL);
    USE(offsetIntoLine);
    CGSize advance = CGSizeMake(glyphAdvancement, 0);
    NSUInteger byteIndex;
    for (byteIndex = 0; byteIndex < numBytes; byteIndex++) {
        unsigned char byte = bytes[byteIndex];
        CGGlyph glyph = glyphTable[byte];
        if (glyph == 0) glyph = replacementGlyph;
	advances[byteIndex] = advance;
        glyphs[byteIndex] = glyph;
    }
    *resultGlyphCount = byteIndex;
    
}

- (CGFloat)advancePerByte {
    return glyphAdvancement;
}

- (CGFloat)advanceBetweenColumns {
    return 0; //don't have any space between columns
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return byteCount;
}

@end
