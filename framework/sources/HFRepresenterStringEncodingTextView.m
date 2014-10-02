//
//  HFRepresenterStringEncodingTextView.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterStringEncodingTextView.h>
#import <HexFiend/HFRepresenterTextView_Internal.h>
#include <malloc/malloc.h>

@implementation HFRepresenterStringEncodingTextView

static NSString *copy1CharStringForByteValue(unsigned long long byteValue, NSUInteger bytesPerChar, NSStringEncoding encoding) {
    NSString *result = nil;
    unsigned char bytes[sizeof byteValue];
    /* If we are little endian, then the bytesPerChar doesn't matter, because it will all come out the same.  If we are big endian, then it does matter. */
#if ! __BIG_ENDIAN__
    *(unsigned long long *)bytes = byteValue;
#else
    if (bytesPerChar == sizeof(uint8_t)) {
        *(uint8_t *)bytes = (uint8_t)byteValue;
    } else if (bytesPerChar == sizeof(uint16_t)) {
        *(uint16_t *)bytes = (uint16_t)byteValue;
    } else if (bytesPerChar == sizeof(uint32_t)) {
        *(uint32_t *)bytes = (uint32_t)byteValue;
    } else if (bytesPerChar == sizeof(uint64_t)) {
        *(uint64_t *)bytes = (uint64_t)byteValue;
    } else {
        [NSException raise:NSInvalidArgumentException format:@"Unsupported bytesPerChar of %u", bytesPerChar];
    }
#endif

    /* ASCII is mishandled :( */
    BOOL encodingOK = YES;
    if (encoding == NSASCIIStringEncoding && bytesPerChar == 1 && bytes[0] > 0x7F) {
        encodingOK = NO;
    }

    
    
    /* Now create a string from these bytes */
    if (encodingOK) {
        result = [[NSString alloc] initWithBytes:bytes length:bytesPerChar encoding:encoding];
        
        if ([result length] > 1) {
            /* Try precomposing it */
            NSString *temp = [[result precomposedStringWithCompatibilityMapping] copy];
            [result release];
            result = temp;
        }
        
        /* Ensure it has exactly one character */
        if ([result length] != 1) {
            [result release];
            result = nil;
        }
    }
    
    /* All done */
    return result;
}

static BOOL getGlyphs(CGGlyph *glyphs, NSString *string, NSFont *inputFont) {
    NSUInteger length = [string length];
    HFASSERT(inputFont != nil);
    NEW_ARRAY(UniChar, chars, length);
    [string getCharacters:chars range:NSMakeRange(0, length)];
    bool result = CTFontGetGlyphsForCharacters((CTFontRef)inputFont, chars, glyphs, length);
    /* A NO return means some or all characters were not mapped.  This is OK.  We'll use the replacement glyph.  Unless we're calculating the replacement glyph!  Hmm...maybe we should have a series of replacement glyphs that we try? */
    
    ////////////////////////
    // Workaround for a Mavericks bug. Still present as of 10.9.5
    // TODO: Hmm, still? Should look into this again, either it's not a bug or Apple needs a poke.
    if(!result) for(NSUInteger i = 0; i < length; i+=15) {
        CFIndex x = length-i;
        if(x > 15) x = 15;
        result = CTFontGetGlyphsForCharacters((CTFontRef)inputFont, chars+i, glyphs+i, x);
        if(!result) break;
    }
    ////////////////////////
    
    FREE_ARRAY(chars);
    return result;
}

