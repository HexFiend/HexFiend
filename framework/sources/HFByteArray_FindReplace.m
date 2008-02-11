//
//  HFByteArray_FindReplace.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/8/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArray_Internal.h>

unsigned char* boyer_moore_helper(const unsigned char * restrict haystack, const unsigned char * restrict needle, unsigned long haystack_length, unsigned long needle_length, const unsigned long * restrict char_jump, const unsigned long * restrict match_jump) {
    unsigned ua, ub;
    
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
		    
		    unsigned result;
		    
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
	    
	    unsigned result;
	    
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

- (unsigned long long)_byteSearchForwardsBoyerMoore:(HFByteArray *)findBytes inRange:(const HFRange)range withBytesConsumedProgress:(unsigned long long *)bytesConsumed {
    REQUIRE_NOT_NULL(bytesConsumed);
    *bytesConsumed = 0;
    unsigned long needle_length = ll2l([findBytes length]);
    unsigned char *needle = malloc(needle_length);
    if (! needle) {
	NSLog(@"Out of memory allocating %lu bytes", needle_length);
	return ULLONG_MAX;
    }
    [findBytes copyBytes:needle range:HFRangeMake(0, needle_length)];

    const unsigned long long total_haystack_length = range.length;
    unsigned long haystack_bytes_to_allocate;
    
    BOOL search_with_chunks = total_haystack_length > SEARCH_CHUNK_SIZE + needle_length;
    unsigned needle_length_rounded_up_to_page_size = 0;
    
    /* does the haystack fit entirely in memory? */
    if (! search_with_chunks) haystack_bytes_to_allocate = ll2l(total_haystack_length);
    else {
	/* we are searching by chunks, so we will need to prepend up to needle_length bytes to handle the case where a result overlaps two chunks.  To get our base buffer page-aligned, we round needle_length up to a page size */
	unsigned long needle_length_page_overflow = needle_length % PAGE_SIZE;
	needle_length_rounded_up_to_page_size = needle_length + (needle_length_page_overflow ? (PAGE_SIZE - needle_length_page_overflow) : 0);
	
	haystack_bytes_to_allocate = SEARCH_CHUNK_SIZE + needle_length_rounded_up_to_page_size;
    }
    
    unsigned char *haystack = malloc(haystack_bytes_to_allocate);
    if (! haystack) {
	free(needle);
	NSLog(@"Out of memory allocating %lu bytes", haystack_bytes_to_allocate);
	return ULLONG_MAX;
    }

    /* generate the two Boyer-Moore auxiliary buffers */
    unsigned long char_jump[UCHAR_MAX + 1] = {0};
    unsigned long *match_jump;
    match_jump = malloc(2 * (needle_length + 1) * sizeof *match_jump);
    if (! match_jump) {
	NSLog(@"Out of memory allocating %u bytes", (2 * (needle_length + 1) * sizeof *match_jump));
	free(haystack);
	free(needle);
        return ULLONG_MAX;
    }
    
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
    
    
    unsigned long long result;
    
    /* start the search */
    if (! search_with_chunks) {
	unsigned long haystack_length = ll2l(total_haystack_length);
	[self copyBytes:haystack range:range];
	unsigned char *search_result = boyer_moore_helper(haystack, needle, haystack_length, needle_length, char_jump, match_jump);
	if (search_result == NULL) result = ULLONG_MAX;
	else result = range.location + (search_result - haystack);
    }
    else {
	unsigned char * const base_read_in_location = haystack + needle_length_rounded_up_to_page_size;
	unsigned char * const base_copy_location = base_read_in_location - needle_length;
	unsigned char * const base_copy_src = base_read_in_location + SEARCH_CHUNK_SIZE - needle_length;
	HFRange remaining_range = range;
	
	/* start us off */
	HFRange search_range = remaining_range;
	if (search_range.length > SEARCH_CHUNK_SIZE) search_range.length = SEARCH_CHUNK_SIZE;
	[self copyBytes:base_read_in_location range:search_range];
	unsigned char *search_result = boyer_moore_helper(base_read_in_location, needle, SEARCH_CHUNK_SIZE, needle_length, char_jump, match_jump);
	if (search_result) result = search_range.location + (search_result - base_read_in_location);
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
		
		if (copy_range.length) [self copyBytes:base_read_in_location range:copy_range];
		
		search_result = boyer_moore_helper(base_copy_location, needle, ll2l(search_range.length), needle_length, char_jump, match_jump);
		if (search_result) {
		    result = search_range.location + (search_result - base_copy_location);
		    break;
		}
		else {
		    remaining_range.location += search_range.length - needle_length;
		    remaining_range.length -= search_range.length - needle_length;
		}
	    }
	}
    }
    
    free(needle);
    free(haystack);
    free(match_jump);
    return result;
}

- (unsigned long long)_byteSearchForwardsSingle:(unsigned char)byte inRange:(const HFRange)range withBytesConsumedProgress:(unsigned long long *)bytesConsumed {
    return ULLONG_MAX;
}

@end
