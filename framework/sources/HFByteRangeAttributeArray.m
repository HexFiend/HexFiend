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
    NSRange range;
}

- (id)initWithName:(NSString *)nameParameter range:(NSRange)rangeParameter;

@end

@implementation HFByteRangeAttributeRun

- (id)initWithName:(NSString *)nameParameter range:(NSRange)rangeParameter {
    HFASSERT(nameParameter != nil);
    [super init];
    name = [nameParameter copy];
    range = rangeParameter;
    return self;
}

- (void)dealloc {
    [name release];
    [super dealloc];
}

@end


@implementation HFByteRangeAttributeArray

- (id)init {
    [super init];
    attributeRuns = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc {
    [attributeRuns release];
    [super dealloc];
}

- (void)addAttribute:(NSString *)attributeName range:(NSRange)range {
    HFASSERT(attributeName != nil);
    HFByteRangeAttributeRun *run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:range];
    [attributeRuns addObject:run];
    [run release];
}

- (NSArray *)attributesAtIndex:(NSUInteger)index range:(NSRange *)range {
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger maxLocation = NSUIntegerMax;
    FOREACH(HFByteRangeAttributeRun *, run, attributeRuns) {
        if (NSLocationInRange(index, run->range)) {
            [result addObject:run->name];
            maxLocation = MIN(maxLocation, NSMaxRange(run->range));
        }
    }
    if (range) *range = NSMakeRange(index, maxLocation - index);
    return result;
}

@end
