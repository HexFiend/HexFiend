#import <HexFiend/HFFastMemchr.h>

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

#else

#include <string.h>

#endif

unsigned char *HFFastMemchr(const unsigned char *haystack, unsigned char needle, size_t length) {
    if (length == 0) return NULL;
#if defined(__i386__) || defined(__x86_64__)
    return sse_memchr(haystack, needle, length);
#else
    // TODO: Can we use Accelerate framework?
    return memchr(haystack, needle, length);
#endif
}
