//
//  HFBTree.m
//  BTree
//
//  Created by peter on 2/6/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "HFBTree.h"
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

#define FIXUP_LENGTHS 0

#define BTREE_BRANCH_ORDER 10
#define BTREE_LEAF_ORDER 10

#define BTREE_ORDER 10
#define BTREE_NODE_MINIMUM_VALUE_COUNT (BTREE_ORDER / 2)

#define BTREE_LEAF_MINIMUM_VALUE_COUNT (BTREE_LEAF_ORDER / 2)

#define BAD_INDEX ((ChildIndex_t)(-1))
typedef unsigned int ChildIndex_t;

/* How deep can our tree get?  128 is huge. */
#define MAX_DEPTH 128
#define BAD_DEPTH ((TreeDepth_t)(-1))
typedef unsigned int TreeDepth_t;

#define TreeEntry NSObject <HFBTreeEntry>
#define HFBTreeLength(x) [(TreeEntry *)(x) length]


@class HFBTreeNode, HFBTreeBranch, HFBTreeLeaf;

static TreeEntry *btree_search(HFBTree *tree, HFBTreeIndex offset, HFBTreeIndex *outBeginningOffset);
static id btree_insert_returning_retained_value_for_parent(HFBTree *tree, TreeEntry *entry, HFBTreeIndex offset);
static BOOL btree_remove(HFBTree *tree, HFBTreeIndex offset);
static void btree_recursive_check_integrity(HFBTree *tree, HFBTreeNode *branchOrLeaf, TreeDepth_t depth, __strong HFBTreeNode **linkHelper);
#if FIXUP_LENGTHS
static HFBTreeIndex btree_recursive_fixup_cached_lengths(HFBTree *tree, HFBTreeNode *branchOrLeaf);
#endif
static HFBTreeIndex btree_recursive_check_integrity_of_cached_lengths(HFBTreeNode *branchOrLeaf);
static BOOL btree_are_cached_lengths_correct(HFBTreeNode *branchOrLeaf, HFBTreeIndex *outLength);
#if FIXUP_LENGTHS
static NSUInteger btree_entry_count(HFBTreeNode *branchOrLeaf);
#endif
static ChildIndex_t count_node_values(HFBTreeNode *node);
static HFBTreeIndex sum_child_lengths(const id *children, const BOOL isLeaf);
static HFBTreeNode *mutable_copy_node(HFBTreeNode *node, TreeDepth_t depth, __strong HFBTreeNode **linkingHelper);

#if NDEBUG
#define VERIFY_LENGTH(a)
#else
#define VERIFY_LENGTH(a) btree_recursive_check_integrity_of_cached_lengths((a))
#endif

#define IS_BRANCH(a) [(a) isKindOfClass:[HFBTreeBranch class]]
#define IS_LEAF(a) [(a) isKindOfClass:[HFBTreeLeaf class]]

#define ASSERT_IS_BRANCH(a) HFASSERT(IS_BRANCH(a))
#define ASSERT_IS_LEAF(a) HFASSERT(IS_LEAF(a))

#define GET_LENGTH(node, parentIsLeaf) ((parentIsLeaf) ? HFBTreeLength(node) : CHECK_CAST((node), HFBTreeNode)->subtreeLength)

#define CHECK_CAST(a, b) ({HFASSERT([(a) isKindOfClass:[b class]]); (b *)(a);})
#define CHECK_CAST_OR_NULL(a, b) ({HFASSERT((a == nil) || [(a) isKindOfClass:[b class]]); (b *)(a);})

#define DEFEAT_INLINE 1

#if DEFEAT_INLINE
#define FORCE_STATIC_INLINE static
#else
#define FORCE_STATIC_INLINE static __inline__ __attribute__((always_inline))
#endif

@interface HFBTreeEnumerator : NSEnumerator {
    HFBTreeLeaf *currentLeaf;
    ChildIndex_t childIndex;
}

- (instancetype)initWithLeaf:(HFBTreeLeaf *)leaf;

@end

@interface HFBTreeNode : NSObject {
    @public
    HFBTreeIndex subtreeLength;
    __weak HFBTreeNode *left;
    __weak HFBTreeNode *right;
    DEFINE_OBJ_ARRAY(id, children);
}

@end

@implementation HFBTreeNode

- (instancetype)init {
    if ((self = [super init]) != nil) {
        children = INIT_OBJ_ARRAY(id, BTREE_ORDER);
    }
    return self;
}

- (void)dealloc {
    FREE_OBJ_ARRAY(children, BTREE_ORDER);
}

- (NSString *)shortDescription {
    return [NSString stringWithFormat:@"<%@: %p (%llu)>", [self class], self, subtreeLength];
}

@end

@interface HFBTreeBranch : HFBTreeNode
@end

@implementation HFBTreeBranch

- (NSString *)description {
    const char *lengthsMatchString = (subtreeLength == sum_child_lengths(children, NO) ? "" : " INCONSISTENT ");
    NSMutableString *s = [NSMutableString stringWithFormat:@"<%@: %p (length: %llu%s) (children: %u) (", [self class], self, subtreeLength, lengthsMatchString, count_node_values(self)];
    NSUInteger i;
    for (i=0; i < BTREE_ORDER; i++) {
        if (children[i] == nil) break;
        [s appendFormat:@"%s%@", (i == 0 ? "" : ", "), [children[i] shortDescription]];
    }
    [s appendString:@")>"];
    return s;
}

@end

@interface HFBTreeLeaf : HFBTreeNode
@end

@implementation HFBTreeLeaf

- (NSString *)description {
    NSMutableString *s = [NSMutableString stringWithFormat:@"<%@: %p (%u) (", [self class], self, count_node_values(self)];
    NSUInteger i;
    for (i=0; i < BTREE_ORDER; i++) {
        if (children[i] == nil) break;
        [s appendFormat:@"%s%@", (i == 0 ? "" : ", "), children[i]];
    }
    [s appendString:@")>"];
    return s;
}

@end

@interface SubtreeInfo_t : NSObject {
    @public
    HFBTreeBranch *branch;
    ChildIndex_t childIndex; //childIndex is the index of the child of branch, not branch's index in its parent
}

@end

@implementation SubtreeInfo_t
@end

@interface LeafInfo_t : NSObject {
    @public
    HFBTreeLeaf *leaf;
    ChildIndex_t entryIndex;
    HFBTreeIndex offsetOfEntryInTree;
}

@end

@implementation LeafInfo_t
@end

@implementation HFBTree
{
    @public
    unsigned int depth;
    HFBTreeNode *root;
}

- (instancetype)init {
    self = [super init];
    depth = BAD_DEPTH;
    root = nil;
    return self;
}

