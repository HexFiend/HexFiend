//
//  HFBTree.h
//  BTree
//
//  Created by peter on 2/6/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef unsigned long long HFBTreeIndex;

@class HFBTreeNode;

@interface HFBTree : NSObject {
    unsigned int depth;
    HFBTreeNode *root;
}

- (void)insertEntry:(id)entry atOffset:(HFBTreeIndex)offset;
- (id)entryContainingOffset:(HFBTreeIndex)offset beginningOffset:(HFBTreeIndex *)outBeginningOffset;
- (void)removeEntryAtOffset:(HFBTreeIndex)offset;

#if HFTEST_BTREES
- (void)checkIntegrityOfCachedLengths;
- (void)checkIntegrityOfBTreeStructure;
#endif

- (NSEnumerator *)entryEnumerator;

- (HFBTreeIndex)length;

@end

@protocol HFBTreeEntry <NSObject>
- (unsigned long long)length;
@end
