//
//  HFByteArray_FindReplace.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/8/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFProgressTracker.h>

unsigned char* boyer_moore_helper(const unsigned char * restrict haystack, const unsigned char * restrict needle, unsigned long haystack_length, unsigned long needle_length, const unsigned long * restrict char_jump, const unsigned long * restrict match_jump) {
    unsigned long ua, ub;
    
    const unsigned char *u_pat = needle + needle_length;
    const unsigned char *u_text = haystack + needle_length - 1;
    
    const unsigned char *const end_haystack = haystack + haystack_length;
    
    if (haystack_length > 12 * needle_length) {
	const unsigned char *end_quick_look = haystack + haystack_length - 11 * needle_length;
	for (;;) {
	    while (u_text < end_quick_look) {
		unsigned long offset;
		offset = char_jump[*u_text]; u_text += offset;
		offset = char_jump[*u_text]; u_text += offset;
		if (offset == 0) goto stage2;
		
		offset = char_jump[*u_text]; u_text += offset;
		offset = char_jump[*u_text]; u_text += offset;
		offset = char_jump[*u_text]; u_text += offset;
		if (offset == 0) goto stage2;
		
		offset = char_jump[*u_text]; u_text += offset;
		offset = char_jump[*u_text]; u_text += offset;
		offset = char_jump[*u_text]; u_text += offset;
		if (offset == 0) goto stage2;
		
		offset = char_jump[*u_text]; u_text += offset;
		offset = char_jump[*u_text]; u_text += offset;
		if (offset == 0) goto stage2;
	    }
	    break;
	    
stage2:
	    u_text--;
	    u_pat--;
	    while (u_pat > needle) {
		if (*u_text == u_pat[-1]) {
		    u_text--;
		    u_pat--;
		} else {
		    ua = char_jump[*u_text];
		    ub = match_jump[u_pat - needle];
		    
		    unsigned long result;
		    
		    result = (ua > ub ? ua : ub);
		    
		    u_text += result;
		    
		    u_pat = needle + needle_length;
		    break;
		}
	    }
	    if (u_pat == needle) {
		return (unsigned char*)(u_text + 1);
	    }
	}
    }
    

    while (u_text < end_haystack && u_pat > needle) {
	if (*u_text == u_pat[-1]) {
	    u_text--;
	    u_pat--;
	} else {
	    ua = char_jump[*u_text];
	    ub = match_jump[u_pat - needle];
	    
	    unsigned long result;
	    
	    result = (ua > ub ? ua : ub);
	    
	    u_text += result;
	    
	    u_pat = needle + needle_length;
	}
    }
    
    if (u_pat == needle) {
	return (unsigned char*)(u_text + 1);
    } else {
	return NULL;
    }
}

@implementation HFByteArray (HFFindReplace)

- (void)_copyBytes:(unsigned char *)bytes range:(HFRange)range forwards:(BOOL)forwards inEnclosingRange:(HFRange)enclosingRange {
    if (forwards) {
        [self copyBytes:bytes range:range];
    }
    else {
        unsigned long long endEnclosingRange = HFMaxRange(enclosingRange);
        HFASSERT(HFMaxRange(range) <= endEnclosingRange);
        HFRange invertedRange = HFRangeMake(endEnclosingRange - range.length - range.location, range.length);
        
        if (0 && invertedRange.length <= SEARCH_CHUNK_SIZE) {
            /* Copy to a temporary buffer, then reverse to the output buffer */
            unsigned char tempBuffer[SEARCH_CHUNK_SIZE];
            NSUInteger index = ll2l(invertedRange.length);
            [self copyBytes:tempBuffer range:invertedRange];
            while (index--) {
                *bytes++ = tempBuffer[index];
            }
        }
        else {
            /* Copy backwards - from the end, and then invert the bytes */
            [self copyBytes:bytes range:invertedRange];
            /* Reverse the bytes */
            NSUInteger i, max = ll2l(invertedRange.length);
            NSUInteger mid = max / 2;
            for (i=0; i < mid; i++) {
                unsigned char temp = bytes[i];
                bytes[i] = bytes[max - 1 - i];
                bytes[max - 1 - i] = temp;
            }
        }
    }
}

