//
//  HFByteRangeAttributeArray.m
//  HexFiend_2
//
//  Created by Peter Ammon on 8/24/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteRangeAttributeArray.h>
#import <HexFiend/HFAnnotatedTree.h>

/* This is a very naive class and it should use a better data structure than an array. */

@interface HFByteRangeAttributeRun : NSObject {
@public
    NSString *name;
    HFRange range;
}

- (id)initWithName:(NSString *)nameParameter range:(HFRange)rangeParameter;

@end

@implementation HFByteRangeAttributeRun

- (id)initWithName:(NSString *)nameParameter range:(HFRange)rangeParameter {
    HFASSERT(nameParameter != nil);
    [super init];
    name = [nameParameter copy];
    range = rangeParameter;
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@ {%llu, %llu}]", name, range.location, range.length];
}

- (void)dealloc {
    [name release];
    [super dealloc];
}

- (NSComparisonResult)compare:(HFByteRangeAttributeRun *)run {
    return (range.location > run->range.location) - (run->range.location > range.location);
}

@end

@implementation HFByteRangeAttributeArray

- (id)init {
    if ([self class] == [HFByteRangeAttributeArray class]) {
	[self release];
	return [[HFAnnotatedTreeByteRangeAttributeArray alloc] init];
    }
    return [super init];
}

- (id)mutableCopyWithZone:(NSZone *)zone { UNIMPLEMENTED(); }
- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length { UNIMPLEMENTED(); }
- (NSSet *)attributesInRange:(HFRange)range { UNIMPLEMENTED(); }
- (HFRange)rangeOfAttribute:(NSString *)attribute { UNIMPLEMENTED_VOID(); return HFRangeMake(0, 0); }
- (void)addAttribute:(NSString *)attributeName range:(HFRange)range { UNIMPLEMENTED_VOID(); }
- (void)removeAttribute:(NSString *)attributeName range:(HFRange)range { UNIMPLEMENTED_VOID(); }
- (void)removeAttribute:(NSString *)attributeName { UNIMPLEMENTED_VOID(); }
- (void)removeAttributes:(NSSet *)attributeName { UNIMPLEMENTED_VOID(); }
- (BOOL)isEmpty { UNIMPLEMENTED(); }
- (NSEnumerator *)attributeEnumerator { UNIMPLEMENTED(); }
- (void)transferAttributesFromAttributeArray:(HFByteRangeAttributeArray *)array range:(HFRange)range baseOffset:(unsigned long long)baseOffset { UNIMPLEMENTED_VOID(); }

- (BOOL)isEqual:(HFByteRangeAttributeArray *)array {
    if (! [array isKindOfClass:[HFByteRangeAttributeArray class]]) return NO;
    HFRange remaining = HFRangeMake(0, ULLONG_MAX);
    const BOOL log = YES;
    BOOL result = YES;
    NSUInteger amt = 0;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    while (remaining.length > 0) {
	unsigned long long applied1, applied2;
	NSSet *atts1 = [self attributesAtIndex:remaining.location length:&applied1];
	NSSet *atts2 = [array attributesAtIndex:remaining.location length:&applied2];
	if (applied1 != applied2) {
	    if (log) NSLog(@"Failed %d", __LINE__);
	    [array attributesAtIndex:remaining.location length:&applied2];
	    result = NO;
	    break;
	}
	if (result && !atts1 != !atts2) {
	    if (log) NSLog(@"Failed %d", __LINE__);
	    result = NO;
	    break;
	}
	if (! (atts1 == atts2 || [atts1 isEqual:atts2])) {
	    if (log) NSLog(@"Failed %d", __LINE__);
	    result = NO;
	    break;
	}
	HFASSERT(applied1 <= remaining.length);
	remaining.length -= applied1;
	remaining.location += applied1;
	amt++;
	[pool release];
	pool = [[NSAutoreleasePool alloc] init];
    }
    [pool release];
    return result;
}

@end

@implementation HFNaiveByteRangeAttributeArray

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p %@>", [self class], self, attributeRuns];
}

- (id)init {
    [super init];
    attributeRuns = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc {
    [attributeRuns release];
    [super dealloc];
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    HFNaiveByteRangeAttributeArray *result = [[[self class] allocWithZone:zone] init];
    [result->attributeRuns addObjectsFromArray:attributeRuns];
    return result;
}

- (BOOL)isEmpty {
    return [attributeRuns count] == 0;
}

- (void)addAttribute:(NSString *)attributeName range:(HFRange)range {
    HFASSERT(attributeName != nil);
    HFByteRangeAttributeRun *run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:range];
    [attributeRuns addObject:run];
    [run release];
}

