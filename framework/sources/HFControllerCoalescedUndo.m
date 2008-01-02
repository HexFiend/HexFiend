//
//  HFControllerCoalescedUndo.m
//  HexFiend_2
//
//  Created by Peter Ammon on 12/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFControllerCoalescedUndo.h>
#import <HexFiend/HFFullMemoryByteArray.h>

/* Invariant for this class: actionPoint >= anchorPoint */

@implementation HFControllerCoalescedUndo

- initWithReplacedData:(HFByteArray *)replacedData atAnchorLocation:(unsigned long long)anchor  {
    [super init];
    deletedData = [replacedData retain];
    byteArrayWasCopied = NO;
    anchorPoint = anchor;
    actionPoint = anchor;
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

- (void)appendDataOfLength:(unsigned long long)length {
    HFASSERT(anchorPoint <= actionPoint);
    actionPoint = HFSum(actionPoint, length);
}

- (void)_copyByteArray {
    HFASSERT(deletedData != nil);
    HFASSERT(byteArrayWasCopied == NO);
    HFByteArray *oldDeletedData = deletedData;
    deletedData = [deletedData mutableCopy];
    [oldDeletedData release];
    byteArrayWasCopied = YES;
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
