//
//  HFBTree.h
//  HexFiend
//
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef unsigned long long HFBTreeIndex;

@class HFBTreeNode;

@protocol HFBTreeEntry <NSObject>
- (unsigned long long)length;
@end

@interface HFBTree : NSObject <NSMutableCopying, HFBTreeEntry>

- (void)insertEntry:(id)entry atOffset:(HFBTreeIndex)offset;
- (nullable id)entryContainingOffset:(HFBTreeIndex)offset beginningOffset:(HFBTreeIndex *)outBeginningOffset;
- (void)removeEntryAtOffset:(HFBTreeIndex)offset;
- (void)removeAllEntries;

#if HFUNIT_TESTS
- (void)checkIntegrityOfCachedLengths;
- (void)checkIntegrityOfBTreeStructure;
#endif

- (nonnull NSEnumerator *)entryEnumerator;
- (NSArray *)allEntries;

- (HFBTreeIndex)length;

/* Applies the given function to the entry at the given offset, continuing with subsequent entries until the function returns NO.  Do not modify the tree from within this function. */
- (void)applyFunction:(BOOL (*)(id entry, HFBTreeIndex offset, void *_Nullable userInfo))func toEntriesStartingAtOffset:(HFBTreeIndex)offset withUserInfo:(void *_Nullable)userInfo;

@end

NS_ASSUME_NONNULL_END
