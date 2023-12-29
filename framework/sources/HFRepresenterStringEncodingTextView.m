//
//  HFRepresenterStringEncodingTextView.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "HFRepresenterStringEncodingTextView.h"
#import "HFTextRepresenter_Internal.h"
#import <HexFiend/HFAssert.h>
#import <HexFiend/HFEncodingManager.h>
#import <HexFiend/HFFUnctions.h>
#import <CoreText/CoreText.h>

static NSString *copy1CharStringForByteValue(unsigned long long byteValue, NSUInteger bytesPerChar, HFStringEncoding *encoding) {
    NSString *result = nil;
    unsigned char bytes[sizeof byteValue];
    /* If we are little endian, then the bytesPerChar doesn't matter, because it will all come out the same.  If we are big endian, then it does matter. */
    *(unsigned long long *)bytes = byteValue;

    /* ASCII is mishandled :( */
    BOOL encodingOK = YES;
    if (encoding.isASCII && bytesPerChar == 1 && bytes[0] > 0x7F) {
        encodingOK = NO;
    }

    /* Now create a string from these bytes */
    if (encodingOK) {
        result = [encoding stringFromBytes:bytes length:bytesPerChar];
        
        if ([result length] > 1) {
            /* Try precomposing it */
            NSString *temp = [[result precomposedStringWithCompatibilityMapping] copy];
            result = temp;
        }
        
        /* Ensure it has exactly one character */
        if ([result length] != 1) {
            result = nil;
        }
    }
    
    /* All done */
    return result;
}

static BOOL getGlyphs(CGGlyph *glyphs, NSString *string, CTFontRef inputFont) {
    NSUInteger length = [string length];
    HFASSERT(inputFont != nil);
    NEW_ARRAY(UniChar, chars, length);
    [string getCharacters:chars range:NSMakeRange(0, length)];
    bool result = CTFontGetGlyphsForCharacters(inputFont, chars, glyphs, length);
    /* A NO return means some or all characters were not mapped.  This is OK.  We'll use the replacement glyph.  Unless we're calculating the replacement glyph!  Hmm...maybe we should have a series of replacement glyphs that we try? */
    
    ////////////////////////
    // Workaround for a Mavericks bug. Still present as of 10.9.5
    // TODO: Hmm, still? Should look into this again, either it's not a bug or Apple needs a poke.
    if(!result) for(NSUInteger i = 0; i < length; i+=15) {
        CFIndex x = length-i;
        if(x > 15) x = 15;
        result = CTFontGetGlyphsForCharacters(inputFont, chars+i, glyphs+i, x);
        if(!result) break;
    }
    ////////////////////////
    
    FREE_ARRAY(chars);
    return result;
}

