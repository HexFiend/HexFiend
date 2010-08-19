//
//  HFIndexSet.m
//  HexFiend_2
//
//  Created by Peter Ammon on 8/4/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFIndexSet.h>
#import <objc/objc-auto.h>

/* A range capacity of 0 means we're using our single range in our union.  A range capacity > 0 means we are using the multiple ranges. */

@interface HFIndexSet (HFPrivateStuff)

- (NSUInteger)bsearchOnValue:(unsigned long long)idx;
- (HFRange *)pointerToRangeAtIndex:(NSUInteger)idx;

@end

@implementation HFIndexSet

- (id)init {
    return [super init];
}

- (id)initWithValue:(unsigned long long)value {
    [self init];
    rangeCount = 1;
    singleRange = HFRangeMake(value, 1);
    return self;
}

- (id)initWithValuesInRange:(HFRange)range {
    [self init];
    rangeCount = 1;
    singleRange = range;
    return self;    
}

- (NSUInteger)hash {
    return rangeCount;
}

- (NSUInteger)numberOfRanges {
    return rangeCount;
}

- (HFRange)rangeAtIndex:(NSUInteger)idx {
    HFASSERT(idx < rangeCount);
    if (rangeCapacity == 0) return singleRange;
    return multipleRanges[idx];
}

- (HFRange *)pointerToRangeAtIndex:(NSUInteger)idx {
    HFASSERT(idx < rangeCount);
    if (rangeCapacity == 0) return &singleRange;
    return multipleRanges + idx;    
}

- (BOOL)isEqual:(HFIndexSet *)val {
    if (self == val) return YES;
    if (! [val isKindOfClass:[HFIndexSet class]]) return NO;
    if (val->rangeCount != rangeCount) return NO;
    NSUInteger i, max = rangeCount;
    for (i=0; i < max; i++) {
	if (! HFRangeEqualsRange([self rangeAtIndex:i], [val rangeAtIndex:i])) return NO;
    }
    return YES;
}

- (unsigned long long)numberOfValues {
    /* This should maybe be cached */
    unsigned long long result;
    if (rangeCount == 0) {
	result = 0;
    }
    else if (rangeCapacity == 0) {
	result = singleRange.length;
    }
    else {
	result = 0;
	for (NSUInteger i=0; i < rangeCount; i++) {
	    result = HFSum(result, multipleRanges[i].length);
	}
    }
    return result;
}

- (BOOL)isEqualToNSIndexSet:(NSIndexSet *)indexSet {
    if ((unsigned long long)[indexSet count] != [self numberOfValues]) return NO;
    for (NSUInteger i=0; i < rangeCount; i++) {
	const HFRange *rangePtr = [self pointerToRangeAtIndex:i];
	if (HFMaxRange(*rangePtr) >= NSNotFound) return NO; //NSIndexSet does not support indices at or above NSNotFound
	NSRange nsrange = NSMakeRange(ll2l(rangePtr->location), ll2l(rangePtr->length));
	if (! [indexSet containsIndexesInRange:nsrange]) return NO;
    }
    return YES;
}

- (void)dealloc {
    free(multipleRanges);
    [super dealloc];
}