static void generateGlyphs(NSFont *baseFont, NSMutableArray *fonts, struct HFGlyph_t *outGlyphs, NSInteger bytesPerChar, NSStringEncoding encoding, const NSUInteger *charactersToLoad, NSUInteger charactersToLoadCount, CGFloat *outMaxAdvance) {
    /* If the caller wants the advance, initialize it to 0 */
    if (outMaxAdvance) *outMaxAdvance = 0;
    
    /* Invalid glyph marker */
    const struct HFGlyph_t invalidGlyph = {.fontIndex = kHFGlyphFontIndexInvalid, .glyph = -1};
    
    NSCharacterSet *coveredSet = [baseFont coveredCharacterSet];
    NSMutableString *coveredGlyphFetchingString = [[NSMutableString alloc] init];
    NSMutableIndexSet *coveredGlyphIndexes = [[NSMutableIndexSet alloc] init];
    NSMutableString *substitutionFontsGlyphFetchingString = [[NSMutableString alloc] init];
    NSMutableIndexSet *substitutionGlyphIndexes = [[NSMutableIndexSet alloc] init];
    
    /* Loop over all the characters, appending them to our glyph fetching string */
    NSUInteger idx;
    for (idx = 0; idx < charactersToLoadCount; idx++) {
        NSString *string = copy1CharStringForByteValue(charactersToLoad[idx], bytesPerChar, encoding);
        if (string == nil) {
            /* This byte value is not represented in this char set (e.g. upper 128 in ASCII) */
            outGlyphs[idx] = invalidGlyph;
        } else {
            if ([coveredSet characterIsMember:[string characterAtIndex:0]]) {
                /* It's covered by our base font */
                [coveredGlyphFetchingString appendString:string];
                [coveredGlyphIndexes addIndex:idx];
            } else {
                /* Maybe there's a substitution font */
                [substitutionFontsGlyphFetchingString appendString:string];
                [substitutionGlyphIndexes addIndex:idx];
            }
        }
        [string release];
    }
    
    
    /* Fetch the non-substitute glyphs */
    {
        NEW_ARRAY(CGGlyph, cgglyphs, [coveredGlyphFetchingString length]);
        BOOL success = getGlyphs(cgglyphs, coveredGlyphFetchingString, baseFont);
        HFASSERT(success == YES);
        NSUInteger numGlyphs = [coveredGlyphFetchingString length];
        
        /* Fill in our glyphs array */
        NSUInteger coveredGlyphIdx = [coveredGlyphIndexes firstIndex];
        for (NSUInteger i=0; i < numGlyphs; i++) {
            outGlyphs[coveredGlyphIdx] = (struct HFGlyph_t){.fontIndex = 0, .glyph = cgglyphs[i]};
            coveredGlyphIdx = [coveredGlyphIndexes indexGreaterThanIndex:coveredGlyphIdx];
            
            /* Record the advancement.  Note that this may be more efficient to do in bulk. */
            if (outMaxAdvance) *outMaxAdvance = HFMax(*outMaxAdvance, [baseFont advancementForGlyph:cgglyphs[i]].width);
            
        }
        HFASSERT(coveredGlyphIdx == NSNotFound); //we must have exhausted the table
        FREE_ARRAY(cgglyphs);
    }
    
    /* Now do substitution glyphs. */
    {
        NSUInteger substitutionGlyphIndex = [substitutionGlyphIndexes firstIndex], numSubstitutionChars = [substitutionFontsGlyphFetchingString length];
        for (NSUInteger i=0; i < numSubstitutionChars; i++) {
            CTFontRef substitutionFont = CTFontCreateForString((CTFontRef)baseFont, (CFStringRef)substitutionFontsGlyphFetchingString, CFRangeMake(i, 1));
            if (substitutionFont) {
                /* We have a font for this string */
                CGGlyph glyph;
                unichar c = [substitutionFontsGlyphFetchingString characterAtIndex:i];
                NSString *substring = [[NSString alloc] initWithCharacters:&c length:1];
                BOOL success = getGlyphs(&glyph, substring, (NSFont *)substitutionFont);
                [substring release];
                
                if (! success) {
                    /* Turns out there wasn't a glyph like we thought there would be, so set an invalid glyph marker */
                    outGlyphs[substitutionGlyphIndex] = invalidGlyph;
                } else {
                    /* Find the index in fonts.  If none, add to it. */
                    HFASSERT(fonts != nil);
                    NSUInteger fontIndex = [fonts indexOfObject:(id)substitutionFont];
                    if (fontIndex == NSNotFound) {
                        [fonts addObject:(id)substitutionFont];
                        fontIndex = [fonts count] - 1;
                    }
                    
                    /* Now make the glyph */
                    HFASSERT(fontIndex < UINT16_MAX);
                    outGlyphs[substitutionGlyphIndex] = (struct HFGlyph_t){.fontIndex = (uint16_t)fontIndex, .glyph = glyph};
                }
                
                /* We're done with this */
                CFRelease(substitutionFont);
                
            }
            substitutionGlyphIndex = [substitutionGlyphIndexes indexGreaterThanIndex:substitutionGlyphIndex];
        }
    }
    
    [coveredGlyphFetchingString release];
    [coveredGlyphIndexes release];
    [substitutionFontsGlyphFetchingString release];
    [substitutionGlyphIndexes release];
}

