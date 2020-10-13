/* Functions and convenience methods for working with HFTypes */

#import <HexFiend/HFFrameworkPrefix.h>
#import <HexFiend/HFTypes.h>
#import <libkern/OSAtomic.h>

NS_ASSUME_NONNULL_BEGIN

#define HFDEFAULT_FONT (@"Monaco")
#define HFDEFAULT_FONTSIZE ((CGFloat)10.)

#define HFZeroRange (HFRange){0, 0}

/*!
  Makes an HFRange.  An HFRange is like an NSRange except it uses unsigned long longs.
*/
static inline HFRange HFRangeMake(unsigned long long loc, unsigned long long len) {
    return (HFRange){loc, len};
}

/*!
  Returns true if a given location is within a given HFRange.  If the location is at the end of the range (range.location + range.length) this returns NO.
*/
static inline BOOL HFLocationInRange(unsigned long long location, HFRange range) {
    return location >= range.location && location - range.location < range.length;
}

static inline HFFPRange HFFPRangeMake(long double loc, long double len) {
    return (HFFPRange){loc, len};
}

/*!
  Like NSRangeToString but for HFRanges
*/
static inline NSString* HFRangeToString(HFRange range) {
    return [NSString stringWithFormat:@"{%llu, %llu}", range.location, range.length];
}

/*!
  Converts a given HFFPRange to a string.
*/
static inline NSString* HFFPRangeToString(HFFPRange range) {
    return [NSString stringWithFormat:@"{%Lf, %Lf}", range.location, range.length];
}

/*!
  Returns true if two HFRanges are equal.
*/
static inline BOOL HFRangeEqualsRange(HFRange a, HFRange b) {
    return a.location == b.location && a.length == b.length;
}

/*!
  Returns true if a + b does not overflow an unsigned long long.
*/
static inline BOOL HFSumDoesNotOverflow(unsigned long long a, unsigned long long b) {
    return a + b >= a;
}

/*!
  Returns true if a * b does not overflow an unsigned long long.
*/
static inline BOOL HFProductDoesNotOverflow(unsigned long long a, unsigned long long b) {
    if (b == 0) return YES;
    unsigned long long result = a * b;
    return result / b == a;
}

/*!
  Returns a * b as an NSUInteger.  This asserts on overflow, unless NDEBUG is defined.
*/
static inline NSUInteger HFProductInt(NSUInteger a, NSUInteger b) {
    NSUInteger result = a * b;
    assert(a == 0 || result / a == b); //detect overflow
    return result;
}

/*!
  Returns a + b as an NSUInteger.  This asserts on overflow unless NDEBUG is defined.
*/
static inline NSUInteger HFSumInt(NSUInteger a, NSUInteger b) {
	assert(a + b >= a);
	return a + b;
}

/*!
 Returns a + b as an NSUInteger, saturating at NSUIntegerMax
 */
static inline NSUInteger HFSumIntSaturate(NSUInteger a, NSUInteger b) {
    NSUInteger result = a + b;
    return (result < a) ? NSUIntegerMax : result;
}

/*!
 Returns a + b as an unsigned long long, saturating at ULLONG_MAX
 */
static inline unsigned long long HFSumULLSaturate(unsigned long long a, unsigned long long b) {
    unsigned long long result = a + b;
    return (result < a) ? ULLONG_MAX : result;
}

/*!
  Returns a * b as an unsigned long long.  This asserts on overflow, unless NDEBUG is defined.
*/
static inline unsigned long long HFProductULL(unsigned long long a, unsigned long long b) {
    unsigned long long result = a * b;
    assert(HFProductDoesNotOverflow(a, b)); //detect overflow
    return result;
}

/*!
  Returns a + b as an unsigned long long.  This asserts on overflow, unless NDEBUG is defined.
*/
static inline unsigned long long HFSum(unsigned long long a, unsigned long long b) {
    assert(HFSumDoesNotOverflow(a, b));
    return a + b;
}