#if HFUNIT_TESTS
- (void)checkIntegrityOfCachedLengths {
    if (root == nil) {
        /* nothing */
    }
    else {
        btree_recursive_check_integrity_of_cached_lengths(root);
    }
}

- (void)checkIntegrityOfBTreeStructure {
    if (depth == BAD_DEPTH) {
        HFASSERT(root == nil);
    }
    else {
        NEW_OBJ_ARRAY(HFBTreeNode*, linkHelper, MAX_DEPTH + 1);
        btree_recursive_check_integrity(self, root, depth, linkHelper);
        FREE_OBJ_ARRAY(linkHelper, MAX_DEPTH + 1);
    }
}
#endif

- (HFBTreeIndex)length {
    if (root == nil) return 0;
    return ((HFBTreeNode *)root)->subtreeLength;
}

- (void)insertEntry:(id)entryObj atOffset:(HFBTreeIndex)offset {
    TreeEntry *entry = (TreeEntry *)entryObj; //avoid a conflicting types warning
    HFASSERT(entry);
    HFASSERT(offset <= [self length]);
    if (! root) {
        HFASSERT([self length] == 0);
        HFASSERT(depth == BAD_DEPTH);
        HFBTreeLeaf *leaf = [[HFBTreeLeaf alloc] init];
        leaf->children[0] = entry;
        leaf->subtreeLength = HFBTreeLength(entry);
        root = leaf;
        depth = 0;
    }
    else {
        HFBTreeNode *newParentValue = btree_insert_returning_retained_value_for_parent(self, entry, offset);
        if (newParentValue) {
            HFBTreeBranch *newRoot = [[HFBTreeBranch alloc] init];
            newRoot->children[0] = root; //transfer our retain
            newRoot->children[1] = newParentValue; //transfer the retain we got from the function
            newRoot->subtreeLength = HFSum(root->subtreeLength, newParentValue->subtreeLength);
            root = newRoot;
            depth++;
            HFASSERT(depth <= MAX_DEPTH);
        }
#if FIXUP_LENGTHS
        HFBTreeIndex outLength = -1;
        if (! btree_are_cached_lengths_correct(root, &outLength)) {
            puts("Fixed up length after insertion");
            btree_recursive_fixup_cached_lengths(self, root);
        }
#endif
    }
}

- (TreeEntry *)entryContainingOffset:(HFBTreeIndex)offset beginningOffset:(HFBTreeIndex *)outBeginningOffset {
    HFASSERT(root != nil);
    return btree_search(self, offset, outBeginningOffset);
}

- (void)removeAllEntries {
    root = nil;
    depth = BAD_DEPTH;
}

- (void)removeEntryAtOffset:(HFBTreeIndex)offset {
    HFASSERT(root != nil);
#if FIXUP_LENGTHS
    const NSUInteger beforeCount = btree_entry_count(root);
#endif
    BOOL deleteRoot = btree_remove(self, offset);
    if (deleteRoot) {
        HFASSERT(count_node_values(root) <= 1);
        id newRoot = root->children[0]; //may be nil!
        root = newRoot;
        depth--;
    }
#if FIXUP_LENGTHS
    const NSUInteger afterCount = btree_entry_count(root);
    if (beforeCount != afterCount + 1) {
        NSLog(@"Bad counts: before %lu, after %lu", beforeCount, afterCount);
    }
    HFBTreeIndex outLength = -1;
    static NSUInteger fixupCount;
    if (! btree_are_cached_lengths_correct(root, &outLength)) {
        fixupCount++;
        printf("Fixed up length after deletion (%lu)\n", (unsigned long)fixupCount);
        btree_recursive_fixup_cached_lengths(self, root);
    }
    else {
        //printf("Length post-deletion was OK! (%lu)\n", fixupCount);
    }
#endif
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    USE(zone);
    HFBTree *result = [[[self class] alloc] init];
    result->depth = depth;
    NEW_OBJ_ARRAY(HFBTreeNode *, linkingHelper, MAX_DEPTH + 1);
    result->root = mutable_copy_node(root, depth, linkingHelper);
    FREE_OBJ_ARRAY(linkingHelper, MAX_DEPTH + 1);
    return result;
}

FORCE_STATIC_INLINE ChildIndex_t count_node_values(HFBTreeNode *node) {
    ChildIndex_t count;
    for (count=0; count < BTREE_LEAF_ORDER; count++) {
        if (node->children[count] == nil) break;
    }
    return count;
}

FORCE_STATIC_INLINE HFBTreeIndex sum_child_lengths(const id *children, const BOOL isLeaf) {
    HFBTreeIndex result = 0;
    for (ChildIndex_t childIndex = 0; childIndex < BTREE_ORDER; childIndex++) {
        id child = children[childIndex];
        if (! child) break;
        HFBTreeIndex childLength = GET_LENGTH(child, isLeaf);
        result = HFSum(result, childLength);
    }
    return result;
}

FORCE_STATIC_INLINE HFBTreeIndex sum_N_child_lengths(const id *children, ChildIndex_t numChildren, const BOOL isLeaf) {
    HFBTreeIndex result = 0;
    for (ChildIndex_t childIndex = 0; childIndex < numChildren; childIndex++) {
        id child = children[childIndex];
        HFASSERT(child != NULL);
        HFBTreeIndex childLength = GET_LENGTH(child, isLeaf);
        result = HFSum(result, childLength);
    }
    return result;
}

FORCE_STATIC_INLINE ChildIndex_t index_containing_offset(HFBTreeNode *node, HFBTreeIndex offset, HFBTreeIndex * restrict outOffset, const BOOL isLeaf) {
    ChildIndex_t childIndex;
    HFBTreeIndex previousSum = 0;
    const id *children = node->children;
    for (childIndex = 0; childIndex < BTREE_ORDER; childIndex++) {
        HFASSERT(children[childIndex] != nil);
        HFBTreeIndex childLength = GET_LENGTH(children[childIndex], isLeaf);
        HFBTreeIndex newSum = HFSum(childLength, previousSum);
        if (newSum > offset) {
            break;
        }
        previousSum = newSum;
    }
    *outOffset = previousSum;
    return childIndex;
}

FORCE_STATIC_INLINE id child_containing_offset(HFBTreeNode *node, HFBTreeIndex offset, HFBTreeIndex * restrict outOffset, const BOOL isLeaf) {
    return node->children[index_containing_offset(node, offset, outOffset, isLeaf)];
}