static int compareGlyphFontIndexes(const void *p1, const void *p2) {
    const struct HFGlyph_t *g1 = p1, *g2 = p2;
    if (g1->fontIndex != g2->fontIndex) {
        /* Prefer to sort by font index */
        return (g1->fontIndex > g2->fontIndex) - (g2->fontIndex > g1->fontIndex);
    } else {	
        /* If they have equal font indexes, sort by glyph value */
        return (g1->glyph > g2->glyph) - (g2->glyph > g1->glyph);
    }
}

- (void)threadedPrecacheGlyphs:(const struct HFGlyph_t *)glyphs withFonts:(NSArray *)localFonts count:(NSUInteger)count {
    /* This method draws glyphs anywhere, so that they get cached by CG and drawing them a second time can be fast. */
    NSUInteger i, validGlyphCount;
    
    /* We can use 0 advances */
    NEW_ARRAY(CGSize, advances, count);
    bzero(advances, count * sizeof *advances);
    
    /* Make a local copy of the glyphs, and sort them according to their font index so that we can draw them with the fewest runs. */
    NEW_ARRAY(struct HFGlyph_t, validGlyphs, count);
    
    validGlyphCount = 0;
    for (i=0; i < count; i++) {
        if (glyphs[i].glyph <= kCGGlyphMax && glyphs[i].fontIndex != kHFGlyphFontIndexInvalid) {
            validGlyphs[validGlyphCount++] = glyphs[i];
        }
    }
    qsort(validGlyphs, validGlyphCount, sizeof *validGlyphs, compareGlyphFontIndexes);
    
    /* Remove duplicate glyphs */
    NSUInteger trailing = 0;
    struct HFGlyph_t lastGlyph = {.glyph = kCGFontIndexInvalid, .fontIndex = kHFGlyphFontIndexInvalid};
    for (i=0; i < validGlyphCount; i++) {
        if (! HFGlyphEqualsGlyph(lastGlyph, validGlyphs[i])) {
            lastGlyph = validGlyphs[i];
            validGlyphs[trailing++] = lastGlyph;
        }
    }
    validGlyphCount = trailing;
    
    /* Draw the glyphs in runs */
    NEW_ARRAY(CGGlyph, cgglyphs, count);
    NSImage *glyphDrawingImage = [[NSImage alloc] initWithSize:NSMakeSize(100, 100)];
    [glyphDrawingImage lockFocus];
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    HFGlyphFontIndex runFontIndex = -1;
    NSUInteger runLength = 0;
    for (i=0; i <= validGlyphCount; i++) {
        if (i == validGlyphCount || validGlyphs[i].fontIndex != runFontIndex) {
            /* End the current run */
            if (runLength > 0) {
                NSLog(@"Drawing with %@", [localFonts[runFontIndex] screenFont]);
                [[localFonts[runFontIndex] screenFont] set];
                CGContextSetTextPosition(ctx, 0, 50);
                CGContextShowGlyphsWithAdvances(ctx, cgglyphs, advances, runLength);
            }
            NSLog(@"Drew a run of length %lu", (unsigned long)runLength);
            runLength = 0;
            if (i < validGlyphCount) runFontIndex = validGlyphs[i].fontIndex;
        }
        if (i < validGlyphCount) {
            /* Append to the current run */
            cgglyphs[runLength++] = validGlyphs[i].glyph;
        }
    }
    
    /* All done */
    [glyphDrawingImage unlockFocus];
    [glyphDrawingImage release];
    FREE_ARRAY(advances);
    FREE_ARRAY(validGlyphs);
    FREE_ARRAY(cgglyphs);
}