/*!
 Returns a + b as an unsigned long long.  This asserts on overflow, unless NDEBUG is defined.
 */
static inline unsigned long long HFMaxULL(unsigned long long a, unsigned long long b) {
    return a < b ? b : a;
}

/*!
  Returns a - b as an unsigned long long.  This asserts on underflow (if b > a), unless NDEBUG is defined.
*/
static inline unsigned long long HFSubtract(unsigned long long a, unsigned long long b) {
    assert(a >= b);
    return a - b;
}

/*!
  Returns the smallest multiple of B that is equal to or larger than A, and asserts on overflow.
*/
static inline unsigned long long HFRoundUpToMultiple(unsigned long long a, unsigned long long b) {
    // The usual approach of ((a + (b - 1)) / b) * b doesn't handle overflow correctly
    unsigned long long remainder = a % b;
    if (remainder == 0) return a;
    else return HFSum(a, b - remainder);
}

/*!
 Returns the smallest multiple of B that is equal to or larger than A, and asserts on overflow.
 */
static inline NSUInteger HFRoundUpToMultipleInt(NSUInteger a, NSUInteger b) {
    // The usual approach of ((a + (b - 1)) / b) * b doesn't handle overflow correctly
    NSUInteger remainder = a % b;
    if (remainder == 0) return a;
    else return (NSUInteger)HFSum(a, b - remainder);
}

/*!
 Returns the least common multiple of A and B, and asserts on overflow or if A or B is zero.
 */
static inline NSUInteger HFLeastCommonMultiple(NSUInteger a, NSUInteger b) {
    assert(a > 0);
    assert(b > 0);
    
    /* Compute GCD.  It ends up in U. */
    NSUInteger t, u = a, v = b;
    while (v > 0) {
        t = v;
        v = u % v;
        u = t;
    }
    
    /* Return the product divided by the GCD, in an overflow safe manner */
    return HFProductInt(a/u, b);
}


/*!
 Returns the smallest multiple of B strictly larger than A, or ULLONG_MAX if it would overflow
*/
static inline unsigned long long HFRoundUpToNextMultipleSaturate(unsigned long long a, unsigned long long b) {
    assert(b > 0);
    unsigned long long result = a + (b - a % b);
    if (result < a) result = ULLONG_MAX; //the saturation...on overflow go to the max
    return result;
}

/*! Like NSMaxRange, but for an HFRange. */
static inline unsigned long long HFMaxRange(HFRange a) {
    assert(HFSumDoesNotOverflow(a.location, a.length));
    return a.location + a.length;
}

/*! Returns YES if needle is fully contained within haystack.  Equal ranges are always considered to be subranges of each other (even if they are empty).  Furthermore, a zero length needle at the end of haystack is considered a subrange - for example, {6, 0} is a subrange of {3, 3}. */
static inline BOOL HFRangeIsSubrangeOfRange(HFRange needle, HFRange haystack) {
    // If needle starts before haystack, or if needle is longer than haystack, it is not a subrange of haystack
    if (needle.location < haystack.location || needle.length > haystack.length) return NO;
    
    // Their difference in lengths determines the maximum difference in their start locations.  We know that these expressions cannot overflow because of the above checks.
    return haystack.length - needle.length >= needle.location - haystack.location;
}

/*! Splits a range about a subrange, returning by reference the prefix and suffix (which may have length zero). */
static inline void HFRangeSplitAboutSubrange(HFRange range, HFRange subrange, HFRange *outPrefix, HFRange *outSuffix) {
    // Requires it to be a subrange
    assert(HFRangeIsSubrangeOfRange(subrange, range));
    outPrefix->location = range.location;
    outPrefix->length = HFSubtract(subrange.location, range.location);
    outSuffix->location = HFMaxRange(subrange);
    outSuffix->length = HFMaxRange(range) - outSuffix->location;
}