FORCE_STATIC_INLINE ChildIndex_t index_for_child_at_offset(HFBTreeNode *node, HFBTreeIndex offset, const BOOL isLeaf) {
    ChildIndex_t childIndex;
    HFBTreeIndex previousSum = 0;
    __strong id *const children = node->children;
    for (childIndex = 0; childIndex < BTREE_ORDER; childIndex++) {
        if (previousSum == offset) break;
        HFASSERT(children[childIndex] != nil);
        HFBTreeIndex childLength = GET_LENGTH(children[childIndex], isLeaf);
        previousSum = HFSum(childLength, previousSum);
        HFASSERT(previousSum <= offset);
    }
    HFASSERT(childIndex <= BTREE_ORDER); //note we allow the child index to be one past the end (in which case we are sure to split the node)
    HFASSERT(previousSum == offset); //but we still require the offset to be the sum of all the lengths of this node
    return childIndex;
}

FORCE_STATIC_INLINE ChildIndex_t child_index_for_insertion_at_offset(HFBTreeBranch *branch, HFBTreeIndex insertionOffset, HFBTreeIndex *outPriorCombinedOffset) {
    ChildIndex_t indexForInsertion;
    HFBTreeIndex priorCombinedOffset = 0;
    __strong id *const children = branch->children;
    for (indexForInsertion = 0; indexForInsertion < BTREE_BRANCH_ORDER; indexForInsertion++) {
        if (! children[indexForInsertion]) break;
        HFBTreeNode *childNode = CHECK_CAST(children[indexForInsertion], HFBTreeNode);
        HFBTreeIndex subtreeLength = childNode->subtreeLength;
        HFASSERT(subtreeLength > 0);
        HFBTreeIndex newOffset = HFSum(priorCombinedOffset, subtreeLength);
        if (newOffset >= insertionOffset) {
            break;
        }
        priorCombinedOffset = newOffset;
    }
    *outPriorCombinedOffset = priorCombinedOffset;
    return indexForInsertion;
}

FORCE_STATIC_INLINE ChildIndex_t child_index_for_deletion_at_offset(HFBTreeBranch *branch, HFBTreeIndex deletionOffset, HFBTreeIndex *outPriorCombinedOffset) {
    ChildIndex_t indexForDeletion;
    HFBTreeIndex priorCombinedOffset = 0;
    for (indexForDeletion = 0; indexForDeletion < BTREE_BRANCH_ORDER; indexForDeletion++) {
        HFASSERT(branch->children[indexForDeletion] != nil);
        HFBTreeNode *childNode = CHECK_CAST(branch->children[indexForDeletion], HFBTreeNode);
        HFBTreeIndex subtreeLength = childNode->subtreeLength;
        HFASSERT(subtreeLength > 0);
        HFBTreeIndex newOffset = HFSum(priorCombinedOffset, subtreeLength);
        if (newOffset > deletionOffset) {
            /* Key difference between insertion and deletion: insertion uses >=, while deletion uses > */
            break;
        }
        priorCombinedOffset = newOffset;
    }
    *outPriorCombinedOffset = priorCombinedOffset;
    return indexForDeletion;
}

FORCE_STATIC_INLINE void insert_value_into_array(id value, NSUInteger insertionIndex, __strong id *array, NSUInteger arrayCount) {
    HFASSERT(insertionIndex <= arrayCount);
    HFASSERT(arrayCount > 0);
    NSUInteger pushingIndex = arrayCount - 1;
    while (pushingIndex > insertionIndex) {
        array[pushingIndex] = array[pushingIndex - 1];
        pushingIndex--;
    }
    array[insertionIndex] = value;
}


FORCE_STATIC_INLINE void remove_value_from_array(NSUInteger removalIndex, __strong id *array, NSUInteger arrayCount) {
    HFASSERT(removalIndex < arrayCount);
    HFASSERT(arrayCount > 0);
    HFASSERT(array[removalIndex] != nil);
    array[removalIndex] = nil;
    for (NSUInteger pullingIndex = removalIndex + 1; pullingIndex < arrayCount; pullingIndex++) {
        array[pullingIndex - 1] = array[pullingIndex];
    }
    array[arrayCount - 1] = nil;
}

static void split_array(const restrict id *values, ChildIndex_t valueCount, __strong id *left, __strong id *right, ChildIndex_t leftArraySizeForClearing) {
    const ChildIndex_t midPoint = valueCount/2;
    ChildIndex_t inputIndex = 0, outputIndex = 0;
    while (inputIndex < midPoint) {
        left[outputIndex++] = values[inputIndex++];
    }
    
    /* Clear the remainder of our left array.  Right array does not have to be cleared. */
    HFASSERT(outputIndex <= leftArraySizeForClearing);
    while (outputIndex < leftArraySizeForClearing) {
        left[outputIndex++] = nil;
    }
    
    /* Move the second half of our values into the right array */
    outputIndex = 0;
    while (inputIndex < valueCount) {
        right[outputIndex++] = values[inputIndex++];
    }
}

FORCE_STATIC_INLINE HFBTreeNode *add_child_to_node_possibly_creating_split(HFBTreeNode *node, id value, ChildIndex_t insertionLocation, BOOL isLeaf) {
    ChildIndex_t childCount = count_node_values(node);
    HFASSERT(insertionLocation <= childCount);
    if (childCount < BTREE_ORDER) {
        /* No need to make a split */
        insert_value_into_array(value, insertionLocation, node->children, childCount + 1);
        node->subtreeLength = HFSum(node->subtreeLength, GET_LENGTH(value, isLeaf));
        return nil;
    }
    
    HFASSERT(node->children[BTREE_ORDER - 1] != nil); /* we require that it be full */
    NEW_OBJ_ARRAY(id, allEntries, BTREE_ORDER + 1);
    for (int i = 0; i < BTREE_ORDER; ++i) {
        allEntries[i] = node->children[i];
    }
    allEntries[BTREE_ORDER] = nil;
    
    /* insert_value_into_array applies a retain, so allEntries owns a retain on its values */
    insert_value_into_array(value, insertionLocation, allEntries, BTREE_ORDER + 1);
    HFBTreeNode *newNode = [[[node class] alloc] init];
    
    /* figure out our total length */
    HFBTreeIndex totalLength = HFSum(node->subtreeLength, GET_LENGTH(value, isLeaf));
    
    /* Distribute half our values to the new leaf */
    split_array(allEntries, BTREE_ORDER + 1, node->children, newNode->children, BTREE_ORDER);

    FREE_OBJ_ARRAY(allEntries, BTREE_ORDER + 1);
    
    /* figure out how much is in the new array */
    HFBTreeIndex newNodeLength = sum_child_lengths(newNode->children, isLeaf);
    
    /* update our lengths */
    HFASSERT(newNodeLength < totalLength);
    newNode->subtreeLength = newNodeLength;
    node->subtreeLength = totalLength - newNodeLength;
    
    /* Link it in */
    HFBTreeNode *rightNode = node->right;
    newNode->right = rightNode;
    if (rightNode) rightNode->left = newNode;
    newNode->left = node;
    node->right = newNode;
    return newNode;
}

