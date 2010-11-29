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

static NSString *copy1CharStringForByteValue(unsigned long long byteValue, NSUInteger bytesPerChar, NSStringEncoding encoding) {
    char bytes[sizeof byteValue];
    /* If we are little endian, then the bytesPerChar doesn't matter, because it will all come out the same.  If we are big endian, then it does matter. */
#if ! __BIG_ENDIAN__
    *(unsigned long *)bytes = byteValue;
#else
    if (bytesPerChar == sizeof(uint8_t)) {
        *(uint8_t *)bytes = (uint8_t)byteValue;
    } else if (bytesPerChar == sizeof(uint16_t)) {
        *(uint16_t *)bytes = (uint16_t)byteValue;
    } else if (bytesPerChar == sizeof(uint32_t)) {
        *(uint32_t *)bytes = (uint32_t)byteValue;
    } else if (bytesPerChar == sizeof(uint64_t)) {
        *(uint64_t *)bytes = (uint32_t)byteValue;
    } else {
        [NSException raise:NSInvalidArgumentException format:@"Unsupported bytesPerChar of %u", bytesPerChar];
    }
#endif
    /* Now create a string from these bytes */
    NSString *result = [[NSString alloc] initWithBytes:bytes length:bytesPerChar encoding:encoding];
    
    /* Ensure it has exactly one character */
    if ([result length] != 1) {
        [result release];
        result = nil;
    }
    
    /* All done */
    return result;
}

/* Generates glyphs for a range of values in  our given encoding. */
- (void)generateGlyphs:(struct HFGlyph_t *)outGlyphs forByteValuesInRange:(NSRange)range maxAdvance:(CGFloat *)outMaxAdvance {
    /* If the caller wants the advance, initialize it to 0 */
    if (outMaxAdvance) *outMaxAdvance = 0;
    
    NSFont *font = [[self font] screenFont];
    NSCharacterSet *coveredSet = [font coveredCharacterSet];
    NSMutableString *coveredGlyphFetchingString = [[NSMutableString alloc] init];
    NSMutableIndexSet *coveredGlyphIndexes = [[NSMutableIndexSet alloc] init];
    NSMutableString *substitutionFontsGlyphFetchingString = [[NSMutableString alloc] init];
    NSMutableIndexSet *substitutionGlyphIndexes = [[NSMutableIndexSet alloc] init];
    
    /* Loop over all the characters, appending them to our glyph fetching string */
    for (NSUInteger i=0; i < range.length; i++) {
        NSString *string = copy1CharStringForByteValue(i + range.location, bytesPerChar, encoding);
        if (string) {
            if ([coveredSet characterIsMember:[string characterAtIndex:0]]) {
                /* It's covered by our base font */
                [coveredGlyphFetchingString appendString:string];
                [coveredGlyphIndexes addIndex:i];
            } else {
                /* Maybe there's a substitution font */
                [substitutionFontsGlyphFetchingString appendString:string];
                [substitutionGlyphIndexes addIndex:i];
            }
        }
        [string release];        
    }
    
    /* Fetch the non-substitute glyphs */
    NEW_ARRAY(CGGlyph, cgglyphs, range.length);
    NSUInteger numGlyphs = [self _getGlyphs:cgglyphs forString:coveredGlyphFetchingString font:font];
    HFASSERT(numGlyphs == [coveredGlyphFetchingString length]);
    
    /* Fill in our glyphs array */
    NSUInteger coveredGlyphIdx = [coveredGlyphIndexes firstIndex];
    for (NSUInteger i=0; i < numGlyphs; i++) {
        outGlyphs[coveredGlyphIdx] = (struct HFGlyph_t){.fontIndex = 0, .glyph = cgglyphs[i]};
        coveredGlyphIdx = [coveredGlyphIndexes indexGreaterThanIndex:coveredGlyphIdx];
        
        /* Record the advancement.  Note that this may be more efficient to do in bulk. */
        if (outMaxAdvance) *outMaxAdvance = HFMax(*outMaxAdvance, [font advancementForGlyph:cgglyphs[i]].width);

    }
    HFASSERT(coveredGlyphIdx == NSNotFound); //we must have exhausted the table
    
    /* Now do substitution glyphs. */
    NSUInteger substitutionGlyphIndex = [substitutionGlyphIndexes firstIndex], numSubstitutionChars = [substitutionFontsGlyphFetchingString length];
    for (NSUInteger i=0; i < numSubstitutionChars; i++) {
        CTFontRef substitutionFont = CTFontCreateForString((CTFontRef)font, (CFStringRef)substitutionFontsGlyphFetchingString, CFRangeMake(i, 1));
        if (substitutionFont) {
            /* We have a font for this string */
            CGGlyph glyph;
            unichar c = [substitutionFontsGlyphFetchingString characterAtIndex:i];
            NSString *substring = [[NSString alloc] initWithCharacters:&c length:1];
            NSUInteger numGlyphs = [self _getGlyphs:&glyph forString:substring font:(NSFont *)substitutionFont];
            HFASSERT(numGlyphs == 1);
            [substring release];
            
            /* Find the index in fonts.  If none, add to it. */
            HFASSERT(fonts != nil);
            NSUInteger fontIndex = [fonts indexOfObject:(id)substitutionFont];
            if (fontIndex == NSNotFound) {
                [fonts addObject:(id)substitutionFont];
                fontIndex = [fonts count] - 1;
            }
            
            /* We're done with this */
            CFRelease(substitutionFont);
            
            /* Now make the glyph */
            HFASSERT(fontIndex < UINT16_MAX);
            outGlyphs[substitutionGlyphIndex] = (struct HFGlyph_t){.fontIndex = fontIndex, .glyph = glyph};
        }
        substitutionGlyphIndex = [substitutionGlyphIndexes indexGreaterThanIndex:substitutionGlyphIndex];
    }
    
    [coveredGlyphFetchingString release];
    [coveredGlyphIndexes release];
    [substitutionFontsGlyphFetchingString release];
    [substitutionGlyphIndexes release];
}

