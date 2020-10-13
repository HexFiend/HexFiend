//
//  HFAnnotatedTree.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "HFAnnotatedTree.h"
#import <HexFiend/HFFrameworkPrefix.h>
#import <HexFiend/HFAssert.h>

#if NDEBUG
#define VERIFY_INTEGRITY() do { } while (0)
#else
#define VERIFY_INTEGRITY() [self verifyIntegrity]
#endif

/* HFAnnotatedTree is an AA tree.  */

static unsigned long long null_annotater(id left, id right) { USE(left); USE(right); return 0; }
static void skew(HFAnnotatedTreeNode *node, HFAnnotatedTree *tree);
static BOOL split(HFAnnotatedTreeNode *oldparent, HFAnnotatedTree *tree);
static void rebalanceAfterLeafAdd(HFAnnotatedTreeNode *n, HFAnnotatedTree *tree);
static void delete(HFAnnotatedTreeNode *n, HFAnnotatedTree *tree);
#if ! NDEBUG
static void verify_integrity(HFAnnotatedTreeNode *n);
#endif

static HFAnnotatedTreeNode *next_node(HFAnnotatedTreeNode *node);

static void insert(HFAnnotatedTreeNode *root, HFAnnotatedTreeNode *node, HFAnnotatedTree *tree);

static inline HFAnnotatedTreeNode *get_parent(HFAnnotatedTreeNode *node);
static inline HFAnnotatedTreeNode *get_root(HFAnnotatedTree *tree);
static inline HFAnnotatedTreeNode *create_root(void);
static inline HFAnnotatedTreeAnnotaterFunction_t get_annotater(HFAnnotatedTree *tree);

static void reannotate(HFAnnotatedTreeNode *node, HFAnnotatedTree *tree);

static HFAnnotatedTreeNode *first_node(HFAnnotatedTreeNode *node);

static HFAnnotatedTreeNode *left_child(HFAnnotatedTreeNode *node);
static HFAnnotatedTreeNode *right_child(HFAnnotatedTreeNode *node);

@implementation HFAnnotatedTree

- (instancetype)initWithAnnotater:(HFAnnotatedTreeAnnotaterFunction_t)annot {
    self = [super init];
    annotater = annot ? annot : null_annotater;    
    /* root is always an HFAnnotatedTreeNode with a left child but no right child */
    root = create_root();
    return self;
}

- (id)rootNode {
    return root;
}

- (id)firstNode {
    return first_node(root);
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    HFAnnotatedTree *copied = [[[self class] alloc] init];
    copied->annotater = annotater;
    copied->root = [root mutableCopyWithZone:zone];
    return copied;
}

- (BOOL)isEmpty {
    /* We're empty if our root has no children. */
    return left_child(root) == nil && right_child(root) == nil;
}

- (void)insertNode:(HFAnnotatedTreeNode *)node {
    HFASSERT(node != nil);
    HFASSERT(get_parent(node) == nil);    
    /* Insert into the root */
    insert(root, node, self);
    VERIFY_INTEGRITY();
}

- (void)removeNode:(HFAnnotatedTreeNode *)node {
    HFASSERT(node != nil);
    HFASSERT(get_parent(node) != nil);
    delete(node, self);
    VERIFY_INTEGRITY();
}

#if ! NDEBUG
- (void)verifyIntegrity {
    [root verifyIntegrity];
    [root verifyAnnotation:annotater];
}
#endif

static HFAnnotatedTreeNode *get_root(HFAnnotatedTree *tree) {
    return tree->root;
}

static HFAnnotatedTreeAnnotaterFunction_t get_annotater(HFAnnotatedTree *tree) {
    return tree->annotater;
}

@end

@implementation HFAnnotatedTreeNode

- (NSComparisonResult)compare:(HFAnnotatedTreeNode *)node {
    USE(node);
    UNIMPLEMENTED();
}

- (id)nextNode {
    return next_node(self);
}

- (id)leftNode { return left; }
- (id)rightNode { return right; }
- (id)parentNode { return parent; }

- (id)mutableCopyWithZone:(NSZone *)zone {
    HFAnnotatedTreeNode *copied = [[[self class] alloc] init];
    if (left) {
        copied->left = [left mutableCopyWithZone:zone];
        copied->left->parent = copied;
    }
    if (right) {
        copied->right = [right mutableCopyWithZone:zone];
        copied->right->parent = copied;
    }
    copied->level = level;
    copied->annotation = annotation;
    return copied;
}

static HFAnnotatedTreeNode *left_child(HFAnnotatedTreeNode *node) {
    return node->left;
}

static HFAnnotatedTreeNode *right_child(HFAnnotatedTreeNode *node) {
    return node->right;    
}


static HFAnnotatedTreeNode *create_root(void) {
    HFAnnotatedTreeNode *result = [[HFAnnotatedTreeNode alloc] init];
    result->level = UINT_MAX; //the root has a huge level
    return result;
}