FORCE_STATIC_INLINE void add_values_to_array(const id * restrict srcValues, NSUInteger amountToCopy, __strong id * targetValues, NSUInteger amountToPush) {
    // a pushed value at index X goes to index X + amountToCopy
    NSUInteger pushIndex = amountToPush;
    while (pushIndex--) {
        targetValues[amountToCopy + pushIndex] = targetValues[pushIndex];
    }
    for (NSUInteger i = 0; i < amountToCopy; i++) {
        targetValues[i] = srcValues[i];
    }
}

FORCE_STATIC_INLINE void remove_values_from_array(__strong id * array, NSUInteger amountToRemove, NSUInteger totalArrayLength) {
    HFASSERT(totalArrayLength >= amountToRemove);
    /* Release existing values */
    NSUInteger i;
    for (i=0; i < amountToRemove; i++) {
        array[i] = nil;
    }
    /* Move remaining values */
    for (i=amountToRemove; i < totalArrayLength; i++) {
        array[i - amountToRemove] = array[i];
    }
    /* Clear the end */
    for (i=totalArrayLength - amountToRemove; i < totalArrayLength; i++) {
        array[i] = nil;
    }
}

FORCE_STATIC_INLINE BOOL rebalance_node_by_distributing_to_neighbors(HFBTreeNode *node, ChildIndex_t childCount, BOOL isLeaf, BOOL * restrict modifiedLeftNeighbor, BOOL *restrict modifiedRightNeighbor) {
    HFASSERT(childCount < BTREE_NODE_MINIMUM_VALUE_COUNT);
    BOOL result = NO;
    HFBTreeNode *leftNeighbor = node->left, *rightNeighbor = node->right;
    const ChildIndex_t leftSpaceAvailable = (leftNeighbor ? BTREE_ORDER - count_node_values(leftNeighbor) : 0);
    const ChildIndex_t rightSpaceAvailable = (rightNeighbor ? BTREE_ORDER - count_node_values(rightNeighbor) : 0);
    if (leftSpaceAvailable + rightSpaceAvailable >= childCount) {
        /* We have enough space to redistribute.  Try to do it in such a way that both neighbors end up with the same number of items. */
        ChildIndex_t itemCountForLeft = 0, itemCountForRight = 0, itemCountRemaining = childCount;
        if (leftSpaceAvailable > rightSpaceAvailable) {
            ChildIndex_t amountForLeft = MIN(leftSpaceAvailable - rightSpaceAvailable, itemCountRemaining);
            itemCountForLeft += amountForLeft;
            itemCountRemaining -= amountForLeft;
        }
        else if (rightSpaceAvailable > leftSpaceAvailable) {
            ChildIndex_t amountForRight = MIN(rightSpaceAvailable - leftSpaceAvailable, itemCountRemaining);
            itemCountForRight += amountForRight;
            itemCountRemaining -= amountForRight;       
        }
        /* Now distribute the remainder (if any) evenly, preferring the remainder to go left, because it is slightly cheaper to append to the left than prepend to the right */
        itemCountForRight += itemCountRemaining / 2;
        itemCountForLeft += itemCountRemaining - (itemCountRemaining / 2);
        HFASSERT(itemCountForLeft <= leftSpaceAvailable);
        HFASSERT(itemCountForRight <= rightSpaceAvailable);
        HFASSERT(itemCountForLeft + itemCountForRight == childCount);
        
        if (itemCountForLeft > 0) {
            /* append to the end */
            HFBTreeIndex additionalLengthForLeft = sum_N_child_lengths(node->children, itemCountForLeft, isLeaf);
            leftNeighbor->subtreeLength = HFSum(leftNeighbor->subtreeLength, additionalLengthForLeft);
            add_values_to_array(node->children, itemCountForLeft, leftNeighbor->children + BTREE_ORDER - leftSpaceAvailable, 0);
            HFASSERT(leftNeighbor->subtreeLength == sum_child_lengths(leftNeighbor->children, isLeaf));
            *modifiedLeftNeighbor = YES;
        }
        if (itemCountForRight > 0) {
            /* append to the beginning */
            HFBTreeIndex additionalLengthForRight = sum_N_child_lengths(node->children + itemCountForLeft, itemCountForRight, isLeaf);
            rightNeighbor->subtreeLength = HFSum(rightNeighbor->subtreeLength, additionalLengthForRight);
            add_values_to_array(node->children + itemCountForLeft, itemCountForRight, rightNeighbor->children, BTREE_ORDER - rightSpaceAvailable);
            HFASSERT(rightNeighbor->subtreeLength == sum_child_lengths(rightNeighbor->children, isLeaf));
            *modifiedRightNeighbor = YES;
        }
        /* Remove ourself from the linked list */
        if (leftNeighbor) {
            leftNeighbor->right = rightNeighbor;
        }
        if (rightNeighbor) {
            rightNeighbor->left = leftNeighbor;
        }
        /* Even though we've essentially orphaned ourself, we need to force ourselves consistent (by making ourselves empty) because our parent still references us, and we don't want to make our parent inconsistent. */
        for (ChildIndex_t childIndex = 0; node->children[childIndex] != nil; childIndex++) {
            node->children[childIndex] = nil;
        }
        node->subtreeLength = 0;
        
        result = YES;
    }
    return result;
}


