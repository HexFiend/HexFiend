#import <HexFiend/HFFunctions.h>

@implementation HFRangeWrapper

- (HFRange)HFRange { return range; }

+ (HFRangeWrapper *)withRange:(HFRange)range {
    HFRangeWrapper *result = [[self alloc] init];
    result->range = range;
    return [result autorelease];
}

@end
