//
//  HFByteRangeAttributeArray.m
//  HexFiend_2
//
//  Created by Peter Ammon on 8/24/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "HFByteRangeAttributeArray.h"

/* This is a very naive class and it should use a better data structure than an array. */

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

- (id)mutableCopyWithZone:(NSZone *)zone {
    HFByteRangeAttributeArray *result = [[[self class] allocWithZone:zone] init];
    [result->attributeRuns addObjectsFromArray:attributeRuns];
    return result;
}

- (BOOL)isEmpty {
    return [attributeRuns count] == 0;
}

- (void)addAttribute:(NSString *)attributeName range:(HFRange)range {
    HFASSERT(attributeName != nil);
    HFByteRangeAttributeRun *run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:range];
    [attributeRuns addObject:run];
    [run release];
}

-  (void)removeAttribute:(NSString *)attributeName range:(HFRange)range {
    HFASSERT(attributeName != nil);
    NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
    NSUInteger index = 0, max = [attributeRuns count];
    for (index = 0; index < max; index++) {
        HFByteRangeAttributeRun *run = [attributeRuns objectAtIndex:index];
        if ([attributeName isEqualToString:run->name] && HFIntersectsRange(range, run->range)) {
            HFRange leftRemainder = {0, 0}, rightRemainder = {0, 0};
            if (run->range.location < range.location) {
                leftRemainder = HFRangeMake(run->range.location, range.location - run->range.location);
            }
            if (HFRangeExtendsPastRange(run->range, range)) {
                rightRemainder.location = HFMaxRange(range);
                rightRemainder.length = HFMaxRange(run->range) - rightRemainder.location;
            }
            if (leftRemainder.length || rightRemainder.length) {
                /* Replacing existing run with remainder */
                run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:(leftRemainder.length ? leftRemainder : rightRemainder)];
                [attributeRuns replaceObjectAtIndex:index withObject:run];
                [run release];
            }
            if (leftRemainder.length && rightRemainder.length) {
                /* We have two to insert.  The second must be the right remainder, because we inserted the left up above. */
                index += 1;
                max += 1;
                run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:rightRemainder];
                [attributeRuns insertObject:run atIndex:index];
                [run release];                
            }
            if (! leftRemainder.length && ! rightRemainder.length) {
                /* We don't have any remainder.  Just delete it. */
                [attributeRuns removeObjectAtIndex:index];
                index -= 1;
                max -= 1;
            }     
        }
    }
    [attributeRuns removeObjectsAtIndexes:indexesToRemove];
    [indexesToRemove release];
}

- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length {
    NSMutableSet *result = [NSMutableSet set];
    unsigned long long maxLocation = ULLONG_MAX;
    FOREACH(HFByteRangeAttributeRun *, run, attributeRuns) {
        unsigned long long runStart = run->range.location;            
        unsigned long long runEnd = HFMaxRange(run->range);        
        if (runStart > index) {
            maxLocation = MIN(maxLocation, runStart);
        }
        else if (runEnd > index) {
            maxLocation = MIN(maxLocation, runEnd);
        }
        if (HFLocationInRange(index, run->range)) {
            [result addObject:run->name];
        }
    }
    if (length) *length = maxLocation - index;
    return result;
}

- (void)transferAttributesFromAttributeArray:(HFByteRangeAttributeArray *)array range:(HFRange)range baseOffset:(unsigned long long)baseOffset {
    HFASSERT(array != NULL);
    EXPECT_CLASS(array, HFByteRangeAttributeArray);
    FOREACH(HFByteRangeAttributeRun *, run, array->attributeRuns) {
        HFRange intersection = HFIntersectionRange(range, run->range);
        if (intersection.length > 0) {
            intersection.location += baseOffset;
            [self addAttribute:run->name range:intersection];
        }
    }
}


@end