FORCE_STATIC_INLINE BOOL share_children(HFBTreeNode *node, ChildIndex_t childCount, HFBTreeNode *neighbor, BOOL isRightNeighbor, BOOL isLeaf) {
    ChildIndex_t neighborCount = count_node_values(neighbor);
    ChildIndex_t totalChildren = (childCount + neighborCount);
    BOOL result = NO;
    if (totalChildren <= 2 * BTREE_LEAF_ORDER && totalChildren >= 2 * BTREE_LEAF_MINIMUM_VALUE_COUNT) {
        ChildIndex_t finalMyCount = totalChildren / 2;
        ChildIndex_t finalNeighborCount = totalChildren - finalMyCount;
        HFASSERT(finalNeighborCount < neighborCount);
        HFASSERT(finalMyCount > childCount);
        ChildIndex_t amountToTransfer = finalMyCount - childCount;
        HFBTreeIndex lengthChange;
        if (isRightNeighbor) {
            /* Transfer from left end of right neighbor to this right end of this leaf.  This retains the values. */
            add_values_to_array(neighbor->children, amountToTransfer, node->children + childCount, 0);
            /* Remove from beginning of right neighbor.  This releases them. */
            remove_values_from_array(neighbor->children, amountToTransfer, neighborCount);
            lengthChange = sum_N_child_lengths(node->children + childCount, amountToTransfer, isLeaf);
        }
        else {
            /* Transfer from right end of left neighbor to left end of this leaf */
            add_values_to_array(neighbor->children + neighborCount - amountToTransfer, amountToTransfer, node->children, childCount);
            /* Remove from end of left neighbor */
            remove_values_from_array(neighbor->children + neighborCount - amountToTransfer, amountToTransfer, amountToTransfer);
            lengthChange = sum_N_child_lengths(node->children, amountToTransfer, isLeaf);
        }
        HFASSERT(lengthChange <= neighbor->subtreeLength);
        neighbor->subtreeLength -= lengthChange;
        node->subtreeLength = HFSum(node->subtreeLength, lengthChange);
        HFASSERT(count_node_values(node) == finalMyCount);
        HFASSERT(count_node_values(neighbor) == finalNeighborCount);
        result = YES;
    }
    return result;
}

static BOOL rebalance_node_by_sharing_with_neighbors(HFBTreeNode *node, ChildIndex_t childCount, BOOL isLeaf, BOOL * restrict modifiedLeftNeighbor, BOOL *restrict modifiedRightNeighbor) {
    HFASSERT(childCount < BTREE_LEAF_MINIMUM_VALUE_COUNT);
    BOOL result = NO;
    HFBTreeNode *leftNeighbor = node->left, *rightNeighbor = node->right;
    if (leftNeighbor) {
        result = share_children(node, childCount, leftNeighbor, NO, isLeaf);
        if (result) *modifiedLeftNeighbor = YES;
    }
    if (! result && rightNeighbor) {
        result = share_children(node, childCount, rightNeighbor, YES, isLeaf);
        if (result) *modifiedRightNeighbor = YES;
    }
    return result;
}

/* Return YES if this leaf should be removed after rebalancing.  Other nodes are never removed. */
FORCE_STATIC_INLINE BOOL rebalance_node_after_deletion(HFBTreeNode *node, ChildIndex_t childCount, BOOL isLeaf, BOOL * restrict modifiedLeftNeighbor, BOOL *restrict modifiedRightNeighbor) {
    HFASSERT(childCount < BTREE_LEAF_MINIMUM_VALUE_COUNT);
    /* We may only delete this leaf, and not adjacent leaves.  Thus our rebalancing strategy is:
     If the items to the left or right have sufficient space to hold us, then push our values left or right, and delete this node.
     Otherwise, steal items from the left until we have the same number of items. */
    BOOL deleteNode = NO;
    if (rebalance_node_by_distributing_to_neighbors(node, childCount, isLeaf, modifiedLeftNeighbor, modifiedRightNeighbor)) {
        deleteNode = YES;
        //puts("rebalance_node_by_distributing_to_neighbors");
    }
    else if (rebalance_node_by_sharing_with_neighbors(node, childCount, isLeaf, modifiedLeftNeighbor, modifiedRightNeighbor)) {
        deleteNode = NO;
        //puts("rebalance_node_by_sharing_with_neighbors");
    }
    else {
        [NSException raise:NSInternalInconsistencyException format:@"Unable to rebalance after deleting node %@", node];
    }
    return deleteNode;
}


FORCE_STATIC_INLINE BOOL remove_value_from_node_with_possible_rebalance(HFBTreeNode *node, ChildIndex_t childIndex, BOOL isRootNode, BOOL isLeaf, BOOL * restrict modifiedLeftNeighbor, BOOL *restrict modifiedRightNeighbor) {
    HFASSERT(childIndex < BTREE_ORDER);
    HFASSERT(node != nil);
    HFASSERT(node->children[childIndex] != nil);
    HFBTreeIndex entryLength = GET_LENGTH(node->children[childIndex], isLeaf);
    HFASSERT(entryLength <= node->subtreeLength);
    node->subtreeLength -= entryLength;
    BOOL deleteInputNode = NO;
    
#if ! NDEBUG
    const id savedChild = node->children[childIndex];
    NSUInteger childMultiplicity = 0;
    NSUInteger v;
    for (v = 0; v < BTREE_ORDER; v++) {
        if (node->children[v] == savedChild) childMultiplicity++;
        if (node->children[v] == nil) break;
    }
    
#endif
    
    /* Figure out how many children we have; start at one more than childIndex since we know that childIndex is a valid index */
    ChildIndex_t childCount;
    for (childCount = childIndex + 1; childCount < BTREE_ORDER; childCount++) {
        if (! node->children[childCount]) break;
    }
    
    /* Remove our value at childIndex; this sends it a release message */
    remove_value_from_array(childIndex, node->children, childCount);
    HFASSERT(childCount > 0);
    childCount--;
    
#if ! NDEBUG
    for (v = 0; v < childCount; v++) {
        if (node->children[v] == savedChild) childMultiplicity--;
    }
    HFASSERT(childMultiplicity == 1);
#endif

    if (childCount < BTREE_LEAF_MINIMUM_VALUE_COUNT && ! isRootNode) {
        /* We have too few items; try to rebalance (this will always be possible except from the root node) */
        deleteInputNode = rebalance_node_after_deletion(node, childCount, isLeaf, modifiedLeftNeighbor, modifiedRightNeighbor);
    }
    else {
        //NSLog(@"Deletion from %@ with %u remaining, %s root node, so no need to rebalance\n", node, childCount, isRootNode ? "is" : "is not");
    }
    
    return deleteInputNode;
}

FORCE_STATIC_INLINE void update_node_having_changed_size_of_child(HFBTreeNode *node, BOOL isLeaf) {
    HFBTreeIndex newLength = sum_child_lengths(node->children, isLeaf);
    /* This should only be called if the length actually changes - so assert as such */
    /* I no longer think the above line is true.  It's possible that we can delete a node, and then after a rebalance, we can become the same size we were before. */
    //HFASSERT(node->subtreeLength != newLength);
    node->subtreeLength = newLength;
}

