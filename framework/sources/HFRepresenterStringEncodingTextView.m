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

typedef struct HFGlyph_t {
    uint16_t fontIndex;
    CGGlyph glyph;
};

@implementation HFRepresenterStringEncodingTextView

/* This can be used for pre-Leopard */
- (void)generateGlyphsForBucketAtIndexLegacy:(NSUInteger)idx {
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
        [string release];
    }
    [layoutManager release];
    [textStorage release];
}



- (void)generateGlyphsForBucketAtIndex:(NSUInteger)idx {
    /* Fill in a bucket */
    HFASSERT(idx < 256);
    HFASSERT(glyphTable.glyphBuckets16Bit[idx] == NULL);
    glyphTable.glyphBuckets16Bit[idx] = check_malloc(256 * sizeof(CGGlyph));
    
    NSFont *font = [[self font] screenFont];
    NSCharacterSet *coveredSet = [font coveredCharacterSet];
        
    NSUInteger lowBits;
    for (lowBits = 0; lowBits < 256; lowBits++) {
        CGGlyph glyph = 0;
        unichar c = (idx << 8) | lowBits;
        NSString *string = [[NSString alloc] initWithBytes:&c length:sizeof c encoding:encoding];
        if (string != NULL && [string length] == 1 && [coveredSet characterIsMember:[string characterAtIndex:0]]) {
            CGGlyph glyphs[GLYPH_BUFFER_SIZE];
            NSUInteger glyphCount = [self _glyphsForString:string glyphs:glyphs];
            if (glyphCount == 1) {
                glyph = glyphs[0];
            }
        }
        glyphTable.glyphBuckets16Bit[idx][lowBits] = glyph;
        [string release];
    }
}

/* Helper function for looking up a 16 bit glyph, perhaps generating the bucket */
static CGGlyph get16BitGlyph(HFRepresenterStringEncodingTextView *self, uint16_t character) {
    unsigned char bucketIndex = character >> 8, indexInBucket = character & 0xFF;
    
    /* Generate glyphs if necessary */
    if (! self->glyphTable.glyphBuckets16Bit[bucketIndex]) {
        [self generateGlyphsForBucketAtIndex:bucketIndex];
    }
    
    return self->glyphTable.glyphBuckets16Bit[bucketIndex][indexInBucket];
}

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
        /* We'll calculate the max glyph advancement as we go.  If this is a bottleneck, we can use the bulk getAdvancements:... method.  Initialize it to 1 just to be paranoid, because a 0 advance means we may compute infinite bytes per line. */
        glyphAdvancement = 1;
        NSCharacterSet *coveredSet = [font coveredCharacterSet];
        
        /* Make a string for all covered characters.  We'll get all of its glyphs at once. */
        NSUInteger byteValue;
        NSMutableIndexSet *coveredGlyphs = [[NSMutableIndexSet alloc] init];
        NSMutableString *glyphFetchingString = [[NSMutableString alloc] init];
        for (byteValue = 0; byteValue < 256; byteValue++) {
            unsigned char val = byteValue;
            NSString *string = [[NSString alloc] initWithBytes:&val length:1 encoding:encoding];
            if (string != NULL && [string length] == 1 && [coveredSet characterIsMember:[string characterAtIndex:0]]) {
                [glyphFetchingString appendString:string];
                [coveredGlyphs addIndex:byteValue];
            }
            [string release];            
        }
        
        /* Now get the glyphs */
        CGGlyph glyphs[256];
        NSUInteger numGlyphs = [self _glyphsForString:glyphFetchingString glyphs:glyphs];
        HFASSERT(numGlyphs == [glyphFetchingString length]);
        
        /* Now move them into glyphTable8Bit at their proper index, which is determined by coveredGlyphs */
        NSUInteger idxInTable = [coveredGlyphs firstIndex];
        for (NSUInteger i=0; i < numGlyphs; i++) {
            glyphTable.glyphTable8Bit[idxInTable] = glyphs[i];
            glyphAdvancement = HFMax(glyphAdvancement, [font advancementForGlyph:glyphs[i]].width);
            idxInTable = [coveredGlyphs indexGreaterThanIndex:idxInTable];
        }
        HFASSERT(idxInTable == NSNotFound); //we must have exhausted the table
        [coveredGlyphs release];
        [glyphFetchingString release];
        
        
        /* Replacement glyph */
        [self _glyphsForString:@"." glyphs:glyphs];
        replacementGlyph = glyphs[0];
    } else {
        /* Just use the max glyph advancement in this case, rounded (if we don't round we get fractional advances, which screws up our width calculations) */
        glyphAdvancement = HFRound([font maximumAdvancement].width);
        
        /* Generate the glyphs for the bucket containing '.'.  Do this by taking the string containing a period, and getting bytes in the encoding we want. */
        unsigned char replacementBuff[16];
        NSUInteger usedBuff = 0;
        NSString *replacementChar = @".";
        [replacementChar getBytes:replacementBuff maxLength:sizeof replacementBuff usedLength:&usedBuff encoding:encoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, [replacementChar length]) remainingRange:NULL];
        
        HFASSERT(usedBuff == 2); //not able to handle other values yet
        replacementGlyph = get16BitGlyph(self, *(uint16_t *)replacementBuff);
    }
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
        
        /* Redraw ourselves with our new glyphs */
        [self setNeedsDisplay:YES];
    }
}

/* Override of base class method in case we are 16 bit */
- (NSUInteger)bytesPerCharacter {
    return bytesPerChar;
}

- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(CGGlyph *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    HFASSERT(bytes != NULL);
    HFASSERT(glyphs != NULL);
    HFASSERT(resultGlyphCount != NULL);
    HFASSERT(advances != NULL);
    USE(offsetIntoLine);
    CGSize advance = CGSizeMake(glyphAdvancement, 0);
    NSUInteger charIndex, numChars = numBytes / bytesPerChar;
    if (bytesPerChar == 1) {
        HFASSERT(! usingBuckets);
        for (charIndex = 0; charIndex < numChars; charIndex++) {
            NSUInteger byteIndex = charIndex * bytesPerChar;
            unsigned char byte = bytes[byteIndex];
            CGGlyph glyph = glyphTable.glyphTable8Bit[byte];
            advances[charIndex] = advance;
            glyphs[charIndex] = glyph ? glyph : replacementGlyph;
        }
    } else if (bytesPerChar == 2) {
        HFASSERT(usingBuckets);
        for (charIndex = 0; charIndex < numChars; charIndex++) {
            NSUInteger byteIndex = charIndex * bytesPerChar;
            uint16_t hword = *(const uint16_t *)(bytes + byteIndex);
            CGGlyph glyph = get16BitGlyph(self, hword);            
            advances[charIndex] = advance;
            glyphs[charIndex] = glyph ? glyph : replacementGlyph;
        }        
    } else {
        [NSException raise:NSInvalidArgumentException format:@"Unsupported bytes per char %lu", (unsigned long)bytesPerChar];
    }
    *resultGlyphCount = numChars;
}

- (CGFloat)advancePerCharacter {
    return glyphAdvancement;
}

- (CGFloat)advanceBetweenColumns {
    return 0; //don't have any space between columns
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return byteCount / [self bytesPerCharacter];
}

@end
