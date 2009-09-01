//
//  HFByteRangeAttributeArray.m
//  HexFiend_2
//
//  Created by Peter Ammon on 8/24/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "HFByteRangeAttributeArray.h"

@interface HFByteRangeAttributeRun : NSObject {
@public
    NSString *name;
    HFRange range;
}

- (id)initWithName:(NSString *)nameParameter range:(HFRange)rangeParameter;

@end

@implementation HFByteRangeAttributeRun

- (id)initWithName:(NSString *)nameParameter range:(HFRange)rangeParameter {
    HFASSERT(nameParameter != nil);
    [super init];
    name = [nameParameter copy];
    range = rangeParameter;
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@ {%llu, %llu}]", name, range.location, range.length];
}

- (void)dealloc {
    [name release];
    [super dealloc];
}

@end


@implementation HFByteRangeAttributeArray

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p %@>", [self class], self, attributeRuns];
}

- (id)init {
    [super init];
    attributeRuns = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc {
    [attributeRuns release];
    [super dealloc];
}

- (void)addAttribute:(NSString *)attributeName range:(HFRange)range {
    HFASSERT(attributeName != nil);
    HFByteRangeAttributeRun *run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:range];
    [attributeRuns addObject:run];
    [run release];
}

- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length {
    NSMutableSet *result = [NSMutableSet set];
    unsigned long long maxLocation = ULLONG_MAX;
    FOREACH(HFByteRangeAttributeRun *, run, attributeRuns) {
        unsigned long long runEnd = HFMaxRange(run->range);
        if (runEnd > index && runEnd < maxLocation) {
            maxLocation = runEnd;
        }
        if (HFLocationInRange(index, run->range)) {
            [result addObject:run->name];
        }
    }
    if (length) *length = maxLocation - index;
    return result;
}

- (void)transferAttributesFromAttributeArray:(HFByteRangeAttributeArray *)array baseOffset:(unsigned long long)baseOffset {
    HFASSERT(array != NULL);
    EXPECT_CLASS(array, HFByteRangeAttributeArray);
    FOREACH(HFByteRangeAttributeRun *, run, array->attributeRuns) {
        [self addAttribute:run->name range:HFRangeMake(HFSum(baseOffset, run->range.location), run->range.length)];
    }
}

@end