static void reannotate(HFAnnotatedTreeNode *node, HFAnnotatedTree *tree) {
    HFASSERT(node != nil);
    HFASSERT(tree != nil);
    const HFAnnotatedTreeAnnotaterFunction_t annotater = get_annotater(tree);
    node->annotation = annotater(node->left, node->right);
}


static void insert(HFAnnotatedTreeNode *root, HFAnnotatedTreeNode *node, HFAnnotatedTree *tree) {
    /* Insert node at the proper place in the tree.  root is the root node, and we always insert to the left of root */
    BOOL left = YES;
    HFAnnotatedTreeNode *parentNode = root, *currentChild;
    /* Descend the tree until we find where to insert */
    while ((currentChild = (left ? parentNode->left : parentNode->right)) != nil) {
        parentNode = currentChild;
        left = ([parentNode compare:node] >= 0); //if parentNode is larger than the child, then the child goes to the left of node
    }
    
    /* Now insert, potentially unbalancing the tree */
    if (left) {
        parentNode->left = node;
    }
    else {
        parentNode->right = node;
    }
    
    /* Tell our node about its new parent */
    node->parent = parentNode;
    
    /* Rebalance and update annotations */
    rebalanceAfterLeafAdd(node, tree);
}

static void skew(HFAnnotatedTreeNode *oldparent, HFAnnotatedTree *tree) {
    HFAnnotatedTreeNode *newp = oldparent->left;
    
    if (oldparent->parent->left == oldparent) {
        /* oldparent is the left child of its parent.  Substitute in our left child. */
        oldparent->parent->left = newp;
    }
    else {
        /* oldparent is the right child of its parent.  Substitute in our left child. */
        oldparent->parent->right = newp;
    }
    
    /* Tell the child about its new parent */
    newp->parent = oldparent->parent;
    
    /* Adopt its right child as our left child, and tell it about its new parent */
    oldparent->left = newp->right;
    if (oldparent->left) oldparent->left->parent = oldparent;
    
    /* We are now the right child of the new parent */
    newp->right = oldparent;
    oldparent->parent = newp;
    
    /* If we're now a leaf, our level is 1.  Otherwise, it's one more than the level of our child. */
    oldparent->level = oldparent->left ? oldparent->left->level + 1 : 1;
    
    /* oldparent and newp both had their children changed, so need to be reannotated */
    reannotate(oldparent, tree);
    reannotate(newp, tree);
}

static BOOL split(HFAnnotatedTreeNode *oldparent, HFAnnotatedTree *tree) {
    HFAnnotatedTreeNode *newp = oldparent->right;
    if (newp && newp->right && newp->right->level == oldparent->level) { 
        if (oldparent->parent->left == oldparent) oldparent->parent->left = newp;
        else oldparent->parent->right = newp;
        newp->parent = oldparent->parent;
        oldparent->parent = newp;
        
        oldparent->right = newp->left;
        if (oldparent->right) oldparent->right->parent = oldparent;
        newp->left = oldparent;
        newp->level = oldparent->level + 1;
        
        /* oldparent and newp both had their children changed, so need to be reannotated */
        reannotate(oldparent, tree);
        reannotate(newp, tree);
        
        return YES;
    }
    return NO;
}

static void rebalanceAfterLeafAdd(HFAnnotatedTreeNode *node, HFAnnotatedTree *tree) { // n is a node that has just been inserted and is now a leaf node.
    node->level = 1;
    node->left = nil;
    node->right = nil;
    reannotate(node, tree);
    HFAnnotatedTreeNode * const root = get_root(tree);
    HFAnnotatedTreeNode *probe;
    for (probe = node->parent; probe != root; probe = probe->parent) {
        reannotate(probe, tree);
        // At this point probe->parent->level == probe->level
        if (probe->level != (probe->left ? probe->left->level + 1 : 1)) {
            // At this point the tree is correct, except (AA2) for n->parent
            skew(probe, tree);
            // We handle it (a left add) by changing it into a right add using Skew
            // If the original add was to the left side of a node that is on the
            // right side of a horisontal link, probe now points to the rights side
            // of the second horisontal link, which is correct.
            
            // However if the original add was to the left of node with a horizontal
            // link, we must get to the right side of the second link.
            if (!probe->right || probe->level != probe->right->level) probe = probe->parent;
        }
        if (! split(probe->parent, tree)) break;
    }
    while (probe) {
        reannotate(probe, tree);
        probe = probe->parent;
    }
}

