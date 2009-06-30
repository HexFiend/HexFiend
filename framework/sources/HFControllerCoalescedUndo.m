//
//  HFControllerCoalescedUndo.m
//  HexFiend_2
//
//  Created by Peter Ammon on 12/30/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFControllerCoalescedUndo.h>
#import <HexFiend/HFFullMemoryByteArray.h>

/* Invariant for this class: actionPoint >= anchorPoint
 
 Action point: the offset at which the user is currently typing.
 Anchor point: the offset at which our deletedData would go when we undo.
 */

@implementation HFControllerCoalescedUndo

- initWithReplacedData:(HFByteArray *)replacedData atAnchorLocation:(unsigned long long)anchor  {
    [super init];
    deletedData = [replacedData retain];
    byteArrayWasCopied = NO;
    anchorPoint = anchor;
    actionPoint = anchor;
    return self;
}

- initWithOverwrittenData:(HFByteArray *)overwrittenData atAnchorLocation:(unsigned long long)anchor {
    [super init];
    HFASSERT([overwrittenData length] > 0);
    deletedData = [overwrittenData retain];
    byteArrayWasCopied = NO;
    anchorPoint = anchor;
    actionPoint = HFSum(anchor, [overwrittenData length]);
    return self;
}

- (void)dealloc {
    [deletedData release];
    [super dealloc];
}

- (BOOL)canCoalesceAppendInRange:(HFRange)range {
    HFASSERT(anchorPoint <= actionPoint);
    return range.location == actionPoint;
}

- (BOOL)canCoalesceDeleteInRange:(HFRange)range {
    HFASSERT(anchorPoint <= actionPoint);
    return HFMaxRange(range) == actionPoint;
}

- (BOOL)canCoalesceOverwriteAtLocation:(unsigned long long)location {
    HFASSERT(anchorPoint <= actionPoint);
    // Allow as a special case overwrites of our last character
    return location == actionPoint || (location < ULLONG_MAX && location + 1 == actionPoint);
}

- (void)_copyByteArray {
    HFASSERT(deletedData != nil);
    HFASSERT(byteArrayWasCopied == NO);
    HFByteArray *oldDeletedData = deletedData;
    deletedData = [deletedData mutableCopy];
    [oldDeletedData release];
    byteArrayWasCopied = YES;
}

/* Overwrites the data in the given range, whose location must be equal to or one less than our action point, with data from that range in the array */
- (void)overwriteDataInRange:(HFRange)overwriteRange withByteArray:(HFByteArray *)array {
    HFASSERT(anchorPoint <= actionPoint);
    HFASSERT((actionPoint == anchorPoint && deletedData == nil) || actionPoint - anchorPoint == [deletedData length]); //when we're overwriting, we can't change lengths
    HFASSERT(overwriteRange.location == actionPoint || overwriteRange.location + 1 == actionPoint);
    HFASSERT(HFMaxRange(overwriteRange) <= [array length]);
    
    /* Figure out how much of the overwritten data isn't already covered by our deletedData array */
    HFByteArray *newlyOverwrittenData = nil;
    if (HFMaxRange(overwriteRange) > actionPoint) {
        newlyOverwrittenData = [array subarrayWithRange:HFRangeMake(actionPoint, HFMaxRange(overwriteRange) - actionPoint)];
    }
    
    if (deletedData == nil) {
        HFASSERT(newlyOverwrittenData != nil);
        deletedData = [newlyOverwrittenData retain];
        byteArrayWasCopied = YES; //since we made a subarray, we own it
    }
    else if (newlyOverwrittenData != nil) { // we may have worked entirely within our previously overwritten data and thus have no newly overwritten data
        if (! byteArrayWasCopied) [self _copyByteArray];
        [deletedData insertByteArray:newlyOverwrittenData inRange:HFRangeMake([deletedData length], 0)];
    }
    actionPoint = HFMaxRange(overwriteRange);
}

- (void)appendDataOfLength:(unsigned long long)length {
    HFASSERT(anchorPoint <= actionPoint);
    actionPoint = HFSum(actionPoint, length);
}

- (void)deleteDataOfLength:(unsigned long long)length withByteArray:(HFByteArray *)array {
    HFASSERT(anchorPoint <= actionPoint);
    REQUIRE_NOT_NULL(array);
    if (length == 0) return;
    
    HFASSERT(length <= actionPoint);
    /* We either deleted data that we have already entered (actionPoint > anchorPoint), or we are deleting "fresh" data, that already existed before the user started this string of typing.  Data that is part of this string of typing is lost forever when deleted, but if subtracting this amount of length would cause us to lose "fresh" data, then figure out how much fresh data we lost, and save that off
    */
    unsigned long long newActionPoint = actionPoint - length;
    if (newActionPoint >= anchorPoint) {
        /* We deleted data that we typed in the current string of keypresses, so we don't need to remember any more data */
        actionPoint = newActionPoint;
    }
    else {
        unsigned long long dataDeletedFromThisTypingString = (actionPoint > anchorPoint ? actionPoint - anchorPoint : 0);
        HFASSERT(dataDeletedFromThisTypingString < length);
        unsigned long long freshDataDeleted = length - dataDeletedFromThisTypingString;
        HFASSERT(freshDataDeleted > 0);
        HFASSERT(freshDataDeleted <= actionPoint);
        HFRange additionalDataToSaveRange = HFRangeMake(newActionPoint, freshDataDeleted);
        HFASSERT(HFRangeIsSubrangeOfRange(additionalDataToSaveRange, HFRangeMake(0, [array length])));
        HFByteArray *additionalDataToSave = [array subarrayWithRange:additionalDataToSaveRange];
        
        /* Instantiate deletedData if it's nil, or copy it if it's not nil and we need to */
        if (deletedData == nil) {
            deletedData = [additionalDataToSave retain];
            byteArrayWasCopied = YES;
        }
        else {
            if (! byteArrayWasCopied) [self _copyByteArray];
            HFASSERT(byteArrayWasCopied == YES);
            [deletedData insertByteArray:additionalDataToSave inRange:HFRangeMake(0, 0)];
        }
        
        /* We just deleted data before us - so push our anchor point back */
        actionPoint = newActionPoint;
        anchorPoint = newActionPoint;
    }
}

- (HFRange)rangeToReplace {
    HFASSERT(anchorPoint <= actionPoint);
    return HFRangeMake(anchorPoint, actionPoint - anchorPoint);
}

- (HFByteArray *)deletedData {
    return deletedData;
}

- (HFControllerCoalescedUndo *)invertWithByteArray:(HFByteArray *)byteArray {
    HFASSERT(anchorPoint <= actionPoint);
    REQUIRE_NOT_NULL(byteArray);
    /* self replaces data within rangeToReplace with deletedData; construct an undoer that replaces {rangeToReplace.location, deletedData.length} with what's currently in rangeToReplace */
    HFRange rangeToReplace = [self rangeToReplace];
    HFByteArray *invertedDeletedData;
    if (rangeToReplace.length == 0) {
        invertedDeletedData = nil;
    }
    else {
        invertedDeletedData = [byteArray subarrayWithRange:rangeToReplace];
    }
    HFControllerCoalescedUndo *result = [[[self class] alloc] initWithReplacedData:invertedDeletedData atAnchorLocation:anchorPoint];
    if (deletedData) [result appendDataOfLength:[deletedData length]];
    return [result autorelease];
}

@end
