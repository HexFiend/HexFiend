#import "HFFunctions_Private.h"

#if defined(__i386__) || defined(__x86_64__)

#include <xmmintrin.h>

static unsigned char* sse_memchr(const unsigned char* haystack, unsigned char needle, size_t length) {    
    /* SSE likes 16 byte alignment */
    
    /* Unaligned prefix */
    while (((intptr_t)haystack) % 16) {
        if (! length--) return NULL;
        if (*haystack == needle) return (unsigned char *)haystack;
        haystack++;
    }
    
    /* Compute the number of vectors we can compare, and the unaligned suffix */
    size_t numVectors = length / 16;
    size_t suffixLength = length % 16;
    
    const __m128i searchVector = _mm_set1_epi8(needle);
    while (numVectors--) {
        __m128i bytesVec = _mm_load_si128((const __m128i*)haystack);
        __m128i mask = _mm_cmpeq_epi8(bytesVec, searchVector);
        int maskedBits = _mm_movemask_epi8(mask);
        if (maskedBits) {
            /* some byte has the result - find the LSB of maskedBits */
            haystack += __builtin_ffs(maskedBits) - 1;
            return (unsigned char*)haystack;
        }
        
        haystack += 16;
    }
    
    /* Unaligned suffix */
    while (suffixLength--) {
        if (*haystack == needle) return (unsigned char*)haystack;
        haystack++;
    }
    
    return NULL;
}

#endif

static unsigned char* int_memchr(const unsigned char* haystack, unsigned char needle, size_t length) __attribute__ ((__noinline__, __unused__));
static unsigned char* int_memchr(const unsigned char* haystack, unsigned char needle, size_t length) {
    unsigned prefixLength = (unsigned)((4 - ((unsigned long)haystack) % 4) % 4);
    unsigned suffixLength = (unsigned)(((unsigned long)(haystack + length)) % 4);
    size_t numWords = (length - prefixLength - suffixLength) / 4;
    
    while (prefixLength--) {
        if (*haystack == needle) return (unsigned char*)haystack;
        haystack++;
    }
    
    while (numWords--) {
        unsigned val = *(unsigned int*)haystack;
#if __BIG_ENDIAN__
        if (((val >> 24) & 0xFF) == needle) return (unsigned char*)haystack;
        if (((val >> 16) & 0xFF) == needle) return 1 + (unsigned char*)haystack;
        if (((val >> 8) & 0xFF) == needle) return 2 + (unsigned char*)haystack;
        if ((val & 0xFF) == needle) return 3 + (unsigned char*)haystack;
#else
        if ((val & 0xFF) == needle) return (unsigned char*)haystack;
        if (((val >> 8) & 0xFF) == needle) return 1 + (unsigned char*)haystack;
        if (((val >> 16) & 0xFF) == needle) return 2 + (unsigned char*)haystack;
        if (((val >> 24) & 0xFF) == needle) return 3 + (unsigned char*)haystack;
#endif
	
        haystack += 4;
    }
    
    while (suffixLength--) {
        if (*haystack == needle) return (unsigned char*)haystack;
        haystack++;
    }
    
    return NULL;
}

unsigned char *HFFastMemchr(const unsigned char *haystack, unsigned char needle, size_t length) {
    if (length == 0) return NULL;
#if defined(__i386__) || defined(__x86_64__)
    return sse_memchr(haystack, needle, length);
#else
#error UNKNOWN ARCHITECTURE
#endif
}