- (id)initWithIndexSet:(HFIndexSet *)otherSet {
    HFASSERT(otherSet != nil);
    rangeCount = otherSet->rangeCount;
    if (rangeCount == 0) {
	/* Nothing */
    }
    else if (rangeCount == 1) {
	/* Single range */
	singleRange = [otherSet rangeAtIndex:0];
    }
    else {
	/* Multiple ranges */
	size_t size = rangeCount * sizeof *multipleRanges;
	multipleRanges = NSAllocateCollectable(size, 0); //unscanned, collectable
	memcpy(multipleRanges, otherSet->multipleRanges, size);
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    /* Usual Cocoa thing */
    return [self retain];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    /* Usual Cocoa thing */
    return [(HFMutableIndexSet *)[HFMutableIndexSet alloc] initWithIndexSet:self];
}

#if ! NDEBUG
- (NSUInteger)lsearchOnIndex:(unsigned long long)idx {
    NSUInteger i, max = [self numberOfRanges];
    for (i=0; i < max; i++) {
	HFRange range = [self rangeAtIndex:i];
	if (HFMaxRange(range) > idx) break;
    }
    return i;
}
#endif

/* Returns the index of the range containing the given idx.  If no range contains the idx, returns the index of the first range after it.  If no range is after it, returns rangeCount. */
- (NSUInteger)bsearchOnValue:(unsigned long long)idx {
    NSUInteger result;
    if (rangeCount == 0) {
	/* No ranges */
	result = 0;
    }
    else if (rangeCapacity == 0) {
	/* Single range */
	result = (idx < HFMaxRange(singleRange)) ? 0 : 1;
    }
    else {
	/* Now try the binary search */
	NSUInteger lo = 0, hi = rangeCount;
	while (lo + 1 < hi) {
	    NSUInteger mid = lo + (hi - lo) / 2;
	    if (idx < multipleRanges[mid].location) {
		/* Too high */
		hi = mid;
	    }
	    else if (idx >= HFMaxRange(multipleRanges[mid])) {
		/* Too low */
		lo = mid + 1;
	    }
	    else {
		/* This porridge is just right */
		break;
	    }
	}
	/* lo may contain the index of the last range before idx.  We want the first range after it. */
	if (HFLocationInRange(idx, multipleRanges[lo])) {
	    result = lo;
	}
	else {
	    result = lo + 1;
	}
    }
#if ! NDEBUG
    HFASSERT([self lsearchOnIndex:idx] == result);
#endif
    return result;
}

- (NSUInteger)indexOfRangeContainingValue:(unsigned long long)value {
    /* Returns the index of the range containing the given value, or NSNotFound if it is not found */
    NSUInteger idx = [self bsearchOnValue:value];
    if (idx < rangeCount && HFLocationInRange(value, [self rangeAtIndex:idx])) {
	return idx;
    }
    else {
	return NSNotFound;
    }
}

- (HFRange)rangeContainingValue:(unsigned long long)idx {
    HFRange resultRange = {ULLONG_MAX, ULLONG_MAX};
    NSUInteger indexOfRange = [self bsearchOnValue:idx];
    if (indexOfRange < rangeCount) {
	HFRange nearestRange = [self rangeAtIndex:indexOfRange];
	if (HFLocationInRange(idx, nearestRange)) {
	    resultRange = nearestRange;
	}
    }
    return resultRange;
}

@end

@implementation HFMutableIndexSet

- (void)setCapacity:(NSUInteger)newCapacity {
    if (rangeCapacity == newCapacity) return;
    if (rangeCapacity == 0) {
	/* Go multi */
	multipleRanges = NSAllocateCollectable(newCapacity * sizeof *multipleRanges, 0); //unscanned, collectable
	multipleRanges[0] = singleRange;
    }
    else if (newCapacity == 0) {
	/* Go singular */
	singleRange = [self rangeAtIndex:0];
	if (! objc_collectingEnabled()) free(multipleRanges);
	multipleRanges = NULL;
    }
    else {
	/* Reallocate */
	multipleRanges = NSReallocateCollectable(multipleRanges, newCapacity * sizeof *multipleRanges, 0);
    }
    rangeCapacity = newCapacity;
}

- (id)copyWithZone:(NSZone *)zone {
    /* Usual Cocoa thing */
    return [(HFIndexSet *)[HFIndexSet alloc] initWithIndexSet:self];
}

static BOOL mergeRange(HFRange *target, HFRange src) {
    if (target->location > HFMaxRange(src) || src.location > HFMaxRange(*target)) return NO; //not mergeable
    *target = HFUnionRange(*target, src);
    return YES;
}

/* Divides the given range 'source' into up to two ranges surrounding rangeToDelete, returning the number of ranges (0, 1, or 2) */
static NSUInteger deleteFromRange(HFRange source, HFRange rangeToDelete, HFRange *outputRanges) {
    NSUInteger result = 0;
    
    /* Left side */
    if (rangeToDelete.location > source.location) {
	outputRanges[result].location = source.location;
	outputRanges[result].length = MIN(HFMaxRange(source), rangeToDelete.location) - outputRanges[result].location;
	result += 1;
    }
    
    /* Right side */
    if (HFMaxRange(rangeToDelete) < HFMaxRange(source)) {
	outputRanges[result].location = MAX(HFMaxRange(rangeToDelete), source.location);
	outputRanges[result].length = HFMaxRange(source) - outputRanges[result].location;
	result += 1;
    }
    
    return result;
}

- (void)insertRanges:(const HFRange * restrict)ranges atIndex:(NSUInteger)idx count:(NSUInteger)newRangeCount {
    HFASSERT(idx <= rangeCount);
    
    if (newRangeCount == 0) {
	/* Nothing to do */
    }
    else if (newRangeCount == 1 && rangeCount == 0) {
	/* Handle inserting a single range over an empty set */
	[self setCapacity:1];
	*[self pointerToRangeAtIndex:0] = singleRange;
    }
    else {
	/* Handle multiple ranges */
	[self setCapacity:MAX(rangeCount + newRangeCount, rangeCapacity)];
	
	/* Make our gap.  We know we must be multiple because capacity must be at least 2. */
	memmove(multipleRanges + idx + newRangeCount, multipleRanges + idx, (rangeCount - idx) * sizeof *multipleRanges);
	
	/* Now insert */
	memcpy(multipleRanges + idx, ranges, newRangeCount * sizeof *multipleRanges);
	
	/* Increase our range count */
	rangeCount += newRangeCount;
    }
}

- (void)deleteRangesInRange:(NSRange)range {
    HFASSERT(NSMaxRange(range) <= rangeCount);
    if (range.length == 0) {
	/* Nothing to do */
    }
    else if (range.length == rangeCount) {
	/* Delete everything */
	rangeCount = 0;
	[self setCapacity:0];
    }
    else if (range.length + 1 == rangeCount) {
	/* Deleting all but one */
	HFRange remainingRange = [self rangeAtIndex: (range.location > 0 ? 0 : rangeCount - 1)];
	[self setCapacity:0];
	rangeCount = 1;
	singleRange = remainingRange;
    }
    else {
	/* Delete, leaving more than one.  We must be multiple in this case */
	NSUInteger remainingOnRight = rangeCount - NSMaxRange(range);
	/* Copy left */
	memmove(multipleRanges + range.location, multipleRanges + NSMaxRange(range), remainingOnRight * sizeof *multipleRanges);
	rangeCount -= range.length;
	HFASSERT(rangeCount > 1);
	[self setCapacity:rangeCount];
    }
}

- (void)mergeRightStartingAtIndex:(NSUInteger)idx {
    if (rangeCount > 1) {
	NSUInteger mergeIndex, firstIndexToMerge = idx + 1;
	for (mergeIndex = firstIndexToMerge; mergeIndex < rangeCount; mergeIndex++) {
	    if (! mergeRange(multipleRanges + idx, multipleRanges[mergeIndex])) {
		/* Can't merge, so we're done */
		break;
	    }
	}
	/* mergeIndex is the index of the first range that we could not merge (or is equal to rangeCount), so delete the ranges we merged. */
	[self deleteRangesInRange:NSMakeRange(firstIndexToMerge, mergeIndex - firstIndexToMerge)];
    }
}

- (void)addIndexesInRange:(HFRange)range {
    if (rangeCount == 0) {
	/* No ranges */
	rangeCount = 1;
	singleRange = range;
    }
    else if (rangeCapacity == 0 && mergeRange(&singleRange, range)) { /* Try to merge a single range */
	/* Success, nothing to do */
    }
    else {	
	/* Binary search to find a range location */
	NSUInteger idx = [self bsearchOnValue:range.location];
	
	if (idx > 0 && mergeRange([self pointerToRangeAtIndex:idx - 1], range)) { /* Try merging left */
	    /* Merge left success.  Subtract one from idx to reflect where we merged. */
	    [self mergeRightStartingAtIndex:idx - 1];
	}
	else if (idx < rangeCount && mergeRange([self pointerToRangeAtIndex:idx], range)) { /* Try merging right */
	    /* Merge right success.  Continue merging. */
	    [self mergeRightStartingAtIndex:idx];
	}
	else {
	    /* We can't merge, so we have to insert it. */
	    [self insertRanges:&range atIndex:idx count:1];
	}
    }
}

- (void)removeIndexesInRange:(HFRange)rangeToDelete {
    if (rangeCount == 0 || rangeToDelete.length == 0) {
	/* Nothing to do */
    }
    else if (rangeCount == 1) {
	HFRange newRanges[2];
	NSUInteger count = deleteFromRange([self rangeAtIndex:0], rangeToDelete, newRanges);
	if (count == 0) {
	    /* Deletes everything */
	    rangeCount = 0;
	}
	else if (count == 1) {
	    /* One range */
	    *[self pointerToRangeAtIndex:0] = newRanges[0];
	}
	else {
	    /* Two ranges */
	    [self setCapacity:2];
	    multipleRanges[0] = newRanges[0];
	    multipleRanges[1] = newRanges[2];
	}
    }
    else {
	/* Find the left range that we intersect */
	NSUInteger leftIndex = [self bsearchOnValue:rangeToDelete.location];
	NSUInteger rightIndex = [self bsearchOnValue:HFMaxRange(rangeToDelete)];
	HFASSERT(rightIndex >= leftIndex);
	if (leftIndex == rightIndex) {
	    /* We only have to replace one range */
	    HFRange newRanges[2];
	    NSUInteger count = deleteFromRange([self rangeAtIndex:0], rangeToDelete, newRanges);
	    if (count == 0) {
		/* Delete it, copy right */
		[self deleteRangesInRange:NSMakeRange(leftIndex, 1)];
	    }
	    else if (count == 1) {
		/* Just replace it */
		*[self pointerToRangeAtIndex:leftIndex] = newRanges[0];
	    }
	    else {
		/* Two ranges */
		*[self pointerToRangeAtIndex:leftIndex] = newRanges[0];
		[self addIndexesInRange:newRanges[1]];
	    }
	}
	else {
	    /* We have to replace more than one range */
	    HFRange newRanges[4];
	    NSUInteger rangesToDelete = rightIndex - leftIndex;
	    NSUInteger rangesToInsert = 0;
	    rangesToInsert += deleteFromRange(multipleRanges[leftIndex], rangeToDelete, newRanges);
	    rangesToInsert += deleteFromRange(multipleRanges[rightIndex], rangeToDelete, newRanges + rangesToDelete);
	    
	    /* Replace as many ranges as we can without inserting or deleting */
	    NSUInteger inPlaceReplacementCount;
	    for (inPlaceReplacementCount = 0; inPlaceReplacementCount < MIN(rangesToDelete, rangesToInsert); inPlaceReplacementCount++) {
		*[self pointerToRangeAtIndex:leftIndex + inPlaceReplacementCount] = newRanges[inPlaceReplacementCount];
	    }
	    
	    /* Insert or delete any remaining ones */
	    [self deleteRangesInRange:NSMakeRange(leftIndex + inPlaceReplacementCount, rangesToDelete - inPlaceReplacementCount)];
	    [self insertRanges:newRanges + inPlaceReplacementCount atIndex:leftIndex + inPlaceReplacementCount count:rangesToInsert - inPlaceReplacementCount];
	    
	    /* No need to merge, because deleting ranges never fills holes */
	}
    }
}

- (BOOL)splitRangeAtIndex:(NSInteger)index aboutLocation:(unsigned long long)location {
    HFASSERT(index < rangeCount);
    BOOL result;
    HFRange *nearestRange = [self pointerToRangeAtIndex:index];
    if (location <= nearestRange->location) {
	/* We're either before the range or just at the start, so we don't need to split this range */
	result = NO;
    }
    else {
	result = YES;
    }
    return result;
}

- (void)shiftValuesRightByAmount:(unsigned long long)delta startingAtValue:(unsigned long long)startValue {
    /* Do nothing if we're empty or are shifted by 0. */
    if (rangeCount == 0 || delta == 0) return;
    
    /* See if value is past our end.  If so, nothing will be shifted. */
    HFRange lastRange = [self rangeAtIndex:rangeCount - 1];
    unsigned long long lastValue = HFSum(lastRange.location, lastRange.length - 1);
    if (startValue > lastValue) return;
    
    /* Check for overflow */
    if (lastValue + delta < lastValue) {
	/* Overflow! */
	[NSException raise:NSInvalidArgumentException format:@"Unable to shift indexes in %@ right by %llu: value %llu would overflow", self, delta, lastValue];
    }
    
    /* Figure out where the gap has to be */
    NSUInteger gapIndex = [self bsearchOnValue:startValue];
    HFASSERT(gapIndex < rangeCount); //we expect that we'll be less than rangeCount, because otherwise we should have been caught by the "value past our end" check.
    /* We start shifting at gapIndex, unless we split gapIndex, in which case we start shifting after it */
    NSUInteger rangeIndexToShift = gapIndex;
    if ([self splitRangeAtIndex:gapIndex aboutLocation:startValue]) {
	/* startValue fell in the middle of a range, so we split the range.  The left part we don't shift, the right part we do.  Since left is inserted at gapIndex, increase gapIndex by 1 so we start shifting at the index of the right part. */
	rangeIndexToShift += 1;
    }

    /* Now shift any ranges */
    for (; rangeIndexToShift < rangeCount; rangeIndexToShift++) {
	if (rangeCapacity == 0) {
	    /* One single range, we know we must shift it */
	    HFASSERT(rangeIndexToShift == 0);
	    singleRange.location = HFSum(singleRange.location, delta);
	}
	else {
	    /* Multiple ranges */
	    multipleRanges[rangeIndexToShift].location = HFSum(multipleRanges[rangeIndexToShift].location, delta); 
	}
    }
}

- (void)shiftValuesLeftByAmount:(unsigned long long)delta startingAtValue:(unsigned long long)value {
    /* It doesn't make sense to shift left more than the starting value */
    HFASSERT(value >= delta);
    
    /* Do nothing if we're empty or are shifted by 0. */
    if (rangeCount == 0 || delta == 0) return;
    
    /* Delete values in the covered range */
    [self removeIndexesInRange:HFRangeMake(value - delta, delta)];
    
    /* Now shift any ranges over.  We have nice property that our range is already split by the deletion (though maybe we'll have to merge it */
    NSUInteger rangeIndex = [self bsearchOnValue:value];
    if (rangeIndex < rangeCount) {
	const HFRange *rangePtr = [self pointerToRangeAtIndex:rangeIndex];
	
	/* We expect that we can't be within the range, because we deleted ranges in that index */
	HFASSERT(rangePtr->location >= value);
	
	/* Now shift any ranges */
	for (NSUInteger rangeIndexToShift = rangeIndex; rangeIndexToShift < rangeCount; rangeIndexToShift++) {
	    if (rangeCapacity == 0) {
		/* One single range, we know we must shift it */
		HFASSERT(rangeIndexToShift == 0);
		singleRange.location = HFSubtract(singleRange.location, delta);
	    }
	    else {
		/* Multiple ranges */
		multipleRanges[rangeIndexToShift].location = HFSubtract(multipleRanges[rangeIndexToShift].location, delta); 
	    }
	}
	
	/* We may have to merge */
	if (rangeIndex > 0) [self mergeRightStartingAtIndex:rangeIndex - 1];
    }
}

- (void)shiftValuesLeftByAmount:(unsigned long long)delta endingAtValue:(unsigned long long)endValue {
    /* Do nothing if we're empty or are shifted by 0. */
    if (rangeCount == 0 || delta == 0) return;
    
    /* Maybe the values to shift are below our first value */
    unsigned long long firstValue = [self rangeAtIndex:0].location;
    if (endValue <= firstValue) return;
    
    /* Check for underflow */
    if (firstValue < delta) {
	/* Underflow! */
	[NSException raise:NSInvalidArgumentException format:@"Unable to shift indexes in %@ left by %llu: value %llu would underflow", self, delta, firstValue];
    }
    
    /* Figure out where the gap has to be */
    NSUInteger gapIndex = [self bsearchOnValue:endValue];
    /* We end shifting at gapIndex, unless we split that range, in which case we want to shift the left part */
    NSUInteger firstRangeIndexToNotShift = gapIndex;
    if ([self splitRangeAtIndex:gapIndex aboutLocation:endValue]) {
	/* startValue fell in the middle of a range, so we split the range.  The left part we do shift, the right part we do not.  Since left is inserted at gapIndex, increase gapIndex by 1 so we stop shifting at the index of the right part. */
	firstRangeIndexToNotShift += 1;
    }
    
    /* Now shift any ranges */
    for (NSUInteger rangeIndexToShift = 0; rangeIndexToShift < firstRangeIndexToNotShift; rangeIndexToShift++) {
	if (rangeCapacity == 0) {
	    /* One single range, we know we must shift it */
	    HFASSERT(rangeIndexToShift == 0);
	    singleRange.location = HFSubtract(singleRange.location, delta);
	}
	else {
	    /* Multiple ranges */
	    multipleRanges[rangeIndexToShift].location = HFSubtract(multipleRanges[rangeIndexToShift].location, delta); 
	}
    }
}

@end
