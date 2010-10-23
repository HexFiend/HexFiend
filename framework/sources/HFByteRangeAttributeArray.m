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

/* Our ATree node class for storing an attribute. */
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

static BOOL applyFunctionForNodesInRange(HFByteRangeAttributeArrayNode *node, HFRange rangeOfInterest, BOOL (*func)(HFByteRangeAttributeArrayNode *, HFRange, void *), void *userInfo, BOOL isRoot) {
    BOOL shouldContinue = YES;
    
    /* Figure out whether to recurse left and/or right */
    BOOL recurseLeft = NO, recurseRight = NO;
    if (!isRoot && rangeOfInterest.location >= node->annotation) {
	/* The location is to the right of everything beneath us, so don't recurse left or right */
    }
    else {
	/* Always search our left node if we have one */
	recurseLeft = !! node->left;
	
	/* Search our right node if our range starts left of the end of the range of interest.  If it's to the right, then all right children are at least as far to the right, so none of them can intersect the ROI. */
	recurseRight = node->right && (isRoot || node->range.location < HFMaxRange(rangeOfInterest));	
    }
    
    /* Recurse left first, so we go in-order */
    if (shouldContinue && recurseLeft) {
	shouldContinue = applyFunctionForNodesInRange((HFByteRangeAttributeArrayNode *)(node->left), rangeOfInterest, func, userInfo, NO /* not isRoot */);
    }
    
    /* Now try this node, unless it's root */
    if (shouldContinue && ! isRoot) {
	/* The root node is the base node class, but if we're not root we should have a HFByteRangeAttributeArrayNode */
	EXPECT_CLASS(node, HFByteRangeAttributeArrayNode);
	HFRange intersection = HFIntersectionRange(rangeOfInterest, node->range);
	if (intersection.length > 0) {
	    shouldContinue = func(node, intersection, userInfo);
	}	
    }
    
    /* Now recurse right */
    if (shouldContinue && recurseRight) {
	shouldContinue = applyFunctionForNodesInRange((HFByteRangeAttributeArrayNode *)(node->right), rangeOfInterest, func, userInfo, NO /* not isRoot */);
    }

    return shouldContinue;
}

@end

@interface HFAnnotatedTreeByteRangeAttributeArrayEnumerator : NSEnumerator {
    HFByteRangeAttributeArrayNode *node;
}

- (id)initWithNode:(HFByteRangeAttributeArrayNode *)val;

@end

@implementation HFAnnotatedTreeByteRangeAttributeArray

- (BOOL)walkNodesInRange:(HFRange)range withFunction:(BOOL (*)(HFByteRangeAttributeArrayNode *, HFRange, void *))func userInfo:(void *)userInfoP {
    return applyFunctionForNodesInRange([self->atree rootNode], range, func, userInfoP, YES /* isRoot */);
}

- (id)init {
    [super init];
    atree = [[HFAnnotatedTree alloc] initWithAnnotater:node_max_range];
    attributesToNodes = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)dealloc {
    [atree release];
    [attributesToNodes release];
    [super dealloc];
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

/* Helper function to insert a value into a set under the given key, creating it if necessary.  This could be more efficient as a CFSet because we want object identity semantics. */
static void insertIntoDictionaryOfSets(NSMutableDictionary *dictionary, NSString *key, id value) {
    NSMutableSet *set = [dictionary objectForKey:key];
    if (! set) {
	set = [[NSMutableSet alloc] init];
	[dictionary setObject:set forKey:key];
	[set release];
    }
    [set addObject:value];
}

- (void)addAttribute:(NSString *)attributeName range:(HFRange)range {
    HFByteRangeAttributeArrayNode *node = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:attributeName range:range];
    [atree insertNode:node];
    insertIntoDictionaryOfSets(attributesToNodes, attributeName, node);
    [node release];
}

static BOOL collectNodesWithAttribute(HFByteRangeAttributeArrayNode *node, HFRange intersection, void *userInfoP) {
    [(id)userInfoP addObject:node];
    return YES; //continue
}

- (void)removeAttribute:(NSString *)attributeName range:(HFRange)range {
    /* Get the nodes that we will delete */
    NSMutableArray *nodesToDelete = [[NSMutableArray alloc] init];
    [self walkNodesInRange:range withFunction:collectNodesWithAttribute userInfo:nodesToDelete];
    
    /* We're going to remove these from the attributesToNodes set */
    NSMutableSet *allNodesWithAttribute = [attributesToNodes objectForKey:attributeName];
    
    FOREACH(HFByteRangeAttributeArrayNode *, node, nodesToDelete) {
	
	/* Remove from the corresponding attributesToNodes set */
	[allNodesWithAttribute removeObject:node];
	
	/* Remove this node from the tree too.  It's retained by virtue of being in the nodesToDelete array. */
	[atree removeNode:node];
	
	/* We may have to split node into zero, one, or two pieces.  We could be more efficient and re-use the node if we wanted. */
	if (node->range.location < range.location) {
	    HFRange leftRemainder = HFRangeMake(node->range.location, range.location - node->range.location);
	    HFByteRangeAttributeArrayNode *newNode = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:attributeName range:leftRemainder];
	    [atree insertNode:newNode];
	    [allNodesWithAttribute addObject:newNode];
	    [newNode release];
	    
	}
	if (HFRangeExtendsPastRange(node->range, range)) {
	    HFRange rightRemainder = HFRangeMake(HFMaxRange(range), HFMaxRange(node->range) - HFMaxRange(range));
	    HFASSERT(rightRemainder.length > 0);
	    HFByteRangeAttributeArrayNode *newNode = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:attributeName range:rightRemainder];
	    [atree insertNode:newNode];
	    [allNodesWithAttribute addObject:newNode];
	    [newNode release];
	}
    }
    [nodesToDelete release];
    
    /* Maybe allNodesWithAttribute is now empty */
    if (! [allNodesWithAttribute count]) {
	[attributesToNodes removeObjectForKey:attributeName];
    }
}