/*! Returns YES if the given ranges intersect. Two ranges are considered to intersect if they share at least one index in common.  Thus, zero-length ranges do not intersect anything. */
static inline BOOL HFIntersectsRange(HFRange a, HFRange b) {
    // Ranges are said to intersect if they share at least one value.  Therefore, zero length ranges never intersect anything.
    if (a.length == 0 || b.length == 0) return NO;
    
    // rearrange (a.location < b.location + b.length && b.location < a.location + a.length) to not overflow
    // = ! (a.location >= b.location + b.length || b.location >= a.location + a.length)
    BOOL clause1 = (a.location >= b.location && a.location - b.location >= b.length);
    BOOL clause2 = (b.location >= a.location && b.location - a.location >= a.length);
    return ! (clause1 || clause2);
}

/*! Returns YES if the given ranges intersect. Two ranges are considered to intersect if any fraction overlaps; zero-length ranges do not intersect anything. */
static inline BOOL HFFPIntersectsRange(HFFPRange a, HFFPRange b) {
    // Ranges are said to intersect if they share at least one value.  Therefore, zero length ranges never intersect anything.
    if (a.length == 0 || b.length == 0) return NO;
    
    if (a.location <= b.location && a.location + a.length >= b.location) return YES;
    if (b.location <= a.location && b.location + b.length >= a.location) return YES;
    return NO;
}

/*! Returns a range containing the union of the given ranges.  These ranges must either intersect or be adjacent: there cannot be any "holes" between them. */
static inline HFRange HFUnionRange(HFRange a, HFRange b) {
    assert(HFIntersectsRange(a, b) || HFMaxRange(a) == b.location || HFMaxRange(b) == a.location);
    HFRange result;
    result.location = MIN(a.location, b.location);
    assert(HFSumDoesNotOverflow(a.location, a.length));
    assert(HFSumDoesNotOverflow(b.location, b.length));
    result.length = MAX(a.location + a.length, b.location + b.length) - result.location;
    return result;
}


/*! Returns whether a+b > c+d, as if there were no overflow (so ULLONG_MAX + 1 > 10 + 20) */
static inline BOOL HFSumIsLargerThanSum(unsigned long long a, unsigned long long b, unsigned long long c, unsigned long long d) {
#if 1
    // Theory: compare a/2 + b/2 to c/2 + d/2, and if they're equal, compare a%2 + b%2 to c%2 + d%2.  We may get into trouble if a and b are both even and c and d are both odd: e.g. a = 2, b = 2, c = 1, d = 3.  We would compare 1 + 1 vs 0 + 1, and therefore that 2 + 2 > 1 + 3.  To address this, if both remainders are 1, we add this to the sum.  We know this cannot overflow because ULLONG_MAX is odd, so (ULLONG_MAX/2) + (ULLONG_MAX/2) + 1 does not overflow.
    unsigned int rem1 = (unsigned)(a%2 + b%2);
    unsigned int rem2 = (unsigned)(c%2 + d%2);
    unsigned long long sum1 = a/2 + b/2 + rem1/2;
    unsigned long long sum2 = c/2 + d/2 + rem2/2;
    if (sum1 > sum2) return YES;
    else if (sum1 < sum2) return NO;
    else {
        // sum1 == sum2, so compare the remainders.  But we have already added in the remainder / 2, so compare the remainders mod 2.
        if (rem1%2 > rem2%2) return YES;
        else return NO;
    }
#else
    /* Faster version, but not thoroughly tested yet. */
    unsigned long long xor1 = a^b;
    unsigned long long xor2 = c^d;
    unsigned long long avg1 = (a&b)+(xor1/2);
    unsigned long long avg2 = (c&d)+(xor2/2);
    unsigned s1l = avg1 > avg2;
    unsigned eq = (avg1 == avg2);
    return s1l | ((xor1 & ~xor2) & eq);
#endif
}

/*! Returns the absolute value of a - b. */
static inline unsigned long long HFAbsoluteDifference(unsigned long long a, unsigned long long b) {
    if (a > b) return a - b;
    else return b - a;
}

