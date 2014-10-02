//
//  HFAnnotatedTree.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Foundation/NSObject.h>

typedef unsigned long long (*HFAnnotatedTreeAnnotaterFunction_t)(id left, id right);


@interface HFAnnotatedTreeNode : NSObject <NSMutableCopying> {
    HFAnnotatedTreeNode *left;
    HFAnnotatedTreeNode *right;
    HFAnnotatedTreeNode *parent;
    uint32_t level;
@public
    unsigned long long annotation;
}

/* Pure virtual method, which must be overridden. */
- (NSComparisonResult)compare:(HFAnnotatedTreeNode *)node;

/* Returns the next in-order node. */
- (id)nextNode;

- (id)leftNode;
- (id)rightNode;
- (id)parentNode;

#if ! NDEBUG
- (void)verifyIntegrity;
- (void)verifyAnnotation:(HFAnnotatedTreeAnnotaterFunction_t)annotater;
#endif


@end


@interface HFAnnotatedTree : NSObject <NSMutableCopying> {
    HFAnnotatedTreeAnnotaterFunction_t annotater;
    HFAnnotatedTreeNode *root;
}

- (instancetype)initWithAnnotater:(HFAnnotatedTreeAnnotaterFunction_t)annotater;
- (void)insertNode:(HFAnnotatedTreeNode *)node;
- (void)removeNode:(HFAnnotatedTreeNode *)node;
- (id)rootNode;
- (id)firstNode;
- (BOOL)isEmpty;

#if ! NDEBUG
- (void)verifyIntegrity;
#endif

@end