static HFBTreeLeaf *btree_descend(HFBTree *tree, __strong SubtreeInfo_t **outDescentInfo, HFBTreeIndex *insertionOffset, BOOL isForDelete) {
    TreeDepth_t maxDepth = tree->depth;
    HFASSERT(maxDepth != BAD_DEPTH && maxDepth <= MAX_DEPTH);
    id currentBranchOrLeaf = tree->root;
    HFBTreeIndex offsetForSubtree = *insertionOffset;
    for (TreeDepth_t currentDepth = 0; currentDepth < maxDepth; currentDepth++) {
        ASSERT_IS_BRANCH(currentBranchOrLeaf);
        HFBTreeBranch *currentBranch = currentBranchOrLeaf;
        HFBTreeIndex priorCombinedOffset = (HFBTreeIndex)-1;
        ChildIndex_t nextChildIndex = (isForDelete ? child_index_for_deletion_at_offset : child_index_for_insertion_at_offset)(currentBranch, offsetForSubtree, &priorCombinedOffset);
        outDescentInfo[currentDepth]->branch = currentBranch;
        outDescentInfo[currentDepth]->childIndex = nextChildIndex;
        offsetForSubtree -= priorCombinedOffset;
        currentBranchOrLeaf = currentBranch->children[nextChildIndex];
        if (isForDelete) {
            HFBTreeNode *node = currentBranchOrLeaf;
            HFASSERT(node->subtreeLength > offsetForSubtree);
        }
    }
    ASSERT_IS_LEAF(currentBranchOrLeaf);
    *insertionOffset = offsetForSubtree;
    return currentBranchOrLeaf;
}

static LeafInfo_t * btree_find_leaf(HFBTree *tree, HFBTreeIndex offset) {
    TreeDepth_t depth = tree->depth;
    HFBTreeNode *currentNode = tree->root;
    HFBTreeIndex remainingOffset = offset;
    while (depth--) {
        HFBTreeIndex beginningOffsetOfNode;
        currentNode = child_containing_offset(currentNode, remainingOffset, &beginningOffsetOfNode, NO);
        HFASSERT(beginningOffsetOfNode <= remainingOffset);
        remainingOffset = remainingOffset - beginningOffsetOfNode;
    }
    ASSERT_IS_LEAF(currentNode);
    HFBTreeIndex startOffsetOfEntry;
    ChildIndex_t entryIndex = index_containing_offset(currentNode, remainingOffset, &startOffsetOfEntry, YES);
    /* The offset of this entry is the requested offset minus the difference between its starting offset within the leaf and the requested offset within the leaf */
    HFASSERT(remainingOffset >= startOffsetOfEntry);
    HFBTreeIndex offsetIntoEntry = remainingOffset - startOffsetOfEntry;
    HFASSERT(offset >= offsetIntoEntry);
    HFBTreeIndex beginningOffset = offset - offsetIntoEntry;
    LeafInfo_t *info = [[LeafInfo_t alloc] init];
    info->leaf = CHECK_CAST(currentNode, HFBTreeLeaf);
    info->entryIndex = entryIndex;
    info->offsetOfEntryInTree = beginningOffset;
    return info;
}

static TreeEntry *btree_search(HFBTree *tree, HFBTreeIndex offset, HFBTreeIndex *outBeginningOffset) {
    LeafInfo_t *leafInfo = btree_find_leaf(tree, offset);
    *outBeginningOffset = leafInfo->offsetOfEntryInTree;
    return leafInfo->leaf->children[leafInfo->entryIndex];
}

static id btree_insert_returning_retained_value_for_parent(HFBTree *tree, TreeEntry *entry, HFBTreeIndex insertionOffset) {
    NEW_OBJ_ARRAY(SubtreeInfo_t*, descentInfo, MAX_DEPTH);
    for (int i = 0; i < MAX_DEPTH; ++i) {
        descentInfo[i] = [[SubtreeInfo_t alloc] init];
    }
    HFBTreeIndex subtreeOffset = insertionOffset;
    HFBTreeLeaf *leaf = btree_descend(tree, descentInfo, &subtreeOffset, NO);
    ASSERT_IS_LEAF(leaf);
    
    ChildIndex_t insertionLocation = index_for_child_at_offset(leaf, subtreeOffset, YES);
    HFBTreeNode *retainedValueToInsertIntoParentBranch = add_child_to_node_possibly_creating_split(leaf, entry, insertionLocation, YES);
    
    /* Walk up */
    TreeDepth_t depth = tree->depth;
    HFASSERT(depth != BAD_DEPTH);
    HFBTreeIndex entryLength = HFBTreeLength(entry);
    while (depth--) {
        HFBTreeBranch *branch = descentInfo[depth]->branch;
        branch->subtreeLength = HFSum(branch->subtreeLength, entryLength);
        ChildIndex_t childIndex = descentInfo[depth]->childIndex;
        if (retainedValueToInsertIntoParentBranch) {
            HFASSERT(branch->subtreeLength > retainedValueToInsertIntoParentBranch->subtreeLength);
            /* Since we copied some stuff out from under ourselves, subtract its length */
            branch->subtreeLength -= retainedValueToInsertIntoParentBranch->subtreeLength;
            HFBTreeNode *newRetainedValueToInsertIntoParentBranch = add_child_to_node_possibly_creating_split(branch, retainedValueToInsertIntoParentBranch, childIndex + 1, NO);
            retainedValueToInsertIntoParentBranch = newRetainedValueToInsertIntoParentBranch;
        }
    }

    FREE_OBJ_ARRAY(descentInfo, MAX_DEPTH);

    return retainedValueToInsertIntoParentBranch;
}