- (unsigned long long)_byteSearchBoyerMoore:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker {
    unsigned long long result = ULLONG_MAX;
    unsigned char *needle = NULL, *haystack = NULL;
    unsigned long *match_jump = NULL;
    unsigned long long tempProgressValue = 0;
    int tempCancelRequested = 0;
    volatile unsigned long long * const progressValuePtr = (progressTracker ? &progressTracker->currentProgress : &tempProgressValue);
    volatile int *cancelRequested = progressTracker ? &progressTracker->cancelRequested : &tempCancelRequested;
    if (*cancelRequested) goto cancelled;
    unsigned long needle_length = ll2l([findBytes length]);
    needle = malloc(needle_length);
    if (! needle) {
	NSLog(@"Out of memory allocating %lu bytes", needle_length);
	return ULLONG_MAX;
    }
    [findBytes _copyBytes:needle range:HFRangeMake(0, needle_length) forwards:forwards inEnclosingRange:HFRangeMake(0, needle_length)];
    if (*cancelRequested) goto cancelled;

    const unsigned long long total_haystack_length = range.length;
    unsigned long haystack_bytes_to_allocate;
    
    BOOL search_with_chunks = total_haystack_length > SEARCH_CHUNK_SIZE + needle_length;
    unsigned long needle_length_rounded_up_to_page_size = 0;
    
    /* does the haystack fit entirely in memory? */
    if (! search_with_chunks) haystack_bytes_to_allocate = ll2l(total_haystack_length);
    else {
	/* we are searching by chunks, so we will need to prepend up to needle_length bytes to handle the case where a result overlaps two chunks.  To get our base buffer page-aligned, we round needle_length up to a page size */
	unsigned long needle_length_page_overflow = needle_length % PAGE_SIZE;
	needle_length_rounded_up_to_page_size = needle_length + (needle_length_page_overflow ? (PAGE_SIZE - needle_length_page_overflow) : 0);
	
	haystack_bytes_to_allocate = SEARCH_CHUNK_SIZE + needle_length_rounded_up_to_page_size;
    }
    
    haystack = malloc(haystack_bytes_to_allocate);
    if (! haystack) {
	free(needle);
	NSLog(@"Out of memory allocating %lu bytes", haystack_bytes_to_allocate);
	return ULLONG_MAX;
    }

    /* generate the two Boyer-Moore auxiliary buffers */
    unsigned long char_jump[UCHAR_MAX + 1] = {0};
    match_jump = malloc(2 * (needle_length + 1) * sizeof *match_jump);
    if (! match_jump) {
	NSLog(@"Out of memory allocating %u bytes", (2 * (needle_length + 1) * sizeof *match_jump));
	free(haystack);
	free(needle);
        return ULLONG_MAX;
    }
    
    if (*cancelRequested) goto cancelled;
    
    unsigned long *backup;
    unsigned long u, ua, ub;
    backup = match_jump + needle_length + 1;
    
    /* heuristic #1 setup, simple text search */
    for (u=0; u < sizeof char_jump / sizeof *char_jump; u++)
	char_jump[u] = needle_length;
    
    for (u = 0; u < needle_length; u++)
	char_jump[((unsigned char) needle[u])] = needle_length - u - 1;


    /* heuristic #2 setup, repeating pattern search */
    for (u = 1; u <= needle_length; u++)
	match_jump[u] = 2 * needle_length - u;
    
    u = needle_length;
    ua = needle_length + 1;
    while (u > 0) {
	backup[u] = ua;
	while (ua <= needle_length && needle[u - 1] != needle[ua - 1]) {
	    if (match_jump[ua] > needle_length - u) match_jump[ua] = needle_length - u;
	    ua = backup[ua];
	}
	u--; ua--;
    }
    
    for (u = 1; u <= ua; u++)
	if (match_jump[u] > needle_length + ua - u) match_jump[u] = needle_length + ua - u;
    
    ub = backup[ua];
    while (ua <= needle_length) {
	while (ua <= ub) {
	    if (match_jump[ua] > ub - ua + needle_length)
		match_jump[ua] = ub - ua + needle_length;
	    ua++;
	}
	ub = backup[ub];
    }
    
    if (*cancelRequested) goto cancelled;
    
    /* start the search */
    if (! search_with_chunks) {
	unsigned long haystack_length = ll2l(total_haystack_length);
	[self _copyBytes:haystack range:range forwards:forwards inEnclosingRange:range];
	unsigned char *search_result = boyer_moore_helper(haystack, needle, haystack_length, needle_length, char_jump, match_jump);
        HFAtomicAdd64(haystack_length, (int64_t *)progressValuePtr);
	if (search_result == NULL) {
            result = ULLONG_MAX;
        }
	else {
            result = range.location + (search_result - haystack);
            /* Compensate for the reversing that _copyBytes does when searching backwards */
            if (! forwards) {
                result = HFMaxRange(range) - result - needle_length;
            }
        }
    }
    else {
	unsigned char * const base_read_in_location = haystack + needle_length_rounded_up_to_page_size;
	unsigned char * const base_copy_location = base_read_in_location - needle_length;
	unsigned char * const base_copy_src = base_read_in_location + SEARCH_CHUNK_SIZE - needle_length;
	HFRange remaining_range = range;
	
	/* start us off */
	HFRange search_range = remaining_range;
	if (search_range.length > SEARCH_CHUNK_SIZE) search_range.length = SEARCH_CHUNK_SIZE;
	[self _copyBytes:base_read_in_location range:search_range forwards:forwards inEnclosingRange:range];
	unsigned char *search_result = boyer_moore_helper(base_read_in_location, needle, SEARCH_CHUNK_SIZE, needle_length, char_jump, match_jump);
        if (*cancelRequested) goto cancelled;
        HFAtomicAdd64(search_range.length, (int64_t *)progressValuePtr);
	if (search_result) {
            result = search_range.location + (search_result - base_read_in_location);
            /* Compensate for the reversing that _copyBytes does when searching backwards */
            if (! forwards) {
                result = HFMaxRange(range) - result - needle_length;
            }            
        }
	else {
	    result = ULLONG_MAX;
	    remaining_range.location += search_range.length - needle_length;
	    remaining_range.length -= search_range.length - needle_length;
	    while (remaining_range.length > needle_length) {
		search_range = remaining_range;
		if (search_range.length > SEARCH_CHUNK_SIZE + needle_length) search_range.length = SEARCH_CHUNK_SIZE + needle_length;
		memmove(base_copy_location, base_copy_src, needle_length);
		
		HFRange copy_range = search_range;
		copy_range.location += llmin(copy_range.length, needle_length);
		copy_range.length -= llmin(copy_range.length, needle_length);
		
		if (copy_range.length) [self _copyBytes:base_read_in_location range:copy_range forwards:forwards inEnclosingRange:range];
		
		search_result = boyer_moore_helper(base_copy_location, needle, ll2l(search_range.length), needle_length, char_jump, match_jump);
                if (*cancelRequested) goto cancelled;
                HFAtomicAdd64(search_range.length, (int64_t *)progressValuePtr);
		if (search_result) {
		    result = search_range.location + (search_result - base_copy_location);
                    /* Compensate for the reversing that _copyBytes does when searching backwards */
                    if (! forwards) {
                        result = HFMaxRange(range) - result - needle_length;
                    }
		    break;
		}
		else {
		    remaining_range.location += search_range.length - needle_length;
		    remaining_range.length -= search_range.length - needle_length;
		}
	    }
	}
    }
    
cancelled:
    
    free(needle);
    free(haystack);
    free(match_jump);
    return result;
}

