//
//  HFIndexSet.h
//  HexFiend_2
//
//  Created by Peter Ammon on 8/4/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>


/*! @header HFIndexSet
    @abstract Hex Fiend's answer to NSIndexSet.  It can contain any unsigned long long value.
 */

@interface HFIndexSet : NSObject <NSCopying, NSMutableCopying> {
    @protected
    NSUInteger rangeCount;
    NSUInteger rangeCapacity;
    HFRange singleRange;
    __strong HFRange *multipleRanges;
}

- (id)init;
- (id)initWithValue:(unsigned long long)value;
- (id)initWithValuesInRange:(HFRange)range;
- (id)initWithIndexSet:(HFIndexSet *)otherSet;

- (NSUInteger)numberOfRanges;
- (HFRange)rangeAtIndex:(NSUInteger)idx;

- (unsigned long long)countOfValuesInRange:(HFRange)range;

- (unsigned long long)countOfValues;

#if ! NDEBUG
- (void)verifyIntegrity;
#endif

/*! Returns the range containing the given value.  If the index is not present in the set, returns {ULLONG_MAX, ULLONG_MAX}. */
- (HFRange)rangeContainingValue:(unsigned long long)idx;

@end

@interface HFMutableIndexSet : HFIndexSet

/*! Adds indexes in the given range. */
- (void)addIndexesInRange:(HFRange)range;

/*! Removes indexes in the given range. */
- (void)removeIndexesInRange:(HFRange)range;

/*! Shifts all values equal to or greater than the given value right (increase) by the given delta.  This raises an exception if indexes are shifted past ULLONG_MAX. */
- (void)shiftValuesRightByAmount:(unsigned long long)delta startingAtValue:(unsigned long long)value;

/*! Shifts all values equal to or greater than the given value left (decrease) by the given delta.  Values within the range {value - delta, delta} are deleted. This raises an exception if indexes are shifted below 0. */
- (void)shiftValuesLeftByAmount:(unsigned long long)delta startingAtValue:(unsigned long long)value;

/*! Shifts all values less than the given value left (decrease) by the given delta.  This raises an exception of indexes are shifted below 0. */
- (void)shiftValuesLeftByAmount:(unsigned long long)delta endingAtValue:(unsigned long long)value;

@end

@interface HFIndexSet (HFNSIndexSetCompatibility)

/*! Indicates whether the receiver contains exactly the same indexes as the given NSIndexSet. */
- (BOOL)isEqualToNSIndexSet:(NSIndexSet *)indexSet;

@end