static void generateGlyphs(CTFontRef baseFont, NSMutableArray *fonts, struct HFGlyph_t *outGlyphs, NSInteger bytesPerChar, HFStringEncoding *encoding, const NSUInteger *charactersToLoad, NSUInteger charactersToLoadCount, CGFloat *outMaxAdvance) {
    /* If the caller wants the advance, initialize it to 0 */
    if (outMaxAdvance) *outMaxAdvance = 0;
    
    /* Invalid glyph marker */
    const struct HFGlyph_t invalidGlyph = {.fontIndex = kHFGlyphFontIndexInvalid, .glyph = -1};
    
    NSCharacterSet *coveredSet = (__bridge_transfer NSCharacterSet *)CTFontCopyCharacterSet(baseFont);
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
            if (outMaxAdvance) {
                CGSize advance;
                CTFontGetAdvancesForGlyphs(baseFont, kCTFontOrientationVertical, cgglyphs + i, &advance, 1);
                *outMaxAdvance = HFMax(*outMaxAdvance, advance.width);
            }
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
                BOOL success = getGlyphs(&glyph, substring, substitutionFont);
                
                if (! success) {
                    /* Turns out there wasn't a glyph like we thought there would be, so set an invalid glyph marker */
                    outGlyphs[substitutionGlyphIndex] = invalidGlyph;
                } else {
                    /* Find the index in fonts.  If none, add to it. */
                    HFASSERT(fonts != nil);
                    NSUInteger fontIndex = [fonts indexOfObject:(__bridge id)substitutionFont];
                    if (fontIndex == NSNotFound) {
                        [fonts addObject:(__bridge id)substitutionFont];
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
}

@implementation HFRepresenterStringEncodingTextView
{
    HFStringEncoding *encoding;
}

- (void)threadedLoadGlyphs:(id)unused {
    /* Note that this is running on a background thread */
    USE(unused);
    
    /* Do some things under the lock. Someone else may wish to read fonts, and we're going to write to it, so make a local copy.  Also figure out what characters to load. */
    NSMutableArray *localFonts;
    NSIndexSet *charactersToLoad;
    HFASSERT(glyphLoadLock != nil);
    [glyphLoadLock lock];
    localFonts = [fonts mutableCopy];
    charactersToLoad = requestedCharacters;
    /* Set requestedCharacters to nil so that the caller knows we aren't going to check again, and will have to re-invoke us. */
    requestedCharacters = nil;
    [glyphLoadLock unlock];
    
    NSUInteger charVal, glyphIdx, charCount = [charactersToLoad count];
    NEW_ARRAY(struct HFGlyph_t, glyphs, charCount);
    
    /* Now generate our glyphs */
    NEW_ARRAY(NSUInteger, characters, charCount);
    [charactersToLoad getIndexes:characters maxCount:charCount inIndexRange:NULL];
    generateGlyphs((__bridge CTFontRef)localFonts[0], localFonts, glyphs, bytesPerChar, self.encoding, characters, charCount, NULL);
    FREE_ARRAY(characters);
    
    /* Replace fonts.  Do this before we insert into the glyph trie, because the glyph trie references fonts that we're just now putting in the fonts array. */
    HFASSERT(glyphLoadLock != nil);
    [glyphLoadLock lock];
    fonts = localFonts;
    [glyphLoadLock unlock];
    
    /* Now insert all of the glyphs into the glyph trie */
    glyphIdx = 0;
    for (charVal = [charactersToLoad firstIndex]; charVal != NSNotFound; charVal = [charactersToLoad indexGreaterThanIndex:charVal]) {
        HFGlyphTrieInsert(&glyphTable, charVal, glyphs[glyphIdx++]);
    }
    FREE_ARRAY(glyphs);
    
    /* Trigger a redisplay */
    [self performSelectorOnMainThread:@selector(triggerRedisplay:) withObject:nil waitUntilDone:NO];
}

- (void)triggerRedisplay:unused {
    USE(unused);
#if TARGET_OS_IPHONE
    [self setNeedsDisplay];
#else
    [self setNeedsDisplay:YES];
#endif
}

- (void)beginLoadGlyphsForCharacters:(NSIndexSet *)charactersToLoad {
    /* Create the operation (and maybe the operation queue itself) */
    if (! glyphLoader) {
        glyphLoader = [[NSOperationQueue alloc] init];
        [glyphLoader setMaxConcurrentOperationCount:1];
    }
    if (! fonts) {
        fonts = [NSMutableArray arrayWithObject:self.font];
    }
    
    BOOL needToStartOperation;    
    HFASSERT(glyphLoadLock != nil);
    [glyphLoadLock lock];
    if (requestedCharacters) {
        /* There's a pending request, so just add to it */
        [requestedCharacters addIndexes:charactersToLoad];
        needToStartOperation = NO;
    } else {
        /* There's no pending request, so we will create one */
        requestedCharacters = [charactersToLoad mutableCopy];
        needToStartOperation = YES;
    }
    [glyphLoadLock unlock];
    
    if (needToStartOperation) {
        NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:self selector:@selector(threadedLoadGlyphs:) object:charactersToLoad];
        [glyphLoader addOperation:op];
    }
}

- (void)dealloc {
    HFGlyphTreeFree(&glyphTable);
}

- (void)staleTieredProperties {
    tier1DataIsStale = YES;
    /* We have to free the glyph table */
    [glyphLoader waitUntilAllOperationsAreFinished];
    HFGlyphTreeFree(&glyphTable);
    HFGlyphTrieInitialize(&glyphTable, bytesPerChar);
    fonts = nil;
    fontCache = nil;
}

- (void)setFont:(HFFont *)font
{
    [self staleTieredProperties];
    /* fonts is preloaded with our one font */
    if (! fonts) fonts = [[NSMutableArray alloc] init];
    [fonts addObject:font];
    [super setFont:font];
}

- (instancetype)initWithRepresenter:(HFTextRepresenter *)rep
{
    self = [super initWithRepresenter:rep];
    encoding = [HFEncodingManager shared].ascii;
    bytesPerChar = encoding.fixedBytesPerCharacter;
    glyphLoadLock = [[NSLock alloc] init];
    [self staleTieredProperties];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    encoding = [coder decodeObjectForKey:@"HFStringEncoding"];
    bytesPerChar = encoding.fixedBytesPerCharacter;
    glyphLoadLock = [[NSLock alloc] init];
    [self staleTieredProperties];
    return self;
}

- (instancetype)initWithFrame:(CGRect)frameRect {
    self = [super initWithFrame:frameRect];
    encoding = [HFEncodingManager shared].ascii;
    bytesPerChar = encoding.fixedBytesPerCharacter;
    glyphLoadLock = [[NSLock alloc] init];
    [self staleTieredProperties];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:encoding forKey:@"HFStringEncoding"];
}