- (unsigned long long)_byteSearchSingle:(unsigned char)byte inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker {
    unsigned long long tempProgressValue = 0;
    unsigned long long result = ULLONG_MAX;
    volatile unsigned long long * const progressValuePtr = (progressTracker ? &progressTracker->currentProgress : &tempProgressValue);
    volatile int *cancelRequested = &progressTracker->cancelRequested;
        
    unsigned char buff[SEARCH_CHUNK_SIZE];
    HFRange remainingRange = range;
    while (remainingRange.length > 0) {
        if (*cancelRequested) goto cancelled;
        NSUInteger lengthToCopy = ll2l(MIN(remainingRange.length, sizeof buff));
        [self _copyBytes:buff range:HFRangeMake(remainingRange.location, lengthToCopy) forwards:forwards inEnclosingRange:range];
        if (*cancelRequested) goto cancelled;
        unsigned char *resultPtr = HFFastMemchr(buff, byte, lengthToCopy);
        if (resultPtr) {
            result = HFSum((resultPtr - buff), remainingRange.location);
            if (! forwards) {
                /* Because we reversed everything while searching, our result itself is reversed; so reverse it again */
                HFASSERT(result < HFMaxRange(range));
                result = HFMaxRange(range) - result - 1/*found range length*/;
            }
            break;
        }
        remainingRange.location = HFSum(remainingRange.location, lengthToCopy);
        remainingRange.length -= lengthToCopy;
        HFAtomicAdd64(lengthToCopy, (int64_t *)progressValuePtr);
    }
    return result;
    
    cancelled:
    return ULLONG_MAX;
}