- (void)removeAttribute:(NSString *)attributeName {
    /* We can just remove everything in attributesToNodes */
    NSMutableSet *matchingNodes = [attributesToNodes objectForKey:attributeName];
    if (matchingNodes) {
	for (HFByteRangeAttributeArrayNode *node in matchingNodes) {
	    [atree removeNode:node];
	}
	/* We can just remove the entire set */
	[attributesToNodes removeObjectForKey:attributeName];
    }
}

- (void)removeAttributes:(NSSet *)attributeNames {
    /* This may be more efficient by walking the tree */
    for (NSString *name in attributeNames) {
	[self removeAttribute:name];
    }
}

struct CollectAttributes_t {
    NSMutableSet *attributes;
    unsigned long long locationOfInterest;
    unsigned long long validLength;
};
static BOOL collectAttributes(HFByteRangeAttributeArrayNode *node, HFRange intersection, void *userInfoP) {
    struct CollectAttributes_t *userInfo = userInfoP;
    BOOL shouldContinue;
    /* Store in validLength the maximum length over which all attributes are valid. */
    if (HFLocationInRange(userInfo->locationOfInterest, intersection)) {
	/* We want this node's attribute */
	[userInfo->attributes addObject:node->attribute];
	/* This node contains the location we're interested in, so we are valid to the end of the intersection. */
	userInfo->validLength = MIN(userInfo->validLength, HFSubtract(HFMaxRange(intersection), userInfo->locationOfInterest));
	/* Maybe there's more nodes */
	shouldContinue = YES;
    }
    else {
	/* This node does not contain the location we're interested in (it must start beyond it), so we are valid to the beginning of its range */
	userInfo->validLength = MIN(userInfo->validLength, HFSubtract(intersection.location, userInfo->locationOfInterest));
	/* Since the nodes are walked left-to-right according to the node's start location, no subsequent node can contain our locationOfInterest, and all subsequent nodes must have a start location at or after this one.  So we're done. */
	shouldContinue = NO;
    }
    return shouldContinue;
}

- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length {
    struct CollectAttributes_t userInfo = {
	.attributes = [[NSMutableSet alloc] init],
	.locationOfInterest = index,
	.validLength = ULLONG_MAX
    };
    /* length will contain the length over which the given set of attributes applies.  In case no attributes apply, we need to return that length; so we need to walk the entire tree.. */
    [self walkNodesInRange:HFRangeMake(index, ULLONG_MAX - index) withFunction:collectAttributes userInfo:&userInfo];
    if (length) *length = userInfo.validLength;
    return [userInfo.attributes autorelease];
}

struct FindAttribute_t {
    NSString *attribute;
    HFRange resultRange;
};
static BOOL findAttribute(HFByteRangeAttributeArrayNode *node, HFRange intersection, void *userInfoP) {
    BOOL result = YES; /* assume continue */
    struct FindAttribute_t *userInfo = userInfoP;
    if ([userInfo->attribute isEqualToString:node->attribute]) {
	userInfo->resultRange = node->range;
	result = NO; /* all done */
    }
    return result;
}

- (HFRange)rangeOfAttribute:(NSString *)attribute {
    struct FindAttribute_t userInfo = {
	.attribute = attribute,
	.resultRange = {ULLONG_MAX, ULLONG_MAX}
    };
    [self walkNodesInRange:HFRangeMake(0, ULLONG_MAX) withFunction:findAttribute userInfo:&userInfo];
    return userInfo.resultRange;
}

static BOOL fetchAttributes(HFByteRangeAttributeArrayNode *node, HFRange range, void *userInfo) {
    [(NSMutableSet *)userInfo addObject:[node attribute]];
    return YES; /* continue fetching */
}
- (NSSet *)attributesInRange:(HFRange)range {
    NSMutableSet *result = [NSMutableSet set];
    [self walkNodesInRange:range withFunction:fetchAttributes userInfo:result];
    return result;
}

struct TransferAttributes_t {
    HFByteRangeAttributeArray *target;
    unsigned long long baseOffset;
};
static BOOL transferAttributes(HFByteRangeAttributeArrayNode *node, HFRange intersection, void *userInfoP) {
    struct TransferAttributes_t *userInfo = userInfoP;
    intersection.location = HFSum(intersection.location, userInfo->baseOffset);
    [userInfo->target addAttribute:node->attribute range:intersection];
    return YES; /* continue transferring */
}
- (void)transferAttributesFromAttributeArray:(HFAnnotatedTreeByteRangeAttributeArray *)array range:(HFRange)range baseOffset:(unsigned long long)baseOffset {
    EXPECT_CLASS(array, HFAnnotatedTreeByteRangeAttributeArray);
    struct TransferAttributes_t info = {self, baseOffset};
    [array walkNodesInRange:range withFunction:transferAttributes userInfo:&info];
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
    [super init];
    node = val;
    return self;
}

- (id)nextObject {
    id result = [node attribute];
    node = [node nextNode];
    return result;
}

@end