static BOOL btree_remove(HFBTree *tree, HFBTreeIndex deletionOffset) {
    NEW_OBJ_ARRAY(SubtreeInfo_t*, descentInfo, MAX_DEPTH);
    for (int i = 0; i < MAX_DEPTH; ++i) {
        descentInfo[i] = [[SubtreeInfo_t alloc] init];
    }
    HFBTreeIndex subtreeOffset = deletionOffset;
    HFBTreeLeaf *leaf = btree_descend(tree, descentInfo, &subtreeOffset, YES);
    ASSERT_IS_LEAF(leaf);
    
    HFBTreeIndex previousOffsetSum = 0;
    ChildIndex_t childIndex;
    for (childIndex = 0; childIndex < BTREE_LEAF_ORDER; childIndex++) {
        if (previousOffsetSum == subtreeOffset) break;
        TreeEntry *entry = leaf->children[childIndex];
        HFASSERT(entry != nil); //if it were nil, then the offset is too large
        HFBTreeIndex childLength = HFBTreeLength(entry);
        previousOffsetSum = HFSum(childLength, previousOffsetSum);
    }
    HFASSERT(childIndex < BTREE_LEAF_ORDER);
    HFASSERT(previousOffsetSum == subtreeOffset);
        
    TreeDepth_t depth = tree->depth;
    HFASSERT(depth != BAD_DEPTH);
    BOOL modifiedLeft = NO, modifiedRight = NO;
    BOOL deleteNode = remove_value_from_node_with_possible_rebalance(leaf, childIndex, depth==0/*isRootNode*/, YES, &modifiedLeft, &modifiedRight);
    HFASSERT(btree_are_cached_lengths_correct(leaf, NULL));
    while (depth--) {
        HFBTreeBranch *branch = descentInfo[depth]->branch;
        ChildIndex_t branchChildIndex = descentInfo[depth]->childIndex;
        BOOL leftNeighborNeedsUpdating = modifiedLeft && branchChildIndex == 0; //if our child tweaked its left neighbor, and its left neighbor is not also a child of us, we need to inform its parent (which is our left neighbor)
        BOOL rightNeighborNeedsUpdating = modifiedRight && (branchChildIndex + 1 == BTREE_BRANCH_ORDER || branch->children[branchChildIndex + 1] == NULL); //same goes for right
        if (leftNeighborNeedsUpdating) {
            HFASSERT(branch->left != NULL);
//            NSLog(@"Updating lefty %p", branch->left);
            update_node_having_changed_size_of_child(branch->left, NO);
        }
#if ! NDEBUG
        if (branch->left) HFASSERT(btree_are_cached_lengths_correct(branch->left, NULL));
#endif        
        if (rightNeighborNeedsUpdating) {
            HFASSERT(branch->right != NULL);
//            NSLog(@"Updating righty %p", branch->right);
            update_node_having_changed_size_of_child(branch->right, NO);
        }
#if ! NDEBUG
        if (branch->right) HFASSERT(btree_are_cached_lengths_correct(branch->right, NULL));
#endif        
        update_node_having_changed_size_of_child(branch, NO);
        modifiedLeft = NO;
        modifiedRight = NO;
        if (deleteNode) {
            deleteNode = remove_value_from_node_with_possible_rebalance(branch, branchChildIndex, depth==0/*isRootNode*/, NO, &modifiedLeft, &modifiedRight);
        }
        else {
        //    update_node_having_changed_size_of_child(branch, NO);
            // no need to delete parent nodes, so leave deleteNode as NO
        }
        /* Our parent may have to modify its left or right neighbor if we had to modify our left or right neighbor or if one of our children modified a neighbor that is not also a child of us. */
        modifiedLeft = modifiedLeft || leftNeighborNeedsUpdating;
        modifiedRight = modifiedRight || rightNeighborNeedsUpdating;
    }

    FREE_OBJ_ARRAY(descentInfo, MAX_DEPTH);
    
    if (! deleteNode) {
        /* Delete the root if it has one node and a depth of at least 1, or zero nodes and a depth of 0  */
        deleteNode = (tree->depth >= 1 && tree->root->children[1] == nil) || (tree->depth == 0 && tree->root->children[0] == nil);
    }
    return deleteNode;
}

/* linkingHelper stores the last seen node for each depth.  */
static HFBTreeNode *mutable_copy_node(HFBTreeNode *node, TreeDepth_t depth, __strong HFBTreeNode **linkingHelper) {
    if (node == nil) return nil;
    HFASSERT(depth != BAD_DEPTH);
    Class class = (depth == 0 ? [HFBTreeLeaf class] : [HFBTreeBranch class]);
    HFBTreeNode *result = [[class alloc] init];
    result->subtreeLength = node->subtreeLength;
    
    /* Link us in */
    HFBTreeNode *leftNeighbor = linkingHelper[0];
    if (leftNeighbor != nil) {
        leftNeighbor->right = result;
        result->left = leftNeighbor;
    }
    
    /* Leave us for our future right neighbor to find */
    linkingHelper[0] = result;
    
    HFBTreeIndex index;
    for (index = 0; index < BTREE_ORDER; index++) {
        id child = node->children[index];
        if (! node->children[index]) break;
        if (depth > 0) {
            result->children[index] = mutable_copy_node(child, depth - 1, linkingHelper + 1);
        }
        else {
            result->children[index] = (TreeEntry *)child;
        }
    }
    return result;
}

__attribute__((unused))
static BOOL non_nulls_are_grouped_at_start(const id *ptr, NSUInteger count) {
    BOOL hasSeenNull = NO;
    for (NSUInteger i=0; i < count; i++) {
        BOOL ptrIsNull = (ptr[i] == nil);
        hasSeenNull = hasSeenNull || ptrIsNull;
        if (hasSeenNull && ! ptrIsNull) {
            return NO;
        }
    }
    return YES;
}


__attribute__((used)) static void btree_recursive_check_integrity(HFBTree *tree, HFBTreeNode *branchOrLeaf, TreeDepth_t depth, __strong HFBTreeNode **linkHelper) {
    HFASSERT(linkHelper[0] == branchOrLeaf->left);
    if (linkHelper[0]) HFASSERT(linkHelper[0]->right == branchOrLeaf);
    linkHelper[0] = branchOrLeaf;
    
    if (depth == 0) {
        HFBTreeLeaf *leaf = CHECK_CAST(branchOrLeaf, HFBTreeLeaf);
        HFASSERT(non_nulls_are_grouped_at_start(leaf->children, BTREE_LEAF_ORDER));
    }
    else {
        HFBTreeBranch *branch = CHECK_CAST(branchOrLeaf, HFBTreeBranch);
        HFASSERT(non_nulls_are_grouped_at_start(branch->children, BTREE_BRANCH_ORDER));
        for (ChildIndex_t i = 0; i < BTREE_BRANCH_ORDER; i++) {
            if (! branch->children[i]) break;
            btree_recursive_check_integrity(tree, branch->children[i], depth - 1, linkHelper + 1);
        }
    }
    ChildIndex_t childCount = count_node_values(branchOrLeaf);
    if (depth < tree->depth) { // only the root may have fewer than BTREE_NODE_MINIMUM_VALUE_COUNT
        HFASSERT(childCount >= BTREE_NODE_MINIMUM_VALUE_COUNT);
    }
    HFASSERT(childCount <= BTREE_ORDER);
}

__attribute__((used)) static HFBTreeIndex btree_recursive_check_integrity_of_cached_lengths(HFBTreeNode *branchOrLeaf) {
    HFBTreeIndex result = 0;
    if (IS_LEAF(branchOrLeaf)) {
        HFBTreeLeaf *leaf = CHECK_CAST(branchOrLeaf, HFBTreeLeaf);
        for (ChildIndex_t i = 0; i < BTREE_LEAF_ORDER; i++) {
            if (! leaf->children[i]) break;
            result = HFSum(result, HFBTreeLength(leaf->children[i]));
        }
    }
    else {
        HFBTreeBranch *branch = CHECK_CAST(branchOrLeaf, HFBTreeBranch);
        for (ChildIndex_t i = 0; i < BTREE_BRANCH_ORDER; i++) {
            if (branch->children[i]) {
                HFBTreeIndex subtreeLength = btree_recursive_check_integrity_of_cached_lengths(branch->children[i]);
                result = HFSum(result, subtreeLength);
            }
        }
    }
    HFASSERT(result == branchOrLeaf->subtreeLength);
    return result;
}