#define ROLLING_HASH_BASE 269
#define ROLLING_HASH_INIT 0
typedef NSUInteger RollingHash_t;

static inline RollingHash_t hash_bytes(const unsigned char *bytes, NSUInteger length, RollingHash_t initial) {
    RollingHash_t result = initial;
    NSUInteger i;
    for (i=0; i < length; i++) {
        result = result * ROLLING_HASH_BASE + bytes[i];
    }
    return result;
}

static RollingHash_t hash_byte_array(HFByteArray *bytes, HFRange rangeToHash, BOOL forwards, HFRange enclosingRange, const volatile int *cancelRequested) {
    NSCParameterAssert(bytes != NULL);
    HFRange remainingRange = rangeToHash;
    RollingHash_t hash = ROLLING_HASH_INIT;
    while (remainingRange.length) {
        if (*cancelRequested) break;
        unsigned char buff[SEARCH_CHUNK_SIZE];
        NSUInteger lengthToCopy = ll2l(MIN(remainingRange.length, sizeof buff));
        [bytes _copyBytes:buff range:HFRangeMake(remainingRange.location, lengthToCopy) forwards:forwards inEnclosingRange:enclosingRange];
        remainingRange.length -= lengthToCopy;
        remainingRange.location += lengthToCopy;
        hash = hash_bytes(buff, lengthToCopy, hash);
    }
    return hash;
}

static RollingHash_t find_power(RollingHash_t base, unsigned long long exponent) {
    if (exponent == 0) return 1;
    else if ((exponent & 1) == 0) return find_power(base * base, exponent >> 1); // x^(2n) = (x^2)^n
    else return base * find_power(base, exponent ^ 1); // x^(2n + 1) = x * x^(2n)
}

static BOOL matchOccursAtIndex(HFByteArray *needle, HFByteArray *haystack, HFRange haystackRange) {
    HFASSERT(needle != NULL);
    HFASSERT(haystack != NULL);
    HFASSERT(haystackRange.length == [needle length]);
    HFRange needleRange = HFRangeMake(0, haystackRange.length);
    BOOL result = YES;
    while (needleRange.length > 0) {
        unsigned char needleBuff[SEARCH_CHUNK_SIZE], haystackBuff[SEARCH_CHUNK_SIZE];
        NSUInteger amountToCopy = ll2l(MIN(needleRange.length, sizeof needleBuff));
        [needle copyBytes:needleBuff range:HFRangeMake(needleRange.location, amountToCopy)];
        [haystack copyBytes:haystackBuff range:HFRangeMake(haystackRange.location, amountToCopy)];
        if (memcmp(needleBuff, haystackBuff, amountToCopy)) {
            result = NO;
            break;
        }
        needleRange.location += amountToCopy;
        haystackRange.location += amountToCopy;
        needleRange.length -= amountToCopy;
        haystackRange.length -= amountToCopy;
    }
    return result;
}