- (HFStringEncoding *)encoding {
    return encoding;
}

- (void)setEncoding:(HFStringEncoding *)val {
    if (encoding != val) {
        /* Our glyph table is now stale. Call this first to ensure our background operation is complete. */
        [self staleTieredProperties];
        
        /* Store the new encoding. */
        encoding = val;	
        
        /* Compute bytes per character */
        bytesPerChar = encoding.fixedBytesPerCharacter;
        HFASSERT(bytesPerChar > 0);
        
        /* Ensure the tree knows about the new bytes per character */
        HFGlyphTrieInitialize(&glyphTable, bytesPerChar);
		
        /* Redraw ourselves with our new glyphs */
#if TARGET_OS_IPHONE
        [self setNeedsDisplay];
#else
        [self setNeedsDisplay:YES];
#endif
    }
}

- (void)loadTier1Data {
    CTFontRef font = (__bridge CTFontRef)[self font];
    
    /* Use the max advance as the glyph advance */
#if !TARGET_OS_IPHONE
    glyphAdvancement = HFCeil([(__bridge NSFont *)font maximumAdvancement].width);
#else
    // private API :(
    extern CGSize CTFontGetMaximumAdvance(CTFontRef);
    glyphAdvancement = HFCeil(CTFontGetMaximumAdvance(font).width);
#endif

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
- (HFFont *)fontAtSubstitutionIndex:(uint16_t)idx
{
    HFASSERT(idx != kHFGlyphFontIndexInvalid);
    if (idx >= [fontCache count]) {
        /* Our font cache is out of date.  Take the lock and update the cache. */
        NSArray *newFonts = nil;
        HFASSERT(glyphLoadLock != nil);
        [glyphLoadLock lock];
        HFASSERT(idx < [fonts count]);
        newFonts = [fonts copy];
        [glyphLoadLock unlock];
        
        /* Store the new cache */
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

- (void)copyAsASCII:(id)sender {
    USE(sender);
    HFTextRepresenter *rep = [self representer];
    HFASSERT([rep isKindOfClass:[HFTextRepresenter class]]);
#if !TARGET_OS_IPHONE
    [rep copySelectedBytesToPasteboard:[NSPasteboard generalPasteboard] encoding:[HFEncodingManager shared].ascii];
#endif
}

@end