static void delete(HFAnnotatedTreeNode *n, HFAnnotatedTree *tree) { // If n is not a leaf, we first swap it out with the leaf node that just
    // precedes it.
    HFAnnotatedTreeNode *leaf = n, *tmp;
    
    if (n->left) {
        /* Descend the right subtree of our left child, to get the closest predecessor */
        for (leaf = n->left; leaf->right; leaf = leaf->right) {}
        // When we stop, leaf has no 'right' child so it cannot have a left one
    }
    else if (n->right) {
        /* We have no children that precede us, but we have a child after us, so use our closest successor */
        leaf = n->right;
    }
    
    /* tmp is either the parent who loses the child, or tmp is our right subtree.  Either way, we will have to reduce its level. */
    tmp = leaf->parent == n ? leaf : leaf->parent;
    
    /* Tell leaf's parent to forget about leaf */
    if (leaf->parent->left == leaf) {
        leaf->parent->left = nil;
    }
    else {
        leaf->parent->right = nil;
    }
    reannotate(leaf->parent, tree);
    
    if (n != leaf) {
        /* Replace ourself as our parent's child with leaf */
        if (n->parent->left == n) n->parent->left = leaf;
        else n->parent->right = leaf;
        
        /* Leaf's parent is our parent */
        leaf->parent = n->parent;
        
        /* Our left and right children are now leaf's left and right children */
        if (n->left) n->left->parent = leaf;
        leaf->left = n->left;
        if (n->right) n->right->parent = leaf;
        leaf->right = n->right;
        
        /* Leaf's level is our level */
        leaf->level = n->level;
    }
    /* Since we adopted n's children, transferring the retain, tell n to forget about them so it doesn't release them */
    n->left = nil;
    n->right = nil;
    
    // free (n);
    
    HFAnnotatedTreeNode * const root = get_root(tree);
    while (tmp != root) {
        reannotate(tmp, tree);
        // One of tmp's childern had its level reduced
        if (tmp->level > (tmp->left ? tmp->left->level + 1 : 1)) { // AA2 failed
            tmp->level--;
            if (split(tmp, tree)) {
                if (split(tmp, tree)) skew(tmp->parent->parent, tree);
                break;
            }
            tmp = tmp->parent;
        }
        else if (tmp->level <= (tmp->right ? tmp->right->level + 1 : 1)){
            break;
        }
        else { // AA3 failed
            skew(tmp, tree);
            //if (tmp->right) tmp->right->level = tmp->right->left ? tmp->right->left->level + 1 : 1;
            if (tmp->level > tmp->parent->level) {
                skew(tmp, tree);
                split(tmp->parent->parent, tree);
                break;
            }
            tmp = tmp->parent->parent;
        }
    }
    while (tmp) {
        reannotate(tmp, tree);
        tmp = tmp->parent;
    }
}

static HFAnnotatedTreeNode *next_node(HFAnnotatedTreeNode *node) {
    /* Return the next in-order node */
    HFAnnotatedTreeNode *result;
    if (node->right) {
        /* We have a right child, which is after us.  Descend its left subtree. */
        result = node->right;
        while (result->left) {
            result = result->left;
        }
    }
    else {
        /* We have no right child.  If we are our parent's left child, then our parent is after us.  Otherwise,  we're our parent's right child and it was before us, so ascend while we're the parent's right child. */
        result = node;
        while (result->parent && result->parent->right == result) {
            result = result->parent;
        }
        /* Now result is the left child of the parent (or has NULL parents), so its parent is the next node */
        result = result->parent;
    }
    /* Don't return the root */
    if (result != nil && result->parent == nil) {
        result = next_node(result);
    }
    return result;
}

static HFAnnotatedTreeNode *first_node(HFAnnotatedTreeNode *node) {
    /* Return the first node */ 
    HFAnnotatedTreeNode *result = nil, *cursor = node->left;
    while (cursor) {
        /* Descend the left subtree */
        result = cursor;
        cursor = cursor->left;
    }
    return result;
}

static HFAnnotatedTreeNode *get_parent(HFAnnotatedTreeNode *node) {
    HFASSERT(node != nil);
    return node->parent;
}

#if ! NDEBUG
static void verify_integrity(HFAnnotatedTreeNode *n) {
    HFASSERT(!n->left || n->left->parent == n);
    HFASSERT(!n->right || n->right->parent == n);
    HFASSERT(!next_node(n) || [n compare:next_node(n)] <= 0);
    HFASSERT(!n->parent || n->parent->level >= n->level);
    if (n->parent == nil) {
        /* root node */
        HFASSERT(n->level == UINT_MAX);
    }
    else {
        /* non-root node */
        HFASSERT(n->level == (n->left == nil ? 1 : n->left->level + 1));
        HFASSERT((n->level <= 1) || (n->right && n->level - n->right->level <= 1));
    }
    HFASSERT(!n->parent || !n->parent->parent ||
             n->parent->parent->level > n->level);
}

- (void)verifyIntegrity {
    [left verifyIntegrity];
    [right verifyIntegrity];
    verify_integrity(self);
}

- (void)verifyAnnotation:(HFAnnotatedTreeAnnotaterFunction_t)annotater {
    [left verifyAnnotation:annotater];
    [right verifyAnnotation:annotater];
    unsigned long long expectedAnnotation = annotater(left, right);
    HFASSERT(annotation == expectedAnnotation);
}
#endif

@end
