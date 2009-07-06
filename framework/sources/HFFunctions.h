/* Functions and convenience methods for working with HFTypes */

#import <HexFiend/HFTypes.h>
#import <libkern/OSAtomic.h>

#define HFZeroRange (HFRange){0, 0}

/*!
  Makes an HFRange.  An HFRange is like an NSRange except it uses unsigned long longs.
*/
static inline HFRange HFRangeMake(unsigned long long loc, unsigned long long len) {
    return (HFRange){loc, len};
}

/*!
  Returns true if a given location is within a given HFRange.
*/
static inline BOOL HFLocationInRange(unsigned long long location, HFRange range) {
    return location >= range.location && location - range.location < range.length;
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
  Returns a - b as an unsigned long long.  This asserts on underflow (if b > a), unless NDEBUG is defined.
*/
static inline unsigned long long HFSubtract(unsigned long long a, unsigned long long b) {
    assert(a >= b);
    return a - b;
}

/*!
 Returns the smallest multiple of B strictly larger than A.
*/
static inline unsigned long long HFRoundUpToNextMultiple(unsigned long long a, unsigned long long b) {
    assert(b > 0);
    return HFSum(a, b - a % b);
}

/*! Like NSMaxRange, but for an HFRange. */
static inline unsigned long long HFMaxRange(HFRange a) {
    assert(HFSumDoesNotOverflow(a.location, a.length));
    return a.location + a.length;
}

/*! Returns YES if needle is fully contained within haystack.  Equal ranges are always considered to be subranges of each other (even if they are empty).  Furthermore, a zero length needle at the end of haystack is considered a subrange - for example, {6, 0} is a subrange of {3, 3}. */
static inline BOOL HFRangeIsSubrangeOfRange(HFRange needle, HFRange haystack) {
    // handle the case where our needle starts before haystack, or is longer than haystack.  These conditions are important to prevent overflow in future checks.
    if (needle.location < haystack.location || needle.length > haystack.length) return NO;
    
    // Equal ranges are considered to be subranges.  This is an important check, because two equal ranges of zero length are considered to be subranges.
    if (HFRangeEqualsRange(needle, haystack)) return YES;
    
    // handle the case where needle is a zero-length range at the very end of haystack.  We consider this a subrange - that is, (6, 0) is a subrange of (3, 3)
    // rearrange the expression needle.location > haystack.location + haystack.length in a way that cannot overflow
    if (needle.location - haystack.location > haystack.length) return NO;
    
    // rearrange expression: (needle.location + needle.length > haystack.location + haystack.length) in a way that cannot produce overflow
    if (needle.location - haystack.location > haystack.length - needle.length) return NO;
    
    return YES;
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
    //theory: compare a/2 + b/2 to c/2 + d/2, and if they're equal, compare a%2 + b%2 to c%2 + d%2
    unsigned long long sum1 = a/2 + b/2;
    unsigned long long sum2 = c/2 + d/2;
    if (sum1 > sum2) return YES;
    else if (sum1 < sum2) return NO;
    else {
        // sum1 == sum2
        unsigned int sum3 = (unsigned int)(a%2) + (unsigned int)(b%2);
        unsigned int sum4 = (unsigned int)(c%2) + (unsigned int)(d%2);
        if (sum3 > sum4) return YES;
        else return NO;
    }
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
#if __LP64__
    return copysign(a, b);
#else
    return copysignf(a, b);
#endif
}

/*! Atomically increments an NSUInteger, returning the new value.  Optionally invokes a memory barrier. */
static inline NSUInteger HFAtomicIncrement(NSUInteger *ptr, BOOL barrier) {
#if __LP64__
    return (barrier ? OSAtomicIncrement64Barrier : OSAtomicIncrement64)((volatile int64_t *)ptr);
#else
    return (barrier ? OSAtomicIncrement32Barrier : OSAtomicIncrement32)((volatile int32_t *)ptr);
#endif
}

/*! Atomically decrements an NSUInteger, returning the new value.  Optionally invokes a memory barrier. */
static inline NSUInteger HFAtomicDecrement(NSUInteger *ptr, BOOL barrier) {
#if __LP64__
    return (barrier ? OSAtomicDecrement64Barrier : OSAtomicDecrement64)((volatile int64_t *)ptr);
#else
    return (barrier ? OSAtomicDecrement32Barrier : OSAtomicDecrement32)((volatile int32_t *)ptr);
#endif
}

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
    return MAX(1, low);
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

/*! Returns YES if the given string encoding is a superset of ASCII. */
BOOL HFStringEncodingIsSupersetOfASCII(NSStringEncoding encoding);

/*! Converts an unsigned long long to NSUInteger.  The unsigned long long should be no more than ULLONG_MAX. */
static inline unsigned long ll2l(unsigned long long val) { assert(val <= NSUIntegerMax); return (unsigned long)val; }

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

/*! @brief An object wrapper for the HFRange type.

  A simple class responsible for holding an immutable HFRange as an object.  Methods that logically work on multiple HFRanges usually take or return arrays of HFRangeWrappers. */
@interface HFRangeWrapper : NSObject {
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

#ifndef NDEBUG
void HFStartTiming(const char *name);
void HFStopTiming(void);
#endif
