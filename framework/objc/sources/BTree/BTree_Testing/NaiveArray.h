//
//  NaiveArray.h
//  BTree
//
//  Created by peter on 2/6/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HFBTree.h"

@class TreeEntry;

@interface NaiveArray : NSObject {
    NSMutableArray *entries;
}

- (void)insertEntry:(TreeEntry *)entry atOffset:(HFBTreeIndex)offset;
- (TreeEntry *)entryContainingOffset:(HFBTreeIndex)offset beginningOffset:(HFBTreeIndex *)outBeginningOffset;
- (void)removeEntryAtOffset:(HFBTreeIndex)offset;

- (HFBTreeIndex)randomOffset;
- (HFBTreeIndex)randomOffsetExcludingLast;
- (NSEnumerator *)entryEnumerator;

- (HFBTreeIndex)length;


@end
