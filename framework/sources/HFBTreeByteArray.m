//
//  HFBTreeByteArray.m
//  HexFiend_2
//
//  Created by peter on 4/28/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFByteSlice.h>
#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFBTree.h>

@implementation HFBTreeByteArray

- (instancetype)init {
    if ((self = [super init])) {
        btree = [[HFBTree alloc] init];
    }
    return self;
}

- (void)dealloc {
    [btree release];
    [super dealloc];
}

- (unsigned long long)length {
    return [btree length];
}

- (NSArray *)byteSlices {
    return [btree allEntries];
}

- (NSEnumerator *)byteSliceEnumerator {
    return [btree entryEnumerator];
}

- (NSString*)description {
    NSMutableArray* result = [NSMutableArray array];
    NSEnumerator *enumer = [self byteSliceEnumerator];
    HFByteSlice *slice;
    unsigned long long offset = 0;
    while ((slice = [enumer nextObject])) {
        unsigned long long length = [slice length];
        [result addObject:[NSString stringWithFormat:@"{%llu - %llu}", offset, length]];
        offset = HFSum(offset, length);
    }
    if (! [result count]) return @"(empty tree)";
    return [NSString stringWithFormat:@"<%@: %p>: %@", [self class], self, [result componentsJoinedByString:@" "]];
    
}

struct HFBTreeByteArrayCopyInfo_t {
    unsigned char *dst;
    unsigned long long startingOffset;
    NSUInteger remainingLength;
};

static BOOL copy_bytes(id entry, HFBTreeIndex offset, void *userInfo) {
    struct HFBTreeByteArrayCopyInfo_t *info = userInfo;
    HFByteSlice *slice = entry;
    HFASSERT(slice != nil);
    HFASSERT(info != NULL);
    HFASSERT(offset <= info->startingOffset);
    
    unsigned long long sliceLength = [slice length];
    HFASSERT(sliceLength > 0);
    unsigned long long offsetIntoSlice = info->startingOffset - offset;
    HFASSERT(offsetIntoSlice < sliceLength);
    NSUInteger amountToCopy = ll2l(MIN(info->remainingLength, sliceLength - offsetIntoSlice));
    HFRange srcRange = HFRangeMake(info->startingOffset - offset, amountToCopy);
    [slice copyBytes:info->dst range:srcRange];
    info->dst += amountToCopy;
    info->startingOffset = HFSum(info->startingOffset, amountToCopy);
    info->remainingLength -= amountToCopy;
    return info->remainingLength > 0;
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax);
    HFASSERT(HFMaxRange(range) <= [self length]);
    if (range.length > 0) {
	struct HFBTreeByteArrayCopyInfo_t copyInfo = {.dst = dst, .remainingLength = ll2l(range.length), .startingOffset = range.location};
	[btree applyFunction:copy_bytes toEntriesStartingAtOffset:range.location withUserInfo:&copyInfo];
    }
}

- (HFByteSlice *)sliceContainingByteAtIndex:(unsigned long long)offset beginningOffset:(unsigned long long *)actualOffset {
    return [btree entryContainingOffset:offset beginningOffset:actualOffset];
}

/* Given a HFByteArray and a range contained within it, return the first byte slice containing that range, and the range within that slice.  Modifies the given range to reflect what you get when the returned slice is removed. */
static inline HFByteSlice *findInitialSlice(HFBTree *btree, HFRange *inoutArrayRange, HFRange *outRangeWithinSlice) {
    const HFRange arrayRange = *inoutArrayRange;
    const unsigned long long arrayRangeEnd = HFMaxRange(arrayRange);
    
    unsigned long long offsetIntoSlice, lengthFromOffsetIntoSlice;
    
    unsigned long long beginningOffset;
    HFByteSlice *slice = [btree entryContainingOffset:arrayRange.location beginningOffset:&beginningOffset];
    const unsigned long long sliceLength = [slice length];
    HFASSERT(beginningOffset <= arrayRange.location);
    offsetIntoSlice = arrayRange.location - beginningOffset;
    HFASSERT(offsetIntoSlice < sliceLength);
    
    unsigned long long sliceEndInArray = HFSum(sliceLength, beginningOffset);
    if (sliceEndInArray <= arrayRangeEnd) {
        /* Our slice ends before or at the requested range end */
        lengthFromOffsetIntoSlice = sliceLength - offsetIntoSlice;
    }
    else {
        /* Our slice ends after the requested range end */
        unsigned long long overflow = sliceEndInArray - arrayRangeEnd;
        HFASSERT(HFSum(overflow, offsetIntoSlice) < sliceLength);
        lengthFromOffsetIntoSlice = sliceLength - HFSum(overflow, offsetIntoSlice);
    }
    
    /* Set the out range to the input range minus the range consumed by the slice */
    inoutArrayRange->location = MIN(sliceEndInArray, arrayRangeEnd);
    inoutArrayRange->length = arrayRangeEnd - inoutArrayRange->location;
    
    /* Set the out range within the slice to what we computed */
    *outRangeWithinSlice = HFRangeMake(offsetIntoSlice, lengthFromOffsetIntoSlice);
    
    return slice;
}

- (BOOL)fastPathInsertByteSlice:(HFByteSlice *)slice atOffset:(unsigned long long)offset {
    HFASSERT(offset > 0);
    unsigned long long priorSliceOffset;
    HFByteSlice *priorSlice = [btree entryContainingOffset:offset - 1 beginningOffset:&priorSliceOffset];
    HFByteSlice *appendedSlice = [priorSlice byteSliceByAppendingSlice:slice];
    if (appendedSlice) {
        [btree removeEntryAtOffset:priorSliceOffset];
        [btree insertEntry:appendedSlice atOffset:priorSliceOffset];
        return YES;
    }
    else {
        return NO;
    }
}

