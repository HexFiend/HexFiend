//
//  HFRepresenterStringEncodingTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterStringEncodingTextView.h>
#import <HexFiend/HFRepresenterTextView_Internal.h>
#include <malloc/malloc.h>

@implementation HFRepresenterStringEncodingTextView

/* Ligatures generally look not-so-hot with fixed pitch fonts.  Don't use them. */
- (void)generateGlyphTable {
    
    if (usingBuckets) {
        malloc_zone_batch_free(malloc_default_zone(), (void **)glyphTable.glyphBuckets16Bit, 256);
        usingBuckets = NO;
    }
    bzero(&glyphTable, sizeof glyphTable);
    replacementGlyph = 0;
    glyphAdvancement = 0;
    
    if ([self font] == nil || encoding == 0) {
        return;
    }
    
    BOOL is8Bit = HFStringEncodingIsSupersetOfASCII(encoding);
    if (is8Bit) {
        bytesPerChar = 1;
    } else {
        bytesPerChar = 2;
    }
    usingBuckets = ! is8Bit;
    
    NSFont *font = [[self font] screenFont];
    if (is8Bit) {
        /* Generate all the glyphs up front */
        NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 500, 300)];
        [textView turnOffLigatures:nil];
        NSCharacterSet *coveredSet = [font coveredCharacterSet];
        [textView setFont:font];
        
        /* We'll calculate the max glyph advancement as we go.  If this is a bottleneck, we can use the bulk getAdvancements:... method.  Initialize it to 1 just to be paranoid, because a 0 advance means we may compute infinite bytes per line. */
        glyphAdvancement = 1;
        
        NSUInteger byteValue;
        for (byteValue = 0; byteValue < 256; byteValue++) {
            unsigned char val = byteValue;
            NSString *string = [[NSString alloc] initWithBytes:&val length:1 encoding:encoding];
            if (string != NULL && [string length] == 1 && [coveredSet characterIsMember:[string characterAtIndex:0]]) {
                CGGlyph glyphs[GLYPH_BUFFER_SIZE];
                NSUInteger glyphCount = [self _glyphsForString:string withGeneratingTextView:textView glyphs:glyphs];
                if (glyphCount == 1) {
                    glyphTable.glyphTable8Bit[byteValue] = glyphs[0];
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
    } else {
        /* Just use the max glyph advancement in this case */
        glyphAdvancement = [font maximumAdvancement].width;
    }
}

- (void)generateGlyphsForBucketAtIndex:(NSUInteger)idx {
    /* Fill in a bucket */
    HFASSERT(idx < 256);
    HFASSERT(glyphTable.glyphBuckets16Bit[idx] == NULL);
    glyphTable.glyphBuckets16Bit[idx] = check_malloc(256 * sizeof(CGGlyph));
    
    NSFont *font = [[self font] screenFont];
    NSCharacterSet *coveredSet = [font coveredCharacterSet];
    
    NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:@""];
    NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
    NSTextContainer *textContainer = [[NSTextContainer alloc] init];
    [layoutManager addTextContainer:textContainer];
    [textContainer release];
    [textStorage addLayoutManager:layoutManager];
    
    NSUInteger lowBits;
    for (lowBits = 0; lowBits < 256; lowBits++) {
        CGGlyph glyph = 0;
        unichar c = (idx << 8) | lowBits;
        NSString *string = [[NSString alloc] initWithBytes:&c length:sizeof c encoding:encoding];
        if (string != NULL && [string length] == 1 && [coveredSet characterIsMember:[string characterAtIndex:0]]) {
            CGGlyph glyphs[GLYPH_BUFFER_SIZE];
            NSUInteger glyphCount = [self _glyphsForString:string withGeneratingLayoutManager:layoutManager glyphs:glyphs];
            if (glyphCount == 1) {
                glyph = glyphs[0];
            }            
        }
        glyphTable.glyphBuckets16Bit[idx][lowBits] = glyph;
    }
    [layoutManager release];
    [textStorage release];
}

- (void)finalize {
    if (usingBuckets) {
        malloc_zone_batch_free(malloc_default_zone(), (void **)glyphTable.glyphBuckets16Bit, 256);
    }
    [super finalize];
}

- (void)dealloc {
    if (usingBuckets) {
        malloc_zone_batch_free(malloc_default_zone(), (void **)glyphTable.glyphBuckets16Bit, 256);
    }
    [super dealloc];
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
        /* If we're not 8 bit, free all of the buckets */
        if (bytesPerChar > 1) {
            malloc_zone_batch_free(malloc_default_zone(), (void **)glyphTable.glyphBuckets16Bit, 256);
        }
	encoding = val;
	[self generateGlyphTable];
    }
}

/* Override of base class method in case we are 16 bit */
- (NSUInteger)_bytesPerCharacter {
    return bytesPerChar;
}

- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(CGGlyph *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    HFASSERT(bytes != NULL);
    HFASSERT(glyphs != NULL);
    HFASSERT(resultGlyphCount != NULL);
    HFASSERT(advances != NULL);
    USE(offsetIntoLine);
    HFASSERT(numBytes % bytesPerChar == 0);
    CGSize advance = CGSizeMake(glyphAdvancement, 0);
    NSUInteger byteIndex;
    if (bytesPerChar == 1) {
        HFASSERT(! usingBuckets);
        for (byteIndex = 0; byteIndex < numBytes; byteIndex++) {
            unsigned char byte = bytes[byteIndex];
            CGGlyph glyph = glyphTable.glyphTable8Bit[byte];
            advances[byteIndex] = advance;
            glyphs[byteIndex] = glyph ? glyph : replacementGlyph;
        }
    } else if (bytesPerChar == 2) {
        HFASSERT(usingBuckets);
        for (byteIndex = 0; byteIndex < numBytes; byteIndex += 2) {
            uint16_t hword = *(const uint16_t *)(bytes + byteIndex);
            unsigned char bucketIndex = hword >> 8, indexInBucket = hword & 0xFF;
            
            /* Generate glyphs for this bucket if necessary */
            if (! glyphTable.glyphBuckets16Bit[bucketIndex]) {
                [self generateGlyphsForBucketAtIndex:bucketIndex];
            }
            
            CGGlyph glyph = glyphTable.glyphBuckets16Bit[bucketIndex][indexInBucket];
            advances[byteIndex] = advance;
            glyphs[byteIndex] = glyph ? glyph : replacementGlyph;
        }        
    } else {
        [NSException raise:NSInvalidArgumentException format:@"Unsupported bytes per char %lu", (unsigned long)bytesPerChar];
    }
    *resultGlyphCount = byteIndex / bytesPerChar;
}

- (CGFloat)advancePerCharacter {
    return glyphAdvancement;
}

- (CGFloat)advanceBetweenColumns {
    return 0; //don't have any space between columns
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return byteCount;
}

@end
