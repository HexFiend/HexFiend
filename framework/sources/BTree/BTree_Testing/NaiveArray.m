//
//  NaiveArray.m
//  BTree
//
//  Created by peter on 2/6/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "NaiveArray.h"
#import "TreeEntry.h"

#define HFBTreeLength_Fast(a) (((TreeEntry *)(a))->length)

//#define HFBTreeLength_Fast(a) HFBTreeLength(a)


@implementation NaiveArray

- init {
    [super init];
    entries = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc {
    [entries release];
    [super dealloc];
}

- (void)insertEntry:(TreeEntry *)entry atOffset:(HFBTreeIndex)offset {
    NSUInteger index = 0;
    for (TreeEntry *subentry in entries) {
        if (offset == 0) break;
        HFASSERT(HFBTreeLength_Fast(subentry) <= offset);
        index++;
        offset -= HFBTreeLength_Fast(subentry);
    }
    HFASSERT(offset == 0);
    [entries insertObject:entry atIndex:index];
}

- (HFBTreeIndex)offsetForEntryAtIndex:(NSUInteger)index {
    NSUInteger i = 0;
    HFBTreeIndex offset = 0;
    for (TreeEntry *entry in entries) {
        if (i++ == index) break;
        offset += HFBTreeLength_Fast(entry);
    }
    return offset;
}

- (HFBTreeIndex)randomOffset {
    return [self offsetForEntryAtIndex:random() % (1 + [entries count])];
}

- (HFBTreeIndex)randomOffsetExcludingLast {
    HFASSERT([entries count] > 0);
    return [self offsetForEntryAtIndex:random() % [entries count]];
}

- (TreeEntry *)entryContainingOffset:(HFBTreeIndex)offset beginningOffset:(HFBTreeIndex *)outBeginningOffset {
    TreeEntry *entry = nil;
    HFBTreeIndex remainingOffset = offset;
    for (entry in entries) {
        HFBTreeIndex entryLength = HFBTreeLength_Fast(entry);
        if (remainingOffset < entryLength) break;
        remainingOffset -= entryLength;
    }
    HFASSERT(entry != nil);
    if (outBeginningOffset) *outBeginningOffset = offset - remainingOffset;
    return entry;
}

- (void)removeEntryAtOffset:(HFBTreeIndex)offset {
    HFASSERT([entries count] > 0);
    HFBTreeIndex remainingOffset = offset;
    NSUInteger index = 0;
    for (TreeEntry *entry in entries) {
        if (remainingOffset == 0) break;
        HFBTreeIndex entryLength = HFBTreeLength_Fast(entry);
        HFASSERT(remainingOffset >= entryLength);
        remainingOffset -= entryLength;
        index++;
    }
    HFASSERT(remainingOffset == 0);
    HFASSERT(index < [entries count]);
    [entries removeObjectAtIndex:index];
}

- (NSEnumerator *)entryEnumerator {
    return [entries objectEnumerator];
}

- (HFBTreeIndex)length {
    HFBTreeIndex result = 0;
    for (TreeEntry *entry in entries) {
        result = HFSum(result, HFBTreeLength_Fast(entry));
    }
    return result;
}

@end