static BOOL btree_are_cached_lengths_correct(HFBTreeNode *branchOrLeaf, HFBTreeIndex *outLength) {
    if (! branchOrLeaf) {
        if (outLength) *outLength = 0;
        return YES;
    }
    HFBTreeIndex length = 0;
    if (IS_LEAF(branchOrLeaf)) {
        HFBTreeLeaf *leaf = CHECK_CAST(branchOrLeaf, HFBTreeLeaf);
        for (ChildIndex_t i=0; i < BTREE_LEAF_ORDER; i++) {
            if (! leaf->children[i]) break;
            length = HFSum(length, HFBTreeLength(leaf->children[i]));
        }
    }
    else {
        HFBTreeBranch *branch = CHECK_CAST(branchOrLeaf, HFBTreeBranch);
        for (ChildIndex_t i=0; i < BTREE_BRANCH_ORDER; i++) {
            if (! branch->children[i]) break;
            HFBTreeIndex subLength = (HFBTreeIndex)-1;
            if (! btree_are_cached_lengths_correct(branch->children[i], &subLength)) {
                return NO;
            }
            length = HFSum(length, subLength);
        }
    }
    if (outLength) *outLength = length;
    return length == branchOrLeaf->subtreeLength;
}

#if FIXUP_LENGTHS
static NSUInteger btree_entry_count(HFBTreeNode *branchOrLeaf) {
    NSUInteger result = 0;
    if (branchOrLeaf == nil) {
        // do nothing
    }
    else if (IS_LEAF(branchOrLeaf)) {
        HFBTreeLeaf *leaf = CHECK_CAST(branchOrLeaf, HFBTreeLeaf);
        for (ChildIndex_t i=0; i < BTREE_LEAF_ORDER; i++) {
            if (! leaf->children[i]) break;
            result++;
        }        
    }
    else {
        HFBTreeBranch *branch = CHECK_CAST(branchOrLeaf, HFBTreeBranch);
        for (ChildIndex_t i=0; i < BTREE_LEAF_ORDER; i++) {
            if (! branch->children[i]) break;
            result += btree_entry_count(branch->children[i]);
        }
    }
    return result;
}

static HFBTreeIndex btree_recursive_fixup_cached_lengths(HFBTree *tree, HFBTreeNode *branchOrLeaf) {
    HFBTreeIndex result = 0;
    if (IS_LEAF(branchOrLeaf)) {
        HFBTreeLeaf *leaf = CHECK_CAST(branchOrLeaf, HFBTreeLeaf);
        for (ChildIndex_t i = 0; i < BTREE_LEAF_ORDER; i++) {
            if (! leaf->children[i]) break;
            result = HFSum(result, HFBTreeLength(leaf->children[i]));
        }
    }
    else {
        HFBTreeBranch *branch = CHECK_CAST(branchOrLeaf, HFBTreeBranch);
        for (ChildIndex_t i = 0; i < BTREE_BRANCH_ORDER; i++) {
            if (! branch->children[i]) break;
            btree_recursive_fixup_cached_lengths(tree, branch->children[i]);
            result = HFSum(result, CHECK_CAST(branch->children[i], HFBTreeNode)->subtreeLength);
        }
    }
    branchOrLeaf->subtreeLength = result;
    return result;
}
#endif

FORCE_STATIC_INLINE void btree_apply_function_to_entries(HFBTree *tree, HFBTreeIndex offset, BOOL (*func)(id, HFBTreeIndex, void *), void *userInfo) {
    LeafInfo_t *leafInfo = btree_find_leaf(tree, offset);
    HFBTreeLeaf *leaf = leafInfo->leaf;
    ChildIndex_t entryIndex = leafInfo->entryIndex;
    HFBTreeIndex leafOffset = leafInfo->offsetOfEntryInTree;
    BOOL continueApplying = YES;
    while (leaf != NULL) {
        for (; entryIndex < BTREE_LEAF_ORDER; entryIndex++) {
            TreeEntry *entry = leaf->children[entryIndex];
            if (! entry) break;
            continueApplying = func(entry, leafOffset, userInfo);
            if (! continueApplying) break;
            leafOffset = HFSum(leafOffset, HFBTreeLength(entry));
        }
        if (! continueApplying) break;
        leaf = CHECK_CAST_OR_NULL(leaf->right, HFBTreeLeaf);
        entryIndex = 0;
    }
}

- (NSEnumerator *)entryEnumerator {
    if (! root) return [@[] objectEnumerator];
    HFBTreeLeaf *leaf = btree_find_leaf(self, 0)->leaf;
    return [[HFBTreeEnumerator alloc] initWithLeaf:leaf];
}


static BOOL add_to_array(id entry, HFBTreeIndex offset __attribute__((unused)), void *array) {
    [(__bridge NSMutableArray *)array addObject:entry];
    return YES;
}

- (NSArray *)allEntries {
    if (! root) return @[];
    NSUInteger treeCapacity = 1;
    unsigned int depthIndex = depth;
    while (depthIndex--) treeCapacity *= BTREE_ORDER;
    NSMutableArray *result = [NSMutableArray arrayWithCapacity: treeCapacity/2]; //assume we're half full
    btree_apply_function_to_entries(self, 0, add_to_array, (__bridge void *)result);
    return result;
}

- (void)applyFunction:(BOOL (*)(id entry, HFBTreeIndex offset, void *userInfo))func toEntriesStartingAtOffset:(HFBTreeIndex)offset withUserInfo:(void *)userInfo {
    NSParameterAssert(func != NULL);
    if (! root) return;
    btree_apply_function_to_entries(self, offset, func, userInfo);
}

@end


@implementation HFBTreeEnumerator

- (instancetype)initWithLeaf:(HFBTreeLeaf *)leaf {
    NSParameterAssert(leaf != nil);
    ASSERT_IS_LEAF(leaf);
    currentLeaf = leaf;
    return self;
}

- (id)nextObject {
    if (! currentLeaf) return nil;
    if (childIndex >= BTREE_LEAF_ORDER || currentLeaf->children[childIndex] == nil) {
        childIndex = 0;
        currentLeaf = CHECK_CAST_OR_NULL(currentLeaf->right, HFBTreeLeaf);
    }
    if (currentLeaf == nil) return nil;
    HFASSERT(currentLeaf->children[childIndex] != nil);
    return currentLeaf->children[childIndex++];
}

@end