-  (void)removeAttribute:(NSString *)attributeName range:(HFRange)range {
    HFASSERT(attributeName != nil);
    NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
    NSUInteger index = 0, max = [attributeRuns count];
    for (index = 0; index < max; index++) {
        HFByteRangeAttributeRun *run = [attributeRuns objectAtIndex:index];
        if ([attributeName isEqualToString:run->name] && HFIntersectsRange(range, run->range)) {
            HFRange leftRemainder = {0, 0}, rightRemainder = {0, 0};
            if (run->range.location < range.location) {
                leftRemainder = HFRangeMake(run->range.location, range.location - run->range.location);
            }
            if (HFRangeExtendsPastRange(run->range, range)) {
                rightRemainder.location = HFMaxRange(range);
                rightRemainder.length = HFMaxRange(run->range) - rightRemainder.location;
            }
            if (leftRemainder.length || rightRemainder.length) {
                /* Replacing existing run with remainder */
                run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:(leftRemainder.length ? leftRemainder : rightRemainder)];
                [attributeRuns replaceObjectAtIndex:index withObject:run];
                [run release];
            }
            if (leftRemainder.length && rightRemainder.length) {
                /* We have two to insert.  The second must be the right remainder, because we inserted the left up above. */
                index += 1;
                max += 1;
                run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:rightRemainder];
                [attributeRuns insertObject:run atIndex:index];
                [run release];                
            }
            if (! leftRemainder.length && ! rightRemainder.length) {
                /* We don't have any remainder.  Just delete it. */
                [attributeRuns removeObjectAtIndex:index];
                index -= 1;
                max -= 1;
            }     
        }
    }
    [attributeRuns removeObjectsAtIndexes:indexesToRemove];
    [indexesToRemove release];
}

- (void)removeAttribute:(NSString *)attributeName {
    HFASSERT(attributeName != nil);
    NSUInteger idx = [attributeRuns count];
    while (idx--) {
        HFByteRangeAttributeRun *run = [attributeRuns objectAtIndex:idx];
        if ([attributeName isEqualToString:run->name]) {
            [attributeRuns removeObjectAtIndex:idx];
        }
    }
}

- (void)removeAttributes:(NSSet *)attributeNames {
    NSUInteger idx = [attributeRuns count];
    while (idx--) {
        HFByteRangeAttributeRun *run = [attributeRuns objectAtIndex:idx];
        if ([attributeNames containsObject:run->name]) {
            [attributeRuns removeObjectAtIndex:idx];
        }
    }    
}

- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length {
    NSMutableSet *result = [NSMutableSet set];
    unsigned long long maxLocation = ULLONG_MAX;
    FOREACH(HFByteRangeAttributeRun *, run, attributeRuns) {
        unsigned long long runStart = run->range.location;            
        unsigned long long runEnd = HFMaxRange(run->range);        
        if (runStart > index) {
            maxLocation = MIN(maxLocation, runStart);
        }
        else if (runEnd > index) {
            maxLocation = MIN(maxLocation, runEnd);
        }
        if (HFLocationInRange(index, run->range)) {
            [result addObject:run->name];
        }
    }
    if (length) *length = maxLocation - index;
    return result;
}

- (NSSet *)attributesInRange:(HFRange)range {
    NSMutableSet *result = [NSMutableSet set];
    FOREACH(HFByteRangeAttributeRun *, run, attributeRuns) {
	if (HFIntersectsRange(range, run->range)) {
	    [result addObject:run->name];
	}
    }
    return result;
}

- (HFRange)rangeOfAttribute:(NSString *)attribute {
    FOREACH(HFByteRangeAttributeRun *, run, attributeRuns) {
	if ([attribute isEqualToString:run->name]) return run->range;
    }
    return HFRangeMake(ULLONG_MAX, ULLONG_MAX);
}

- (void)transferAttributesFromAttributeArray:(HFNaiveByteRangeAttributeArray *)array range:(HFRange)range baseOffset:(unsigned long long)baseOffset {
    HFASSERT(array != NULL);
    EXPECT_CLASS(array, HFByteRangeAttributeArray);
    FOREACH(HFByteRangeAttributeRun *, run, array->attributeRuns) {
        HFRange intersection = HFIntersectionRange(range, run->range);
        if (intersection.length > 0) {
            intersection.location += baseOffset;
            [self addAttribute:run->name range:intersection];
        }
    }
}

