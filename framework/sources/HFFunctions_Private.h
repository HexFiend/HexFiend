#import <Cocoa/Cocoa.h>

@class HFController;

static inline BOOL HFIsRunningOnLeopardOrLater(void) {
    return NSAppKitVersionNumber >= 949;
}

static inline BOOL HFIsRunningOnSnowLeopardOrLater(void) {
    return NSAppKitVersionNumber >= 1034;
}

/* Returns the first index where the strings differ.  If the strings do not differ in any characters but are of different lengths, returns the smaller length; if they are the same length and do not differ, returns NSUIntegerMax */
static inline NSUInteger HFIndexOfFirstByteThatDiffers(const unsigned char *a, NSUInteger len1, const unsigned char *b, NSUInteger len2) {
    NSUInteger endIndex = MIN(len1, len2);
    for (NSUInteger i = 0; i < endIndex; i++) {
        if (a[i] != b[i]) return i;
    }
    if (len1 != len2) return endIndex;
    return NSUIntegerMax;
}

/* Returns the last index where the strings differ.  If the strings do not differ in any characters but are of different lengths, returns the larger length; if they are the same length and do not differ, returns NSUIntegerMax */
static inline NSUInteger HFIndexOfLastByteThatDiffers(const unsigned char *a, NSUInteger len1, const unsigned char *b, NSUInteger len2) {
    if (len1 != len2) return MAX(len1, len2);
    NSUInteger i = len1;
    while (i--) {
        if (a[i] != b[i]) return i;
    }
    return NSUIntegerMax;
}

static inline unsigned long long llmin(unsigned long long a, unsigned long long b) {
    return a < b ? a : b;
}

__private_extern__ NSImage *HFImageNamed(NSString *name);

/* Returns an NSData from an NSString containing hexadecimal characters.  Characters that are not hexadecimal digits are silently skipped.  Returns by reference whether the last byte contains only one nybble, in which case it will be returned in the low 4 bits of the last byte. */
__private_extern__ NSData *HFDataFromHexString(NSString *string, BOOL* isMissingLastNybble);

__private_extern__ NSString *HFHexStringFromData(NSData *data);

__private_extern__ unsigned char *HFFastMemchr(const unsigned char *s, unsigned char c, size_t n);

/* Modifies F_NOCACHE for a given file descriptor */
__private_extern__ void HFSetFDShouldCache(int fd, BOOL shouldCache);

__private_extern__ NSString *HFDescribeByteCount(unsigned long long count);
__private_extern__ NSString *HFDescribeByteCountWithPrefixAndSuffix(const char *stringPrefix, unsigned long long count, const char *stringSuffix);

/* Function for OSAtomicAdd64 that just does a non-atomic add on PowerPC.  This should not be used where atomicity is critical; an example where this is used is updating a progress bar. */
static inline int64_t HFAtomicAdd64(int64_t a, volatile int64_t *b) {
#if __ppc__
    return *b += a;
#else
    return OSAtomicAdd64(a, b);
#endif
}