- (unsigned long long)_byteSearchRollingHash:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker {
    const unsigned long long needleLength = [findBytes length];
    unsigned long long tempProgressValue = 0;
    int tempCancelRequested = 0;
    volatile unsigned long long * const progressValuePtr = (progressTracker ? &progressTracker->currentProgress : &tempProgressValue);
    volatile int *cancelRequested = progressTracker ? &progressTracker->cancelRequested : &tempCancelRequested;
    HFASSERT(range.length >= needleLength);    
    const RollingHash_t needleHash = hash_byte_array(findBytes, HFRangeMake(0, needleLength), forwards, HFRangeMake(0, needleLength), cancelRequested);
    if (*cancelRequested) goto cancelled;
    
    const RollingHash_t hashPower = find_power(ROLLING_HASH_BASE, needleLength);
    unsigned char trailingChunk[SEARCH_CHUNK_SIZE], leadingChunk[SEARCH_CHUNK_SIZE];
    unsigned long long result = ULLONG_MAX;
    
    /* Prime the hash */
    RollingHash_t rollingHash = hash_byte_array(self, HFRangeMake(range.location, needleLength), forwards, range, cancelRequested);
    if (*cancelRequested) goto cancelled;
    
    HFRange remainingRange = HFRangeMake(HFSum(range.location, needleLength), range.length - needleLength);
    /* Start the hashing */
    while (remainingRange.length > 0 && result == ULLONG_MAX) {
        NSUInteger bufferIndex, amountToCopy = ll2l(MIN(sizeof leadingChunk, remainingRange.length));
        [self _copyBytes:leadingChunk range:HFRangeMake(remainingRange.location, amountToCopy) forwards:forwards inEnclosingRange:range];
        if (*cancelRequested) goto cancelled;
        
        [self _copyBytes:trailingChunk range:HFRangeMake(remainingRange.location - needleLength, amountToCopy) forwards:forwards inEnclosingRange:range];
        if (*cancelRequested) goto cancelled;
        
        for (bufferIndex = 0; bufferIndex < amountToCopy; ) {
            if (rollingHash == needleHash) {
                unsigned long long proposedResult = HFSum(remainingRange.location, bufferIndex) - needleLength;
                if (! forwards) {
                    proposedResult = HFMaxRange(range) - proposedResult - needleLength;
                }
                if (matchOccursAtIndex(findBytes, self, HFRangeMake(proposedResult, needleLength))) {
                    result = proposedResult;
                    break;
                }
            }
            /* Compute the next hash */
            unsigned char trailingChar = trailingChunk[bufferIndex];
            rollingHash = rollingHash * ROLLING_HASH_BASE + leadingChunk[bufferIndex++] - hashPower * (RollingHash_t)trailingChar;
#if ! NDEBUG
            //if (random() % 200 == 0) HFASSERT(rollingHash == hash_byte_array(self, HFRangeMake(remainingRange.location + bufferIndex - needleLength, needleLength), forwards, range, &tempCancelRequested));
#endif
        }
        HFAtomicAdd64(amountToCopy, (int64_t *)progressValuePtr);
        remainingRange.location += amountToCopy;
        remainingRange.length -= amountToCopy;
        if (*cancelRequested) goto cancelled;
    }
    return result;
    
cancelled:
    return ULLONG_MAX;
}

- (unsigned long long)_byteSearchNaive:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker {
    USE(progressTracker);
    unsigned long long i;
    const unsigned long long needleLength = [findBytes length];
    const unsigned long long end = range.length - needleLength + 1;
    if (forwards) {
        for (i=0; i < end; i++) {
            if (matchOccursAtIndex(findBytes, self, HFRangeMake(range.location + i, needleLength))) return i + range.location;
        }
    }
    else {
        i = end;
        while (i--) {
            if (matchOccursAtIndex(findBytes, self, HFRangeMake(range.location + i, needleLength))) return i + range.location;
        }
    }
    return ULLONG_MAX;
}

#if HFUNIT_TESTS

#define HFTEST(a) do { if (! (a)) { printf("Test failed on line %u of file %s: %s\n", __LINE__, __FILE__, #a); exit(0); } } while (0)

+ (void)_testSearchAlgorithmsLookingForArray:(HFByteArray *)needle inArray:(HFByteArray *)haystack {
    HFRange fullRange = HFRangeMake(0, [haystack length]);
    HFRange partialRange = HFRangeMake(fullRange.location + 10, fullRange.length - 10);
    unsigned long long result1, result2;
    
    result1 = [haystack _byteSearchBoyerMoore:needle inRange:fullRange forwards:YES trackingProgress:nil];
    result2 = [haystack _byteSearchRollingHash:needle inRange:fullRange forwards:YES trackingProgress:nil];
    HFTEST(result1 == result2);
    
    result1 = [haystack _byteSearchBoyerMoore:needle inRange:fullRange forwards:NO trackingProgress:nil];
    result2 = [haystack _byteSearchRollingHash:needle inRange:fullRange forwards:NO trackingProgress:nil];
    HFTEST(result1 == result2);    
    
    result1 = [haystack _byteSearchBoyerMoore:needle inRange:partialRange forwards:YES trackingProgress:nil];
    result2 = [haystack _byteSearchRollingHash:needle inRange:partialRange forwards:YES trackingProgress:nil];
    HFTEST(result1 == result2);
    
    result1 = [haystack _byteSearchBoyerMoore:needle inRange:partialRange forwards:NO trackingProgress:nil];
    result2 = [haystack _byteSearchRollingHash:needle inRange:partialRange forwards:NO trackingProgress:nil];
    HFTEST(result1 == result2);    
    
}

#endif

@end

