/* Functions and convenience methods for working with HFTypes */

#import <HexFiend/HFTypes.h>

static inline HFRange HFRangeMake(unsigned long long loc, unsigned long long len) {
    return (HFRange){loc, len};
}

static inline BOOL HFLocationInRange(unsigned long long location, HFRange range) {
    return location >= range.location && location - range.location < range.length;
}

static inline NSString* HFRangeToString(HFRange range) {
    return [NSString stringWithFormat:@"{%llu, %llu}", range.location, range.length];
}

static inline NSString* HFFPRangeToString(HFFPRange range) {
    return [NSString stringWithFormat:@"{%Lf, %Lf}", range.location, range.length];
}

static inline BOOL HFRangeEqualsRange(HFRange a, HFRange b) {
    return a.location == b.location && a.length == b.length;
}

static inline BOOL HFSumDoesNotOverflow(unsigned long long a, unsigned long long b) {
    return a + b >= a;
}

static inline NSUInteger HFProductInt(NSUInteger a, NSUInteger b) {
    NSUInteger result = a * b;
    assert(a == 0 || result / a == b); //detect overflow
    return result;
}

static inline unsigned long long HFProductULL(unsigned long long a, unsigned long long b) {
    unsigned long long result = a * b;
    assert(a == 0 || result / a == b); //detect overflow
    return result;
}

static inline unsigned long long HFSum(unsigned long long a, unsigned long long b) {
    assert(HFSumDoesNotOverflow(a, b));
    return a + b;
}

/* Returns the smallest multiple of B strictly larger than A */
static inline unsigned long long HFRoundUpToNextMultiple(unsigned long long a, unsigned long long b) {
    assert(b > 0);
    return HFSum(a, b - a % b);
}

static inline unsigned long long HFMaxRange(HFRange a) {
    assert(HFSumDoesNotOverflow(a.location, a.length));
    return a.location + a.length;
}

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

static inline BOOL HFRangeIsEmptyAndAtEndOfRange(HFRange needle, HFRange haystack) {
    return needle.length == 0 && needle.location == HFMaxRange(haystack);
}

static inline BOOL HFIntersectsRange(HFRange a, HFRange b) {
    // Ranges are said to intersect if they share at least one value.  Therefore, zero length ranges never intersect anything.
    if (a.length == 0 || b.length == 0) return NO;
    
    // rearrange (a.location < b.location + b.length && b.location < a.location + a.length) to not overflow
    // = ! (a.location >= b.location + b.length || b.location >= a.location + a.length)
    BOOL clause1 = (a.location >= b.location && a.location - b.location >= b.length);
    BOOL clause2 = (b.location >= a.location && b.location - a.location >= a.length);
    return ! (clause1 || clause2);
}

static inline HFRange HFUnionRange(HFRange a, HFRange b) {
    assert(HFIntersectsRange(a, b) || HFMaxRange(a) == b.location || HFMaxRange(b) == a.location);
    HFRange result;
    result.location = MIN(a.location, b.location);
    assert(HFSumDoesNotOverflow(a.location, a.length));
    assert(HFSumDoesNotOverflow(b.location, b.length));
    result.length = MAX(a.location + a.length, b.location + b.length) - result.location;
    return result;
}


/* Returns whether a+b > c+d, as if there were no overflow (so ULLONG_MAX + 1 > 10 + 20) */
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

static inline unsigned long long HFAbsoluteDifference(unsigned long long a, unsigned long long b) {
    if (a > b) return a - b;
    else return b - a;
}

static inline BOOL HFRangeExtendsPastRange(HFRange a, HFRange b) {
    return HFSumIsLargerThanSum(a.location, a.length, b.location, b.length);
}

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

static inline CGFloat HFCeil(CGFloat a) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)ceilf((float)a);
    else return (CGFloat)ceil((double)a);
}

static inline CGFloat HFFloor(CGFloat a) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)floorf((float)a);
    else return (CGFloat)floor((double)a);
}

static inline CGFloat HFRound(CGFloat a) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)roundf((float)a);
    else return (CGFloat)round((double)a);
}

static inline CGFloat HFMin(CGFloat a, CGFloat b) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)fminf((float)a, (float)b);
    else return (CGFloat)fmin((double)a, (double)b);    
}

static inline CGFloat HFMax(CGFloat a, CGFloat b) {
    if (sizeof(a) == sizeof(float)) return (CGFloat)fmaxf((float)a, (float)b);
    else return (CGFloat)fmax((double)a, (double)b);    
}

static inline BOOL HFFPRangeEqualsRange(HFFPRange a, HFFPRange b) {
    return a.location == b.location && a.length == b.length;
}

/* Converts a long double to unsigned long long.  Assumes that val is already an integer - use floorl or ceill */
static inline unsigned long long HFFPToUL(long double val) {
    assert(val >= 0);
    assert(val <= ULLONG_MAX);
    unsigned long long result = (unsigned long long)val;
    assert((long double)result == val);
    return result;
}

static inline long double HFULToFP(unsigned long long val) {
    long double result = (long double)val;
    assert(HFFPToUL(result) == val);
    return result;
}

static inline NSString *HFDescribeAffineTransform(CGAffineTransform t) {
    return [NSString stringWithFormat:@"%f %f 0\n%f %f 0\n%f %f 1", t.a, t.b, t.c, t.d, t.tx, t.ty];
}

BOOL HFStringEncodingIsSupersetOfASCII(NSStringEncoding encoding);

static inline unsigned long ll2l(unsigned long long val) { assert(val <= NSUIntegerMax); return (unsigned long)val; }

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

/* Returns the quotient of a divided by b, rounding up.  Will not overflow. */
static inline unsigned long long HFDivideULLRoundingUp(unsigned long long a, unsigned long long b) {
    if (a == 0) return 0;
    else return ((a - 1) / b) + 1;
}

static inline NSUInteger HFDivideULRoundingUp(NSUInteger a, NSUInteger b) {
    if (a == 0) return 0;
    else return ((a - 1) / b) + 1;
}


@interface HFRangeWrapper : NSObject {
    @public
    HFRange range;
}

- (HFRange)HFRange;
+ (HFRangeWrapper *)withRange:(HFRange)range;
+ (NSArray *)withRanges:(const HFRange *)ranges count:(NSUInteger)count;

/* Sorts and merges overlapping ranges */
+ (NSArray *)organizeAndMergeRanges:(NSArray *)inputRanges;

+ (void)getRanges:(HFRange *)ranges fromArray:(NSArray *)array;

@end