- (NSEnumerator *)attributeEnumerator {
    /* Sort our runs by their first location, and then extract the attributes from them. */
    NSArray *sortedRuns = [attributeRuns sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *attributes = [NSMutableArray arrayWithCapacity:[sortedRuns count]];
    FOREACH(HFByteRangeAttributeRun *, run, sortedRuns) {
	[attributes addObject:run->name];
    }
    return [attributes objectEnumerator];
}

@end

@interface HFByteRangeAttributeArrayNode : HFAnnotatedTreeNode {
@public
    NSString *attribute;
    HFRange range;
}

- (id)initWithAttribute:(NSString *)attribute range:(HFRange)val;
- (NSString *)attribute;
- (HFRange)range;

@end

@implementation HFByteRangeAttributeArrayNode

- (id)initWithAttribute:(NSString *)attr range:(HFRange)val {
    [super init];
    attribute = [attr copy];
    range = val;
    return self;
}

- (void)dealloc {
    [attribute release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%p: %@ {%llu, %llu}]", self, attribute, range.location, range.length];
}


- (NSString *)attribute {
    return attribute;
}

- (HFRange)range {
    return range;
}

- (NSComparisonResult)compare:(HFByteRangeAttributeArrayNode *)node {
    EXPECT_CLASS(node, HFByteRangeAttributeArrayNode);
    /* We are ordered by our range location */
    return (range.location > node->range.location) - (range.location < node->range.location);
}

static unsigned long long node_max_range(id left, id right) {
    if (left) EXPECT_CLASS(left, HFByteRangeAttributeArrayNode);
    if (right) EXPECT_CLASS(right, HFByteRangeAttributeArrayNode);
    HFByteRangeAttributeArrayNode *leftNode = left, *rightNode = right;
    unsigned long long result = 0;
    if (leftNode) {
	result = MAX(result, HFMaxRange(leftNode->range));
	result = MAX(result, leftNode->annotation);
    }
    if (rightNode) {
	result = MAX(result, HFMaxRange(rightNode->range));
	result = MAX(result, rightNode->annotation);
    }
    return result;
}

static void collectNodes(HFByteRangeAttributeArrayNode *node, HFRange intersectionRange, NSString *attribute, NSMutableArray *output, BOOL isRoot) {
    if (! isRoot) {
	/* The root node is the base node class, but if we're not root we should have a HFByteRangeAttributeArrayNode */
	EXPECT_CLASS(node, HFByteRangeAttributeArrayNode);
	/* See if this node matches */
	if (HFIntersectsRange(intersectionRange, node->range)) {
	    if (attribute == nil || [attribute isEqualToString:node->attribute]) {
		/* It's a match */
		[output addObject:node];
	    }
	}
    }
    
    if (intersectionRange.location >= node->annotation) {
	/* The range is to the right of the max range in this subtree, so we don't recurse to any children */
    }
    else {
	/* Always search our left node if we have one */
	BOOL recurseLeft = !! node->left;
	
	/* We don't need to search our right node if our range is entirely to the right of the given range, because our right children must be at least as far to the right. */
	BOOL recurseRight = node->right && (isRoot || node->range.location < HFMaxRange(intersectionRange));
	
	if (recurseLeft) {
	    collectNodes((HFByteRangeAttributeArrayNode *)node->left, intersectionRange, attribute, output, NO /* not isRoot */);
	}
	if (recurseRight) {
	    collectNodes((HFByteRangeAttributeArrayNode *)node->right, intersectionRange, attribute, output, NO /* not isRoot */);
	}
    }
}

/* Because our tree types left and right as HFAnnotatedTreeNode, but we want HFByteRangeAttributeArrayNode, use this function to avoid having to cast everywhere. */
static inline HFByteRangeAttributeArrayNode * leftChild(HFByteRangeAttributeArrayNode *node) { return (HFByteRangeAttributeArrayNode *)(node->left); }
static inline HFByteRangeAttributeArrayNode * rightChild(HFByteRangeAttributeArrayNode *node) { return (HFByteRangeAttributeArrayNode *)(node->right); }

static void collectAttributes(HFByteRangeAttributeArrayNode *node, unsigned long long location, NSMutableSet *attributes, unsigned long long *outLength, BOOL isRoot) {
    /* Add all attributes whose range intersects the given index.  Store in outLength the largest length over which all those attributes are valid. */
    if (! isRoot) {
	/* The root node is the base node class, but if we're not root we should have a HFByteRangeAttributeArrayNode */
	EXPECT_CLASS(node, HFByteRangeAttributeArrayNode);
	/* See if this node matches */
	if (HFLocationInRange(location, node->range)) {
	    /* It's a match - add the attribute and calculate our new max length */
	    [attributes addObject:node->attribute];
	    if (outLength) *outLength = MIN(*outLength, HFMaxRange(node->range) - location);
	}
	else if (location < node->range.location) {
	    /* If this node starts after location, then clamp outLength to it */
	    if (outLength) *outLength = MIN(*outLength, node->range.location - location);
	}
    }
        
    
    if (0 && location >= node->annotation) {
	/* The location is to the right of everything beneath us, so don't recurse */
    }
    else {
	/* Always search our left node if we have one */
	BOOL recurseLeft = !! node->left;
	
	/* Search our right node if our range starts at or left of the location.  If it's to the right, then everything else is further to the right. */
	BOOL recurseRight = node->right && 1;//(isRoot || node->range.location <= location);
	
	if (recurseLeft) {
	    collectAttributes(leftChild(node), location, attributes, outLength, NO /* not isRoot */);
	}
	if (recurseRight) {
	    collectAttributes(rightChild(node), location, attributes, outLength, NO /* not isRoot */);
	}
    }
}

static BOOL findAttribute(HFByteRangeAttributeArrayNode *node, NSString *attribute, HFRange *outResult, BOOL isRoot) {
    BOOL result = NO;
    
    /* Search left first */
    if (! result && node->left) {
	result = findAttribute(leftChild(node), attribute, outResult, NO);
    }
    
    /* Try us */
    if (! result && ! isRoot) {
	EXPECT_CLASS(node, HFByteRangeAttributeArrayNode);
	if (attribute == node->attribute || [attribute isEqualToString:node->attribute]) {
	    *outResult = node->range;
	    result = YES;
	}
    }
    
    /* Search right */
    if (! result && node->right) {
	result = findAttribute(rightChild(node), attribute, outResult, NO);
    }
    
    return result;
}

struct TransferAttributes_t {
    HFByteRangeAttributeArray *target;
    unsigned long long baseOffset;
};
static void transferAttributes(HFByteRangeAttributeArrayNode *node, HFRange intersection, void *userInfoP) {
    struct TransferAttributes_t *userInfo = userInfoP;
    intersection.location = HFSum(intersection.location, userInfo->baseOffset);
    [userInfo->target addAttribute:node->attribute range:intersection];
}

static BOOL applyFunctionForNodesInRange(HFByteRangeAttributeArrayNode *node, HFRange rangeOfInterest, void (*func)(HFByteRangeAttributeArrayNode *, HFRange, void *), void *userInfo, BOOL isRoot) {
    if (! isRoot) {
	/* The root node is the base node class, but if we're not root we should have a HFByteRangeAttributeArrayNode */
	EXPECT_CLASS(node, HFByteRangeAttributeArrayNode);
	HFRange intersection = HFIntersectionRange(rangeOfInterest, node->range);
	if (intersection.length > 0) {
	    func(node, intersection, userInfo);
	}
    }
    
    if (rangeOfInterest.location >= node->annotation) {
	/* The location is to the right of everything beneath us, so don't recurse */
    }
    else {
	/* Always search our left node if we have one */
	BOOL recurseLeft = !! node->left;
	
	/* Search our right node if our range starts at or left of the location.  If it's to the right, then everything else is further to the right. */
	BOOL recurseRight = node->right && (isRoot || node->range.location <= rangeOfInterest.location);
	
	if (recurseLeft) {
	    applyFunctionForNodesInRange(leftChild(node), rangeOfInterest, func, userInfo, NO /* not isRoot */);
	}
	if (recurseRight) {
	    applyFunctionForNodesInRange(rightChild(node), rangeOfInterest, func, userInfo, NO /* not isRoot */);
	}
    }
    
}

@end

@interface HFAnnotatedTreeByteRangeAttributeArrayEnumerator : NSEnumerator {
    HFByteRangeAttributeArrayNode *node;
}

- (id)initWithNode:(HFByteRangeAttributeArrayNode *)val;

@end

@implementation HFAnnotatedTreeByteRangeAttributeArray

- (id)init {
    [super init];
    atree = [[HFAnnotatedTree alloc] initWithAnnotater:node_max_range];
    return self;
}

- (NSString *)description {
    NSMutableArray *nodes = [[NSMutableArray alloc] init];
    for (HFAnnotatedTreeNode *node = [atree firstNode]; node != nil; node = [node nextNode]) {
	[nodes addObject:node];
    }
    NSString *result = [NSString stringWithFormat:@"<%@: %p %@>", [self class], self, nodes];
    [nodes release];
    return result;
}


- (void)addAttribute:(NSString *)attributeName range:(HFRange)range {
    HFByteRangeAttributeArrayNode *node = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:attributeName range:range];
    [atree insertNode:node];
    [node release];
}

