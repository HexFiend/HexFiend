#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

@class HFController;

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

__private_extern__ unsigned char *_Nullable HFFastMemchr(const unsigned char *s, unsigned char c, size_t n);

__private_extern__ NSString *HFDescribeByteCountWithPrefixAndSuffix(const char *_Nullable stringPrefix, unsigned long long count, const char *_Nullable stringSuffix);

/* Function for OSAtomicAdd64 that just does a non-atomic add on PowerPC.  This should not be used where atomicity is critical; an example where this is used is updating a progress bar. */
static inline int64_t HFAtomicAdd64(int64_t a, volatile int64_t *b) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return OSAtomicAdd64(a, b);
#pragma clang diagnostic pop
}

__private_extern__ NSUInteger HFLineHeightForFont(HFFont *font);

NS_ASSUME_NONNULL_END