/*! Returns true if the end of A is larger than the end of B. */
static inline BOOL HFRangeExtendsPastRange(HFRange a, HFRange b) {
    return HFSumIsLargerThanSum(a.location, a.length, b.location, b.length);
}

/*! Returns a range containing all indexes in common betwen the two ranges.  If there are no indexes in common, returns {0, 0}. */
static inline HFRange HFIntersectionRange(HFRange range1, HFRange range2) {
    unsigned long long minend = HFRangeExtendsPastRange(range2, range1) ? range1.location + range1.length : range2.location + range2.length;
    if (range2.location <= range1.location && range1.location - range2.location < range2.length) {
	return HFRangeMake(range1.location, minend - range1.location);
    }
    else if (range1.location <= range2.location && range2.location - range1.location < range1.length) {
	return HFRangeMake(range2.location, minend - range2.location);
    }
    return HFRangeMake(0, 0);
}

/*! ceil() for a CGFloat, for compatibility with OSes that do not have the CG versions.  */
static inline CGFloat HFCeil(CGFloat a) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)ceilf((float)a);
    else return (CGFloat)ceil((double)a);
}

/*! floor() for a CGFloat, for compatibility with OSes that do not have the CG versions.  */
static inline CGFloat HFFloor(CGFloat a) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)floorf((float)a);
    else return (CGFloat)floor((double)a);
}

/*! round() for a CGFloat, for compatibility with OSes that do not have the CG versions.  */
static inline CGFloat HFRound(CGFloat a) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)roundf((float)a);
    else return (CGFloat)round((double)a);
}

/*! fmin() for a CGFloat, for compatibility with OSes that do not have the CG versions.  */
static inline CGFloat HFMin(CGFloat a, CGFloat b) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)fminf((float)a, (float)b);
    else return (CGFloat)fmin((double)a, (double)b);    
}

/*! fmax() for a CGFloat, for compatibility with OSes that do not have the CG versions.  */
static inline CGFloat HFMax(CGFloat a, CGFloat b) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)fmaxf((float)a, (float)b);
    else return (CGFloat)fmax((double)a, (double)b);    
}

/*! Returns true if the given HFFPRanges are equal.  */
static inline BOOL HFFPRangeEqualsRange(HFFPRange a, HFFPRange b) {
    return a.location == b.location && a.length == b.length;
}

