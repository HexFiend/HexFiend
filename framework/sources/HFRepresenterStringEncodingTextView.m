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

- initWithRepresenter:(HFTextRepresenter *)rep {
    if ((self = [super initWithRepresenter:rep])) {
	encoding = NSMacOSRomanStringEncoding;
    }
    return self;
}

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
    if (encoding != val) {
	encoding = val;
	[self generateGlyphTable];
    }
}

- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes intoArray:(CGGlyph *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    HFASSERT(bytes != NULL);
    HFASSERT(glyphs != NULL);
    HFASSERT(resultGlyphCount != NULL);
    HFASSERT(advances != NULL);
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

- (CGFloat)spaceBetweenBytes {
    return 0;
}

- (CGFloat)advancePerByte {
    return glyphAdvancement;
}

- (CGFloat)totalAdvanceForBytesInRange:(NSRange)range {
    return glyphAdvancement * range.length;
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return byteCount;
}

@end