- (void)removeAttribute:(NSString *)attributeName range:(HFRange)range {
    NSMutableArray *nodesToDelete = [[NSMutableArray alloc] init];
    collectNodes([atree rootNode], range, attributeName, nodesToDelete, YES);
    for (HFByteRangeAttributeArrayNode *node in nodesToDelete) {
	
	/* Definitely remove this node.  It's retained by virtue of being in the nodesToDelete array. */
	[atree removeNode:node];
	
	/* We may have to split node into zero, one, or two pieces.  We could be more efficient and re-use the node if we wanted. */
	if (node->range.location < range.location) {
	    HFRange leftRemainder = HFRangeMake(node->range.location, range.location - node->range.location);
	    HFByteRangeAttributeArrayNode *newNode = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:attributeName range:leftRemainder];
	    [atree insertNode:newNode];
	    [newNode release];
	    
	}
	if (HFRangeExtendsPastRange(node->range, range)) {
	    HFRange rightRemainder = HFRangeMake(HFMaxRange(range), HFMaxRange(node->range) - HFMaxRange(range));
	    HFASSERT(rightRemainder.length > 0);
	    HFByteRangeAttributeArrayNode *newNode = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:attributeName range:rightRemainder];
	    [atree insertNode:newNode];
	    [newNode release];
	}
    }
    [nodesToDelete release];
}