- (void)threadedLoadGlyphs:(id)unused {
    /* Note that this is running on a background thread */
    USE(unused);
    
    /* Do some things under the lock. Someone else may wish to read fonts, and we're going to write to it, so make a local copy.  Also figure out what characters to load. */
    NSMutableArray *localFonts;
    NSIndexSet *charactersToLoad;
    OSSpinLockLock(&glyphLoadLock);
    localFonts = [fonts mutableCopy];
    charactersToLoad = requestedCharacters;
    /* Set requestedCharacters to nil so that the caller knows we aren't going to check again, and will have to re-invoke us. */
    requestedCharacters = nil;
    OSSpinLockUnlock(&glyphLoadLock);
    
    /* The base font is the first font */
    NSFont *font = localFonts[0];
    
    NSUInteger charVal, glyphIdx, charCount = [charactersToLoad count];
    NEW_ARRAY(struct HFGlyph_t, glyphs, charCount);
    
    /* Now generate our glyphs */
    NEW_ARRAY(NSUInteger, characters, charCount);
    [charactersToLoad getIndexes:characters maxCount:charCount inIndexRange:NULL];
    generateGlyphs(font, localFonts, glyphs, bytesPerChar, encoding, characters, charCount, NULL);
    FREE_ARRAY(characters);
    
    /* The first time we draw glyphs, it's slow, so pre-cache them by drawing them now. */
    // This was disabled because it blows up the CG glyph cache
    //    [self threadedPrecacheGlyphs:glyphs withFonts:localFonts count:charCount];    
    
    /* Replace fonts.  Do this before we insert into the glyph trie, because the glyph trie references fonts that we're just now putting in the fonts array. */
    id oldFonts;
    OSSpinLockLock(&glyphLoadLock);
    oldFonts = fonts;
    fonts = localFonts;
    OSSpinLockUnlock(&glyphLoadLock);
    [oldFonts release];
    
    /* Now insert all of the glyphs into the glyph trie */
    glyphIdx = 0;
    for (charVal = [charactersToLoad firstIndex]; charVal != NSNotFound; charVal = [charactersToLoad indexGreaterThanIndex:charVal]) {
        HFGlyphTrieInsert(&glyphTable, charVal, glyphs[glyphIdx++]);
    }
    FREE_ARRAY(glyphs);
    
    /* Trigger a redisplay */
    [self performSelectorOnMainThread:@selector(triggerRedisplay:) withObject:nil waitUntilDone:NO];
    
    /* All done. We inherited the retain on requestedCharacters, so release it. */
    [charactersToLoad release];
}

- (void)triggerRedisplay:unused {
    USE(unused);
    [self setNeedsDisplay:YES];
}

- (void)beginLoadGlyphsForCharacters:(NSIndexSet *)charactersToLoad {
    /* Create the operation (and maybe the operation queue itself) */
    if (! glyphLoader) {
        glyphLoader = [[NSOperationQueue alloc] init];
        [glyphLoader setMaxConcurrentOperationCount:1];
    }
    if (! fonts) {
        NSFont *font = [self font];
        fonts = [[NSMutableArray alloc] initWithObjects:&font count:1];
    }
    
    BOOL needToStartOperation;    
    OSSpinLockLock(&glyphLoadLock);
    if (requestedCharacters) {
        /* There's a pending request, so just add to it */
        [requestedCharacters addIndexes:charactersToLoad];
        needToStartOperation = NO;
    } else {
        /* There's no pending request, so we will create one */
        requestedCharacters = [charactersToLoad mutableCopy];
        needToStartOperation = YES;
    }
    OSSpinLockUnlock(&glyphLoadLock);
    
    if (needToStartOperation) {
        NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(threadedLoadGlyphs:) object:charactersToLoad];
        [glyphLoader addOperation:op];
        [op release];
    }
}

- (void)dealloc {
    HFGlyphTreeFree(&glyphTable);
    [fonts release];
    [super dealloc];
}

- (void)staleTieredProperties {
    tier1DataIsStale = YES;
    /* We have to free the glyph table */
    requestedCancel = YES;
    [glyphLoader waitUntilAllOperationsAreFinished];
    requestedCancel = NO;
    HFGlyphTreeFree(&glyphTable);
    HFGlyphTrieInitialize(&glyphTable, bytesPerChar);
    [fonts release];
    fonts = nil;
    [fontCache release];
    fontCache = nil;
}

- (void)setFont:(NSFont *)font {
    [self staleTieredProperties];
    /* fonts is preloaded with our one font */
    if (! fonts) fonts = [[NSMutableArray alloc] init];
    [fonts addObject:font];
    [super setFont:font];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    encoding = (NSStringEncoding)[coder decodeInt64ForKey:@"HFStringEncoding"];
    bytesPerChar = HFStringEncodingCharacterLength(encoding);
    [self staleTieredProperties];
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    encoding = NSMacOSRomanStringEncoding;
    bytesPerChar = HFStringEncodingCharacterLength(encoding);
    [self staleTieredProperties];
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
        /* Our glyph table is now stale. Call this first to ensure our background operation is complete. */
        [self staleTieredProperties];
        
        /* Store the new encoding. */
        encoding = val;	
        
        /* Compute bytes per character */
        bytesPerChar = HFStringEncodingCharacterLength(encoding);
        HFASSERT(bytesPerChar > 0);
        
        /* Ensure the tree knows about the new bytes per character */
        HFGlyphTrieInitialize(&glyphTable, bytesPerChar);
		
        /* Redraw ourselves with our new glyphs */
        [self setNeedsDisplay:YES];
    }
}