- (void)insertByteSlice:(HFByteSlice *)slice atOffset:(unsigned long long)offset {
    [self incrementGenerationOrRaiseIfLockedForSelector:_cmd];
    
    if (offset == 0) {
        [btree insertEntry:slice atOffset:0];
    }
    else if (offset == [btree length]) {
        if (! [self fastPathInsertByteSlice:slice atOffset:offset]) {
            [btree insertEntry:slice atOffset:offset];
        }
    }
    else {
        unsigned long long beginningOffset;
        HFByteSlice *overlappingSlice = [btree entryContainingOffset:offset beginningOffset:&beginningOffset];
        if (beginningOffset == offset) {
            if (! [self fastPathInsertByteSlice:slice atOffset:offset]) {
                [btree insertEntry:slice atOffset:offset];
            }
        }
        else {
            HFASSERT(offset > beginningOffset);
            unsigned long long offsetIntoSlice = offset - beginningOffset;
            unsigned long long sliceLength = [overlappingSlice length];
            HFASSERT(sliceLength > offsetIntoSlice);
            HFByteSlice *left = [overlappingSlice subsliceWithRange:HFRangeMake(0, offsetIntoSlice)];
            HFByteSlice *right = [overlappingSlice subsliceWithRange:HFRangeMake(offsetIntoSlice, sliceLength - offsetIntoSlice)];
            [btree removeEntryAtOffset:beginningOffset];
            
            [btree insertEntry:right atOffset:beginningOffset];

            /* Try the fast appending path */
            HFByteSlice *joinedSlice = [left byteSliceByAppendingSlice:slice];
            if (joinedSlice) {
                [btree insertEntry:joinedSlice atOffset:beginningOffset];
            }
            else {   
                [btree insertEntry:slice atOffset:beginningOffset];
                [btree insertEntry:left atOffset:beginningOffset];
            }
        }
    }
}

- (void)deleteBytesInRange:(HFRange)range {
    [self incrementGenerationOrRaiseIfLockedForSelector:_cmd];
    HFRange remainingRange = range;
    
    HFASSERT(HFMaxRange(range) <= [self length]);
    if (range.length == 0) return; //nothing to delete
    
    //fast path for deleting everything
    if (range.location == 0 && range.length == [self length]) {
        [btree removeAllEntries];
        return;
    }
    
    unsigned long long beforeLength = [self length];
    
    unsigned long long rangeStartLocation = range.location;
    HFByteSlice *beforeSlice = nil, *afterSlice = nil;
    while (remainingRange.length > 0) {
        HFRange rangeWithinSlice;
        HFByteSlice *slice = findInitialSlice(btree, &remainingRange, &rangeWithinSlice);
        const unsigned long long sliceLength = [slice length];
        const unsigned long long rangeWithinSliceEnd = HFMaxRange(rangeWithinSlice);
        HFRange lefty = HFRangeMake(0, rangeWithinSlice.location);
        HFRange righty = HFRangeMake(rangeWithinSliceEnd, sliceLength - rangeWithinSliceEnd);
        HFASSERT(lefty.length == 0 || beforeSlice == nil);
        HFASSERT(righty.length == 0 || afterSlice == nil);
        
        unsigned long long beginningOffset = remainingRange.location - HFMaxRange(rangeWithinSlice);
        
        if (lefty.length > 0){
            beforeSlice = [slice subsliceWithRange:lefty];
            rangeStartLocation = beginningOffset;
        }
        if (righty.length > 0) afterSlice = [slice subsliceWithRange:righty];
        
        [btree removeEntryAtOffset:beginningOffset];
        remainingRange.location = beginningOffset;
    }
    if (afterSlice) {
        [self insertByteSlice:afterSlice atOffset:rangeStartLocation];
    }
    if (beforeSlice) {
        [self insertByteSlice:beforeSlice atOffset:rangeStartLocation];
    }    
    
    unsigned long long afterLength = [self length];
    HFASSERT(beforeLength - afterLength == range.length);
}

- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange {
    [self incrementGenerationOrRaiseIfLockedForSelector:_cmd];

    if (lrange.length > 0) {
        [self deleteBytesInRange:lrange];
    }
    if ([slice length] > 0) {
        [self insertByteSlice:slice atOffset:lrange.location];
    }
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    USE(zone);
    HFBTreeByteArray *result = [[[self class] alloc] init];
    [result->btree release];
    result->btree = [btree mutableCopy];
    return result;
}

- (id)subarrayWithRange:(HFRange)range {
    if (range.location == 0 && range.length == [self length]) {
        return [[self mutableCopy] autorelease];
    }
    HFBTreeByteArray *result = [[[[self class] alloc] init] autorelease];
    HFRange remainingRange = range;
    unsigned long long offsetInResult = 0;
    while (remainingRange.length > 0) {
        HFRange rangeWithinSlice;
        HFByteSlice *slice = findInitialSlice(btree, &remainingRange, &rangeWithinSlice);
        HFByteSlice *subslice;
        if (rangeWithinSlice.location == 0 && rangeWithinSlice.length == [slice length]) {
            subslice = slice;
        }
        else {
            subslice = [slice subsliceWithRange:rangeWithinSlice];
        }
        [result insertByteSlice:subslice atOffset:offsetInResult];
        offsetInResult = HFSum(offsetInResult, rangeWithinSlice.length);
    }
    return result;
}

@end
