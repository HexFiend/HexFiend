//
//  HFBTree.h
//  HexFiend
//
//

#import <Foundation/Foundation.h>

typedef unsigned long long HFBTreeIndex;

@class HFBTreeNode;

@protocol HFBTreeEntry <NSObject>
- (unsigned long long)length;
@end

@interface HFBTree : NSObject <NSMutableCopying, HFBTreeEntry> {
    unsigned int depth;
    HFBTreeNode *root;
}

- (void)insertEntry:(id)entry atOffset:(HFBTreeIndex)offset;
- (id)entryContainingOffset:(HFBTreeIndex)offset beginningOffset:(HFBTreeIndex *)outBeginningOffset;
- (void)removeEntryAtOffset:(HFBTreeIndex)offset;
- (void)removeAllEntries;

#if HFUNIT_TESTS
- (void)checkIntegrityOfCachedLengths;
- (void)checkIntegrityOfBTreeStructure;
#endif

- (NSEnumerator *)entryEnumerator;
- (NSArray *)allEntries;

- (HFBTreeIndex)length;

/* Applies the given function to the entry at the given offset, continuing with subsequent entries until the function returns NO.  Do not modify the tree from within this function. */
- (void)applyFunction:(BOOL (*)(id entry, HFBTreeIndex offset, void *userInfo))func toEntriesStartingAtOffset:(HFBTreeIndex)offset withUserInfo:(void *)userInfo;

@end
