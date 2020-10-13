#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

__private_extern__ unsigned char *_Nullable HFFastMemchr(const unsigned char *s, unsigned char c, size_t n);

/* Function for OSAtomicAdd64 that just does a non-atomic add on PowerPC.  This should not be used where atomicity is critical; an example where this is used is updating a progress bar. */
static inline int64_t HFAtomicAdd64(int64_t a, volatile int64_t *b) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return OSAtomicAdd64(a, b);
#pragma clang diagnostic pop
}

__private_extern__ NSUInteger HFLineHeightForFont(HFFont *font);

NS_ASSUME_NONNULL_END
