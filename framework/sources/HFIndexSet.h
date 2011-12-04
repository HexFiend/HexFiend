//
//  HFIndexSet.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>


/*! @class HFIndexSet
    @brief Hex Fiend's answer to NSIndexSet.  It can contain any unsigned long long value.
*/
@interface HFIndexSet : NSObject <NSCopying, NSMutableCopying> {
    @protected
    NSUInteger rangeCount;
    NSUInteger rangeCapacity;
    HFRange singleRange;
    __strong HFRange *multipleRanges;
}

/*! Initializes the receiver as empty. */
- (id)init;

/*! Initializes the receiver with a single index. */
- (id)initWithValue:(unsigned long long)value;

/*! Initializes the receiver with the indexes in a single range. */
- (id)initWithValuesInRange:(HFRange)range;

/*! Initializes the receiver with the indexes in an NSIndexSet. */
- (id)initWithIndexSet:(HFIndexSet *)otherSet;

/*! Returns the number of ranges in the set. */
- (NSUInteger)numberOfRanges;

/*! Returns the range at a given index. */
- (HFRange)rangeAtIndex:(NSUInteger)idx;

/*! Returns the number of values in a given range. */
- (unsigned long long)countOfValuesInRange:(HFRange)range;

/*! Returns the number of values in the set. */
- (unsigned long long)countOfValues;

#if ! NDEBUG
- (void)verifyIntegrity;
#endif

/*! Returns the range containing the given value.  If the index is not present in the set, returns {ULLONG_MAX, ULLONG_MAX}. */
- (HFRange)rangeContainingValue:(unsigned long long)idx;

/*! Indicates whether the receiver contains exactly the same indexes as the given NSIndexSet. */
- (BOOL)isEqualToNSIndexSet:(NSIndexSet *)indexSet;

@end

/*! @class HFMutableIndexSet
    @brief The mutable subclass of HFIndexSet
*/
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