/*! copysign() for a CGFloat */
static inline CGFloat HFCopysign(CGFloat a, CGFloat b) {
#if CGFLOAT_IS_DOUBLE
    return copysign(a, b);
#else
    return copysignf(a, b);
#endif
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
/*! Atomically increments an NSUInteger, returning the new value.  Optionally invokes a memory barrier. */
static inline NSUInteger HFAtomicIncrement(volatile NSUInteger *ptr, BOOL barrier) {
    return _Generic(ptr,
        volatile unsigned *:           (barrier ? OSAtomicIncrement32Barrier : OSAtomicIncrement32)((volatile int32_t *)ptr),
#if ULONG_MAX == UINT32_MAX
        volatile unsigned long *:      (barrier ? OSAtomicIncrement32Barrier : OSAtomicIncrement32)((volatile int32_t *)ptr),
#else
        volatile unsigned long *:      (barrier ? OSAtomicIncrement64Barrier : OSAtomicIncrement64)((volatile int64_t *)ptr),
#endif
        volatile unsigned long long *: (barrier ? OSAtomicIncrement64Barrier : OSAtomicIncrement64)((volatile int64_t *)ptr));
}

/*! Atomically decrements an NSUInteger, returning the new value.  Optionally invokes a memory barrier. */
static inline NSUInteger HFAtomicDecrement(volatile NSUInteger *ptr, BOOL barrier) {
    return _Generic(ptr,
        volatile unsigned *:           (barrier ? OSAtomicDecrement32Barrier : OSAtomicDecrement32)((volatile int32_t *)ptr),
#if ULONG_MAX == UINT32_MAX
        volatile unsigned long *:      (barrier ? OSAtomicDecrement32Barrier : OSAtomicDecrement32)((volatile int32_t *)ptr),
#else
        volatile unsigned long *:      (barrier ? OSAtomicDecrement64Barrier : OSAtomicDecrement64)((volatile int64_t *)ptr),
#endif
        volatile unsigned long long *: (barrier ? OSAtomicDecrement64Barrier : OSAtomicDecrement64)((volatile int64_t *)ptr));
}

/* Function for OSAtomicAdd64 that just does a non-atomic add on PowerPC.  This should not be used where atomicity is critical; an example where this is used is updating a progress bar. */
static inline int64_t HFAtomicAdd64(int64_t a, volatile int64_t *b) {
    return OSAtomicAdd64(a, b);
}
#pragma clang diagnostic pop

/*! Converts a long double to unsigned long long.  Assumes that val is already an integer - use floorl or ceill */
static inline unsigned long long HFFPToUL(long double val) {
    assert(val >= 0);
    assert(val <= ULLONG_MAX);
    unsigned long long result = (unsigned long long)val;
    assert((long double)result == val);
    return result;
}

/*! Converts an unsigned long long to a long double. */
static inline long double HFULToFP(unsigned long long val) {
    long double result = (long double)val;
    assert(HFFPToUL(result) == val);
    return result;
}

/*! Convenience to return information about a CGAffineTransform for logging. */
static inline NSString *HFDescribeAffineTransform(CGAffineTransform t) {
    return [NSString stringWithFormat:@"%f %f 0\n%f %f 0\n%f %f 1", t.a, t.b, t.c, t.d, t.tx, t.ty];
}

/*! Returns 1 + floor(log base 10 of val).  If val is 0, returns 1. */
static inline NSUInteger HFCountDigitsBase10(unsigned long long val) {
    const unsigned long long kValues[] = {0ULL, 9ULL, 99ULL, 999ULL, 9999ULL, 99999ULL, 999999ULL, 9999999ULL, 99999999ULL, 999999999ULL, 9999999999ULL, 99999999999ULL, 999999999999ULL, 9999999999999ULL, 99999999999999ULL, 999999999999999ULL, 9999999999999999ULL, 99999999999999999ULL, 999999999999999999ULL, 9999999999999999999ULL};
    NSUInteger low = 0, high = sizeof kValues / sizeof *kValues;
    while (high > low) {
        NSUInteger mid = (low + high)/2; //low + high cannot overflow
        if (val > kValues[mid]) {
            low = mid + 1;
        }
        else {
            high = mid;
        }
    }
    return MAX(1u, low);
}

/*! Returns 1 + floor(log base 16 of val).  If val is 0, returns 1.  This works by computing the log base 2 based on the number of leading zeros, and then dividing by 4. */
static inline NSUInteger HFCountDigitsBase16(unsigned long long val) {
    /* __builtin_clzll doesn't like being passed 0 */
    if (val == 0) return 1;
    
    /* Compute the log base 2 */
    NSUInteger leadingZeros = (NSUInteger)__builtin_clzll(val);
    NSUInteger logBase2 = (CHAR_BIT * sizeof val) - leadingZeros - 1;
    return 1 + logBase2/4;
}

/*! Returns the "granularity" of an encoding, in bytes.  ASCII is 1, UTF-16 is 2, etc.  Variable width encodings return the smallest (e.g. Shift-JIS returns 1). */
uint8_t HFStringEncodingCharacterLength(NSStringEncoding encoding);

/*! Converts an unsigned long long to NSUInteger.  The unsigned long long should be no more than ULONG_MAX. */
static inline NSUInteger ll2l(unsigned long long val) { assert(val <= ULONG_MAX); return (unsigned long)val; }

/*! Converts an unsigned long long to uintptr_t.  The unsigned long long should be no more than UINTPTR_MAX. */
static inline uintptr_t ll2p(unsigned long long val) { assert(val <= UINTPTR_MAX); return (uintptr_t)val; }

static inline unsigned long long llmin(unsigned long long a, unsigned long long b) {
    return a < b ? a : b;
}

/*! Returns an unsigned long long, which must be no more than ULLONG_MAX, as an unsigned long. */
static inline CGFloat ld2f(long double val) {
#if ! NDEBUG
     if (isfinite(val)) {
        assert(val <= CGFLOAT_MAX);
        assert(val >= -CGFLOAT_MAX);
        if ((val > 0 && val < CGFLOAT_MIN) || (val < 0 && val > -CGFLOAT_MIN)) {
            NSLog(@"Warning - conversion of long double %Lf to CGFloat will result in the non-normal CGFloat %f", val, (CGFloat)val);
        }
     }
#endif
    return (CGFloat)val;
}

/*! Returns the quotient of a divided by b, rounding up, for unsigned long longs.  Will not overflow. */
static inline unsigned long long HFDivideULLRoundingUp(unsigned long long a, unsigned long long b) {
    if (a == 0) return 0;
    else return ((a - 1) / b) + 1;
}

/*! Returns the quotient of a divided by b, rounding up, for NSUIntegers.  Will not overflow. */
static inline NSUInteger HFDivideULRoundingUp(NSUInteger a, NSUInteger b) {
    if (a == 0) return 0;
    else return ((a - 1) / b) + 1;
}

#if !TARGET_OS_IPHONE
/*! Draws a shadow. */
void HFDrawShadow(CGContextRef context, NSRect rect, CGFloat size, NSRectEdge rectEdge, BOOL active, NSRect clip);

/*! Registers a view to have the given notificationSEL invoked (taking the NSNotification object) when the window becomes or loses key.  If appToo is YES, this also registers with NSApplication for Activate and Deactivate methods. */
void HFRegisterViewForWindowAppearanceChanges(NSView *view, SEL notificationSEL, BOOL appToo);

/*! Unregisters a view to have the given notificationSEL invoked when the window becomes or loses key.  If appToo is YES, this also unregisters with NSApplication. */
void HFUnregisterViewForWindowAppearanceChanges(NSView *view, BOOL appToo);
#endif

/*! Returns a description of the given byte count (e.g. "24 kilobytes") */
NSString *HFDescribeByteCount(unsigned long long count);
NSString *HFDescribeByteCountWithPrefixAndSuffix(const char *_Nullable stringPrefix, unsigned long long count, const char *_Nullable stringSuffix);

/*! @brief An object wrapper for the HFRange type.

  A simple class responsible for holding an immutable HFRange as an object.  Methods that logically work on multiple HFRanges usually take or return arrays of HFRangeWrappers. */
@interface HFRangeWrapper : NSObject <NSCopying> {
    @public
    HFRange range;
}

/*! Returns the HFRange for this HFRangeWrapper. */
- (HFRange)HFRange;

/*! Creates an autoreleased HFRangeWrapper for this HFRange. */
+ (HFRangeWrapper *)withRange:(HFRange)range;

/*! Creates an NSArray of HFRangeWrappers for this HFRange. */
+ (NSArray *)withRanges:(const HFRange *)ranges count:(NSUInteger)count;

/*! Given an NSArray of HFRangeWrappers, get all of the HFRanges into a C array. */
+ (void)getRanges:(HFRange *)ranges fromArray:(NSArray *)array;

/*! Given an array of HFRangeWrappers, returns a "cleaned up" array of equivalent ranges.  This new array represents the same indexes, but overlapping ranges will have been merged, and the ranges will be sorted in ascending order. */
+ (NSArray *)organizeAndMergeRanges:(NSArray *)inputRanges;

@end

/*! @brief A set of HFRanges. HFRangeSet takes the interpetation that all zero-length ranges are identical.
 
 Essentially, a mutable array of ranges that is maintained to be sorted and minimized (i.e. merged with overlapping neighbors).
 
 TODO: The HexFiend codebase currently uses arrays of HFRangeWrappers that have been run through organizeAndMergeRanges:, and not HFRangeSet. The advantage of HFRangeSet is that the sorting & merging is implied by the type, instead of just tacitly assumed. This should lead to less confusion and fewer extra applications of organizeAndMergeRanges.
 
 TODO: HFRangeSet needs to be tested! I guarantee it has bugs! (Which doesn't matter right now because it's all dead code...)
 */
@interface HFRangeSet : NSObject <NSCopying, NSSecureCoding> {
    @private
    CFMutableArrayRef array;
}

/*! Create a range set with just one range. */
+ (HFRangeSet *)withRange:(HFRange)range;

/*! Create a range set with a C array of ranges. No prior sorting is necessary. */
+ (HFRangeSet *)withRanges:(const HFRange *)ranges count:(NSUInteger)count;

/*! Create a range set with an array of HFRangeWrappers. No prior sorting is necessary. */
+ (HFRangeSet *)withRangeWrappers:(NSArray *)ranges;

/*! Create a range set as a copy of another. */
+ (HFRangeSet *)withRangeSet:(HFRangeSet *)rangeSet;

/*! Equivalent to HFRangeSet *x = [HFRangeSet withRange:range]; [x removeRange:rangeSet]; */
+ (HFRangeSet *)complementOfRangeSet:(HFRangeSet *)rangeSet inRange:(HFRange)range;

- (void)addRange:(HFRange)range;    /*!< Union with range */
- (void)removeRange:(HFRange)range; /*!< Subtract range */
- (void)clipToRange:(HFRange)range; /*!< Intersect with range */
- (void)toggleRange:(HFRange)range; /*!< Symmetric difference with range */

- (void)addRangeSet:(HFRangeSet *)rangeSet;    /*!< Union with range set */
- (void)removeRangeSet:(HFRangeSet *)rangeSet; /*!< Subtract range set */
- (void)clipToRangeSet:(HFRangeSet *)rangeSet; /*!< Intersect with range set */
- (void)toggleRangeSet:(HFRangeSet *)rangeSet; /*!< Symmetric difference with range set */


- (BOOL)isEqualToRangeSet:(HFRangeSet *)rangeSet; /*!< Test if two range sets are equivalent. */
- (BOOL)isEmpty;                                  /*!< Test if range set is empty. */

- (BOOL)containsAllRange:(HFRange)range;             /*!< Check if the range set covers all of a range. Always true if 'range' is zero length. */
- (BOOL)overlapsAnyRange:(HFRange)range;             /*!< Check if the range set covers any of a range. Never true if 'range' is zero length. */
- (BOOL)containsAllRangeSet:(HFRangeSet *)rangeSet;  /*!< Check if this range is a superset of another. */
- (BOOL)overlapsAnyRangeSet:(HFRangeSet *)rangeSet;  /*!< Check if this range has a nonempty intersection with another. */

- (HFRange)spanningRange;  /*!< Return a single range that covers the entire range set */

- (void)assertIntegrity;

@end

BOOL HFDarkModeEnabled(void);

CGContextRef HFGraphicsGetCurrentContext(void);

HFColor* HFColorWithWhite(CGFloat white, CGFloat alpha);
HFColor* HFColorWithRGB(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha);

/* Returns an NSData from an NSString containing hexadecimal characters.  Characters that are not hexadecimal digits are silently skipped.  Returns by reference whether the last byte contains only one nybble, in which case it will be returned in the low 4 bits of the last byte. */
NSData *HFDataFromHexString(NSString *string, BOOL *_Nullable isMissingLastNybble);

NSString *HFHexStringFromData(NSData *data, BOOL includePrefix);

NS_ASSUME_NONNULL_END
