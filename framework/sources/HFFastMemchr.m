#import <HexFiend/HFFunctions_Private.h>


#if defined(__ppc__) || defined(__ppc64__)


static unsigned char* altivec_memchr(const unsigned char* haystack, unsigned char needle, size_t length) __attribute__ ((__noinline__));
static unsigned char* altivec_memchr(const unsigned char* haystack, unsigned char needle, size_t length) {
    /* Altivec needs 16 byte alignment */
    unsigned prefixLength = (unsigned)((16 - ((unsigned long)haystack) % 16) % 16);
    unsigned suffixLength = (unsigned)(((unsigned long)(haystack + length)) % 16);
    size_t altivecLength = length - prefixLength - suffixLength;
    size_t numVectors = altivecLength / 16;
    
    while (prefixLength--) {
        if (*haystack == needle) return (unsigned char*)haystack;
        haystack++;
    }
    
    unsigned int mashedByte = (needle << 24 ) | (needle << 16) | (needle << 8) | needle;
    
    const vector unsigned char searchVector = (vector unsigned int){mashedByte, mashedByte, mashedByte, mashedByte};
    
    while (numVectors--) {
        vector unsigned char bytesVec;
        bytesVec = *(const vector unsigned char*)haystack;
        if (vec_any_eq(bytesVec, searchVector)) goto foundResult;
        haystack += 16;
    }
    
    while (suffixLength--) {
        if (*haystack == needle) return (unsigned char*)haystack;
        haystack++;
    }
    
    return NULL;
    
foundResult:
        ;
    /* some byte has the result - look in groups of 4 to find which it is */
    unsigned numWords = 4;
    while (numWords--) {
        unsigned val = *(unsigned int*)haystack;
        if (((val >> 24) & 0xFF) == needle) return (unsigned char*)haystack;
        if (((val >> 16) & 0xFF) == needle) return 1 + (unsigned char*)haystack;
        if (((val >> 8) & 0xFF) == needle) return 2 + (unsigned char*)haystack;
        if ((val & 0xFF) == needle) return 3 + (unsigned char*)haystack;
        haystack += 4;
    }
    
    /* should never get here */
    return NULL;
}

#endif

#if defined(__i386__) || defined(__x86_64__)

#include <xmmintrin.h>

static unsigned char* sse_memchr(const unsigned char* haystack, unsigned char needle, size_t length) {
    /* SSE likes 16 byte alignment */
    unsigned prefixLength = (unsigned)((16 - ((unsigned long)haystack) % 16) % 16);
    unsigned suffixLength = (unsigned)(((unsigned long)(haystack + length)) % 16);
    size_t altivecLength = length - prefixLength - suffixLength;
    size_t numVectors = altivecLength / 16;
    
    while (prefixLength--) {
        if (*haystack == needle) return (unsigned char*)haystack;
        haystack++;
    }
    
    unsigned int mashedByte = (needle << 24 ) | (needle << 16) | (needle << 8) | needle;
    
    const __m128i searchVector = _mm_set_epi32(mashedByte, mashedByte, mashedByte, mashedByte);
    unsigned maskedBits = 0;
    
    while (numVectors--) {
        __m128i bytesVec = _mm_load_si128((const __m128i*)haystack);
        __m128i mask = _mm_cmpeq_epi8(bytesVec, searchVector);
        maskedBits = _mm_movemask_epi8(mask);
        if (maskedBits) goto foundResult;
        
        haystack += 16;
    }
    
    while (suffixLength--) {
        if (*haystack == needle) return (unsigned char*)haystack;
        haystack++;
    }
    
    return NULL;
    
foundResult:
        ;
    /* some byte has the result - find the LSB of maskedBits */
    haystack += __builtin_ffs(maskedBits) - 1;
    return (unsigned char*)haystack;
    
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

#if defined(__ppc__)
#include <sys/sysctl.h>
#include <sys/types.h>

static int checkForAltivec(void) {
    int sels[2] = { CTL_HW, HW_VECTORUNIT };
    int vType = 0; //0 == scalar only
    size_t length = sizeof(vType);
    int error = sysctl(sels, 2, &vType, &length, NULL, 0);
    return (error == 0 && vType != 0);
}

#endif

unsigned char *HFFastMemchr(const unsigned char *haystack, unsigned char needle, size_t length) {
    if (length == 0) return NULL;
#if defined(__ppc__)
    static char altivecIsAvailable = -1;
    if (altivecIsAvailable == -1) altivecIsAvailable = checkForAltivec();
    if (altivecIsAvailable) return altivec_memchr(haystack, needle, length);
    else return int_memchr(haystack, needle, length);
#elif defined(__ppc64__)
    return altivec_memchr(haystack, needle, length);
#elif defined(__i386__) || defined(__x86_64__)
    return sse_memchr(haystack, needle, length);
#else
#error UNKNOWN ARCHITECTURE
#endif
}