- (void)loadTier1Data {
    NSFont *font = [self font];
    
    /* Use the max advance as the glyph advance */
    glyphAdvancement = HFCeil([font maximumAdvancement].width);
    
    /* Generate replacementGlyph */
    CGGlyph glyph[1];
    BOOL foundReplacement = NO;
    if (! foundReplacement) foundReplacement = getGlyphs(glyph, @".", font);
    if (! foundReplacement) foundReplacement = getGlyphs(glyph, @"*", font);
    if (! foundReplacement) foundReplacement = getGlyphs(glyph, @"!", font);
    if (! foundReplacement) {
        /* Really we should just fall back to another font in this case */
        [NSException raise:NSInternalInconsistencyException format:@"Unable to find replacement glyph for font %@", font];
    }
    replacementGlyph.fontIndex = 0;
    replacementGlyph.glyph = glyph[0];
    
    /* We're no longer stale */
    tier1DataIsStale = NO;
}

/* Override of base class method for font substitution */
- (NSFont *)fontAtSubstitutionIndex:(uint16_t)idx {
    HFASSERT(idx != kHFGlyphFontIndexInvalid);
    if (idx >= [fontCache count]) {
        /* Our font cache is out of date.  Take the lock and update the cache. */
        NSArray *newFonts = nil;
        OSSpinLockLock(&glyphLoadLock);
        HFASSERT(idx < [fonts count]);
        newFonts = [fonts copy];
        OSSpinLockUnlock(&glyphLoadLock);
        
        /* Store the new cache */
        [fontCache release];
        fontCache = newFonts;
        
        /* Now our cache should be up to date */
        HFASSERT(idx < [fontCache count]);
    }
    return fontCache[idx];
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
    
    /* Ensure we have advance, etc. before trying to use it */
    if (tier1DataIsStale) [self loadTier1Data];
    
    CGSize advance = CGSizeMake(glyphAdvancement, 0);
    NSMutableIndexSet *charactersToLoad = nil; //note: in UTF-32 this may have to move to an NSSet
    
    const uint8_t localBytesPerChar = bytesPerChar;
    NSUInteger charIndex, numChars = numBytes / localBytesPerChar, byteIndex = 0;
    for (charIndex = 0; charIndex < numChars; charIndex++) {
        NSUInteger character = -1;
        if (localBytesPerChar == 1) {
            character = *(const uint8_t *)(bytes + byteIndex);
        } else if (localBytesPerChar == 2) {
            character = *(const uint16_t *)(bytes + byteIndex);
        } else if (localBytesPerChar == 4) {
            character = *(const uint32_t *)(bytes + byteIndex);	    
        }
        
        struct HFGlyph_t glyph = HFGlyphTrieGet(&glyphTable, character);
        if (glyph.glyph == 0 && glyph.fontIndex == 0) {
            /* Unloaded glyph, so load it */
            if (! charactersToLoad) charactersToLoad = [[NSMutableIndexSet alloc] init];
            [charactersToLoad addIndex:character];
            glyph = replacementGlyph;	    
        } else if (glyph.glyph == (uint16_t)-1 && glyph.fontIndex == kHFGlyphFontIndexInvalid) {
            /* Missing glyph, so ignore it */
            glyph = replacementGlyph;
        } else {
            /* Valid glyph */
        }
        
        HFASSERT(glyph.fontIndex != kHFGlyphFontIndexInvalid);
        
        advances[charIndex] = advance;
        glyphs[charIndex] = glyph;
        byteIndex += localBytesPerChar;
    }
    *resultGlyphCount = numChars;
    
    if (charactersToLoad) {
        [self beginLoadGlyphsForCharacters:charactersToLoad];
        [charactersToLoad release];
    }
}

- (CGFloat)advancePerCharacter {
    /* The glyph advancement is determined by our glyph table */
    if (tier1DataIsStale) [self loadTier1Data];
    return glyphAdvancement;
}

- (CGFloat)advanceBetweenColumns {
    return 0; //don't have any space between columns
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    return byteCount / [self bytesPerCharacter];
}

@end
