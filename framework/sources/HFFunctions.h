/* Functions and convenience methods for working with HFTypes */

#import <HexFiend/HFTypes.h>

static inline HFRange HFRangeMake(unsigned long long loc, unsigned long long len) {
    return (HFRange){loc, len};
}

static inline NSString* HFRangeToString(HFRange range) {
	return [NSString stringWithFormat:@"{%llu, %llu}", range.location, range.length];
}

static inline BOOL HFRangeIsSubrangeOfRange(HFRange needle, HFRange haystack) {
    if (needle.location < haystack.location || needle.length > haystack.length) return NO;
    // rearrange expression: (needle.location + needle.length > haystack.location + haystack.length) in a way that cannot produce overflow
    if (needle.location - haystack.location > haystack.length - needle.length) return NO;
    return YES;
}

static inline BOOL HFSumDoesNotOverflow(unsigned long long a, unsigned long long b) {
    return a + b >= a;
}

static inline unsigned long ll2l(unsigned long long val) { assert(val <= UINT_MAX); return (unsigned long)val; }

static inline BOOL HFRangeEqualsRange(HFRange a, HFRange b) {
    return a.location == b.location && a.length == b.length;
}

@interface HFRangeWrapper : NSObject {
    @public
    HFRange range;
}

- (HFRange)HFRange;
+ (HFRangeWrapper *)withRange:(HFRange)range;

@end