- (void)removeAttribute:(NSString *)attributeName {
    [self removeAttribute:attributeName range:HFRangeMake(0, ULLONG_MAX)];
}

- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length {
    NSMutableSet *attributes = [[NSMutableSet alloc] init];
    if (length) *length = ULLONG_MAX - index;
    collectAttributes([atree rootNode], index, attributes, length, YES);
    return [attributes autorelease];
}

- (HFRange)rangeOfAttribute:(NSString *)attribute {
    HFRange result = {ULLONG_MAX, ULLONG_MAX};
    findAttribute([atree rootNode], attribute, &result, YES);
    return result;
}

static void attributesInRange(HFByteRangeAttributeArrayNode *node, HFRange range, void *userInfo) {
    [(NSMutableSet *)userInfo addObject:[node attribute]];
}

- (NSSet *)attributesInRange:(HFRange)range {
    NSMutableSet *result = [NSMutableSet set];
    applyFunctionForNodesInRange([atree rootNode], range, attributesInRange, result, YES/* isRoot */);
    return result;
}

- (void)transferAttributesFromAttributeArray:(HFAnnotatedTreeByteRangeAttributeArray *)array range:(HFRange)range baseOffset:(unsigned long long)baseOffset {
    EXPECT_CLASS(array, HFAnnotatedTreeByteRangeAttributeArray);
    struct TransferAttributes_t info = {self, baseOffset};
    applyFunctionForNodesInRange([array->atree rootNode], range, transferAttributes, &info, YES /* isRoot */);
}

- (BOOL)isEmpty {
    return [atree isEmpty];
}

- (NSEnumerator *)attributeEnumerator {
    return [[[HFAnnotatedTreeByteRangeAttributeArrayEnumerator alloc] initWithNode:[atree firstNode]] autorelease];
}

@end

@implementation HFAnnotatedTreeByteRangeAttributeArrayEnumerator

- (id)initWithNode:(HFByteRangeAttributeArrayNode *)val {
    node = val;
}

- (id)nextObject {
    id result = [node attribute];
    node = [node nextNode];
    return result;
}

@end
