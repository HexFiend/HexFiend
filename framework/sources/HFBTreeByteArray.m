//
//  HFBTreeByteArray.m
//  HexFiend_2
//
//  Created by peter on 4/28/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFBTree.h>

@implementation HFBTreeByteArray

- init {
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
    return [NSString stringWithFormat:@"%@ <%@>", [super description], [btree description]];
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
    HFASESRT(sliceLength > 0);
    unsigned long long offsetIntoSlice = info->startingOffset - offset;
    HFASSERT(offsetIntoSlice < sliceLength);
    NSUInteger amountToCopy = ll2l(MIN(userInfo->remainingLength, sliceLength - offsetIntoSlice));
    HFRange srcRange = HFRangeMake(info->startingOffset - offset, amountToCopy);
    [slice copyBytes:info->dst range:srcRange];
    info->dst += amountToCopy;
    info->startingOffset = HFSum(info->startingOffset, amountToCopy);
    info->remainingLength -= amountToCopy;
    return info->remainingLength > 0;
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax);
    struct HFBTreeByteArrayCopyInfo_t copyInfo = {.dst = dst, .remainingLength = ll2l(range.length), .initialOffset = range.location};
    [btree applyFunction:copy_bytes toEntriesStartingAtOffset:range.location withUserInfo:userInfo];
}

- (void)deleteBytesInRange:(const HFRange)range {
    HFRange remainingRange = range;
    HFByteSlice *beforeSlice = nil, *afterSlice = nil;
    while (remainingRange.length > 0) {
        HFBTreeIndex beginningOffset;
        HFByteSlice *slice = [btree entryContainingOffset:remainingRange.location beginningOffset:&beginningOffset];
        const unsigned long long sliceLength = [slice length];

        /* Figure out how much of the beginning we need to preserve.  We should only need to preserve the beginning of at most one slice. */
        HFASSERT(beginningOffset <= remainingRange.location);
        unsigned long long offsetIntoSlice = remainingRange.location - beginningOffset;
        HFASSERT(offsetIntoSlice < sliceLength);
        if (offsetIntoSlice > 0) {
            HFASSERT(beforeSlice == nil);
            beforeSlice = [slice subsliceWithRange:HFRangeMake(0, remainingRange.location - beginningOffset)];
        }

        /* Figure out how much of the end we need to preserve.  We should only need to preserve the end of at most one slice. */
        unsigned long long rangeEnd = HFMaxRange(remainingRange);
        unsigned long long sliceEnd = HFSum(beginningOffset, sliceLength);
        if (sliceEnd > rangeEnd) {
            HFASSERT(afterSlice == nil);
            unsigned long long remainderLength = sliceEnd - rangeEnd;
            HFASSERT(remainderLength < sliceLength);
            afterSlice = [slice subsliceWithRange:HFRangeMake(sliceLength - remainderLength, remainderLength)];
        }
        
        [btree removeEntryAtOffset:beginningOffset];
        remainingRange.location = HFSum(remainingRange.location, sliceLength - offsetIntoSlice);
        
    }
}

@end