- (void)generateGlyphsForBucketAtIndex:(NSUInteger)idx {
    /* Fill in a bucket */
    HFASSERT(idx < 256);
    HFASSERT(glyphTable.glyphBuckets16Bit[idx] == NULL);
    glyphTable.glyphBuckets16Bit[idx] = check_calloc(256 * sizeof(struct HFGlyph_t));    
    [self generateGlyphs:glyphTable.glyphBuckets16Bit[idx] forByteValuesInRange:NSMakeRange(idx << 8, 256) maxAdvance:NULL];
}

/* Helper function for looking up a 16 bit glyph, perhaps generating the bucket */
static struct HFGlyph_t get16BitGlyph(HFRepresenterStringEncodingTextView *self, uint16_t character) {
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
    bzero(&replacementGlyph, sizeof replacementGlyph);
    glyphAdvancement = 0;
    
    if ([self font] == nil || encoding == 0) {
        return;
    }
    
    /* The fonts variable stores a list of fonts.  The first object is always the font of the view.  Later objects are substitution fonts, indexed by the fontIndex field of our HFGlyph type. */
    NSFont *font = [[self font] screenFont];
    if (fonts == nil) fonts = [[NSMutableArray alloc] init];
    [fonts removeAllObjects];
    [fonts addObject:font];
    
    bytesPerChar = HFStringEncodingCharacterLength(encoding);
    HFASSERT(bytesPerChar > 0);
    usingBuckets = (bytesPerChar > 1);
    
    if (bytesPerChar == 1) { 
        /* Generate all glyphs */
        [self generateGlyphs:glyphTable.glyphTable8Bit forByteValuesInRange:NSMakeRange(0, 256) maxAdvance:&glyphAdvancement];
        /* Ensure our advance is at least 1 */
        glyphAdvancement = HFMax(glyphAdvancement, 1.);
    } else if (bytesPerChar == 2) {
        /* Just use the max glyph advancement in this case, rounded (if we don't round we get fractional advances, which screws up our width calculations) */
        glyphAdvancement = HFRound([font maximumAdvancement].width);
        
        /* Generate the glyphs for the bucket containing '.'.  Do this by taking the string containing a period, and getting bytes in the encoding we want. */
        unsigned char replacementBuff[16];
        NSUInteger usedBuff = 0;
        NSString *replacementChar = @".";
        [replacementChar getBytes:replacementBuff maxLength:sizeof replacementBuff usedLength:&usedBuff encoding:encoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, [replacementChar length]) remainingRange:NULL];
        
        /* We generally expect usedBuff == 2, but usedBuff == 1 can come about in variable-width encodings, e.g. Big5 */
        HFASSERT(usedBuff == 1 || usedBuff == 2);
        if (usedBuff == 2) {
            replacementGlyph = get16BitGlyph(self, *(uint16_t *)replacementBuff);
        } else {
            /* Here we just promote to a 16 bit value */
            replacementGlyph = get16BitGlyph(self, *(uint8_t *)replacementBuff);
        }
    } else {
        [NSException raise:NSInvalidArgumentException format:@"Unsupported bytesPerChar: %u", bytesPerChar];
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
    [fonts release];
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
	encoding = val;
	[self generateGlyphTable];
        
        /* Redraw ourselves with our new glyphs */
        [self setNeedsDisplay:YES];
    }
}

/* Override of base class method for font substitution */
- (NSFont *)fontAtSubstitutionIndex:(uint16_t)idx {
    HFASSERT(idx < [fonts count]);
    return [fonts objectAtIndex:idx];
}

/* Override of base class method in case we are 16 bit */
- (NSUInteger)bytesPerCharacter {
    return bytesPerChar;
}

- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(struct HFGlyph_t *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
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
            struct HFGlyph_t glyph = glyphTable.glyphTable8Bit[byte];
            advances[charIndex] = advance;
            glyphs[charIndex] = glyph.glyph ? glyph : replacementGlyph;
        }
    } else if (bytesPerChar == 2) {
        HFASSERT(usingBuckets);
        for (charIndex = 0; charIndex < numChars; charIndex++) {
            NSUInteger byteIndex = charIndex * bytesPerChar;
            uint16_t hword = *(const uint16_t *)(bytes + byteIndex);
            struct HFGlyph_t glyph = get16BitGlyph(self, hword);            
            advances[charIndex] = advance;
            glyphs[charIndex] = glyph.glyph ? glyph : replacementGlyph;
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
