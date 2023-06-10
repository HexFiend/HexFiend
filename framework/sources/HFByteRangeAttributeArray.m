//
//  HFByteRangeAttributeArray.m
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteRangeAttributeArray.h>
#import "HFAnnotatedTree.h"
#import <HexFiend/HFByteRangeAttribute.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

#if NDEBUG
#define VERIFY_INTEGRITY(x) do { } while (0)
#else
#define VERIFY_INTEGRITY(x) [(x) verifyIntegrity]
#endif

/* Helper function to construct a range */
static HFRange entireRangeExtendingFromIndex(unsigned long long start) {
    return HFRangeMake(start, ULLONG_MAX - start);
}

static const HFRange kEntireRange = {0, ULLONG_MAX};

@interface HFByteRangeAttributeArray (HFForwardDeclarations)
- (BOOL)shouldTransferAttribute:(NSString *)attribute;
@end

@interface HFByteRangeAttributeRun : NSObject {
@public
    NSString *name;
    HFRange range;
}

- (instancetype)initWithName:(NSString *)nameParameter range:(HFRange)rangeParameter;

@end

/* These guys are immutable! */
@implementation HFByteRangeAttributeRun

- (instancetype)initWithName:(NSString *)nameParameter range:(HFRange)rangeParameter {
    HFASSERT(nameParameter != nil);
    self = [super init];
    name = [nameParameter copy];
    range = rangeParameter;
    return self;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"[%@ {%llu, %llu}]", name, range.location, range.length];
}

- (NSComparisonResult)compare:(HFByteRangeAttributeRun *)run {
    return (range.location > run->range.location) - (run->range.location > range.location);
}

@end

@implementation HFByteRangeAttributeArray

- (instancetype)init {
    // HFByteRangeAttributeArray is abstract class. Do not use directly.
    HFASSERT([self class] != [HFByteRangeAttributeArray class]);
    self = [super init];
    return self;
}

- (id)mutableCopyWithZone:(NSZone *)zone { USE(zone); UNIMPLEMENTED(); }
- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length { USE(index); USE(length); UNIMPLEMENTED(); }
- (NSSet *)attributesInRange:(HFRange)range { USE(range); UNIMPLEMENTED(); }
- (HFRange)rangeOfAttribute:(NSString *)attribute { USE(attribute); UNIMPLEMENTED_VOID(); return HFRangeMake(0, 0); }
- (void)addAttribute:(NSString *)attributeName range:(HFRange)range { USE(attributeName); USE(range); UNIMPLEMENTED_VOID(); }
- (void)removeAttribute:(NSString *)attributeName range:(HFRange)range { USE(attributeName); USE(range); UNIMPLEMENTED_VOID(); }
- (void)removeAttribute:(NSString *)attributeName { USE(attributeName); UNIMPLEMENTED_VOID(); }
- (void)removeAttributes:(NSSet *)attributeName { USE(attributeName); UNIMPLEMENTED_VOID(); }
- (BOOL)isEmpty { UNIMPLEMENTED(); }
- (NSEnumerator *)attributeEnumerator { UNIMPLEMENTED(); }
- (void)transferAttributesFromAttributeArray:(HFByteRangeAttributeArray *)array range:(HFRange)range baseOffset:(unsigned long long)baseOffset validator:(BOOL (^)(NSString *))allowTransferValidator {
    USE(array);
    USE(range);
    USE(baseOffset);
    USE(allowTransferValidator);
    UNIMPLEMENTED_VOID();
}
- (void)byteRange:(HFRange)srcRange wasReplacedByBytesOfLength:(unsigned long long)replacementLength {
    USE(srcRange);
    USE(replacementLength);
    UNIMPLEMENTED_VOID();
}

- (BOOL)shouldTransferAttribute:(NSString *)attribute {
    /* Hack: in transferAttributesFromAttributeArray:, prevent things like getting duplicate bookmarks. This logic should live somewhere else. */
    if ([attribute isEqualToString:kHFAttributeDiffInsertion] || [attribute isEqualToString:kHFAttributeFocused]) {
        return NO;
    } else if (HFBookmarkFromBookmarkAttribute(attribute) != NSNotFound) {
        return HFRangeEqualsRange([self rangeOfAttribute:attribute], HFRangeMake(ULLONG_MAX, ULLONG_MAX));
    } else {
        return YES;
    }
}

#if ! NDEBUG
- (void)verifyIntegrity {
    
}
#endif

- (BOOL)isEqual:(HFByteRangeAttributeArray *)array {
    if (! [array isKindOfClass:[HFByteRangeAttributeArray class]]) return NO;
    VERIFY_INTEGRITY(self);
    VERIFY_INTEGRITY(array);
    HFRange remaining = HFRangeMake(0, ULLONG_MAX);
    BOOL result = YES;
    int num = 0;
    const BOOL log = NO;
    while (remaining.length > 0) {
        @autoreleasepool {
        unsigned long long applied1, applied2;
        NSSet *atts1 = [self attributesAtIndex:remaining.location length:&applied1];
        NSSet *atts2 = [array attributesAtIndex:remaining.location length:&applied2];
        if (applied1 != applied2) {
            if (log) {
                NSLog(@"%d Failed %d", num, __LINE__);
            }
            [array attributesAtIndex:remaining.location length:&applied2];
            result = NO;
            break;
        }
        if (result && !atts1 != !atts2) {
            if (log) {
                NSLog(@"%d Failed %d", num, __LINE__);
            }
            result = NO;
            break;
        }
        if (! (atts1 == atts2 || [atts1 isEqual:atts2])) {
            if (log) {
                NSLog(@"%d Failed %d", num, __LINE__);
            }
            result = NO;
            break;
        }
        HFASSERT(applied1 <= remaining.length);
        remaining.length -= applied1;
        remaining.location += applied1;
        } // @autoreleasepool
    }
    return result;
}

- (NSUInteger)hash {
    return 0; //d'oh, no obvious way to hash this
}

@end

@implementation HFNaiveByteRangeAttributeArray

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p %@>", [self class], self, attributeRuns];
}

- (instancetype)init {
    self = [super init];
    attributeRuns = [[NSMutableArray alloc] init];
    return self;
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
}

-  (void)removeAttribute:(NSString *)attributeName range:(HFRange)range {
    HFASSERT(attributeName != nil);
    NSMutableIndexSet *indexesToRemove = [[NSMutableIndexSet alloc] init];
    NSUInteger index = 0, max = [attributeRuns count];
    for (index = 0; index < max; index++) {
        HFByteRangeAttributeRun *run = attributeRuns[index];
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
                attributeRuns[index] = run;
            }
            if (leftRemainder.length && rightRemainder.length) {
                /* We have two to insert.  The second must be the right remainder, because we inserted the left up above. */
                index += 1;
                max += 1;
                run = [[HFByteRangeAttributeRun alloc] initWithName:attributeName range:rightRemainder];
                [attributeRuns insertObject:run atIndex:index];
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
}

- (void)removeAttribute:(NSString *)attributeName {
    HFASSERT(attributeName != nil);
    NSUInteger idx = [attributeRuns count];
    while (idx--) {
        HFByteRangeAttributeRun *run = attributeRuns[idx];
        if ([attributeName isEqualToString:run->name]) {
            [attributeRuns removeObjectAtIndex:idx];
        }
    }
}

- (void)removeAttributes:(NSSet *)attributeNames {
    NSUInteger idx = [attributeRuns count];
    while (idx--) {
        HFByteRangeAttributeRun *run = attributeRuns[idx];
        if ([attributeNames containsObject:run->name]) {
            [attributeRuns removeObjectAtIndex:idx];
        }
    }    
}

- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length {
    NSMutableSet *result = [NSMutableSet set];
    unsigned long long maxLocation = ULLONG_MAX;
    for(HFByteRangeAttributeRun *run in attributeRuns) {
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
    for(HFByteRangeAttributeRun *run in attributeRuns) {
        if (HFIntersectsRange(range, run->range)) {
            [result addObject:run->name];
        }
    }
    return result;
}

- (HFRange)rangeOfAttribute:(NSString *)attribute {
    for(HFByteRangeAttributeRun *run in attributeRuns) {
        if ([attribute isEqualToString:run->name]) return run->range;
    }
    return HFRangeMake(ULLONG_MAX, ULLONG_MAX);
}

- (void)transferAttributesFromAttributeArray:(HFNaiveByteRangeAttributeArray *)array range:(HFRange)range baseOffset:(unsigned long long)baseOffset validator:(BOOL (^)(NSString *))allowTransfer {
    HFASSERT(array != NULL);
    HFASSERT(array != self);
    EXPECT_CLASS(array, HFNaiveByteRangeAttributeArray);
    for(HFByteRangeAttributeRun *run in array->attributeRuns) {
        if (! allowTransfer || allowTransfer(run->name)) {
            HFRange intersection = HFIntersectionRange(range, run->range);
            if (intersection.length > 0) {
                intersection.location += baseOffset;
                [self addAttribute:run->name range:intersection];
            }
        }
    }
}

- (NSEnumerator *)attributeEnumerator {
    /* Sort our runs by their first location, and then extract the attributes from them. */
    NSArray *sortedRuns = [attributeRuns sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *attributes = [NSMutableArray arrayWithCapacity:[sortedRuns count]];
    for(HFByteRangeAttributeRun *run in sortedRuns) {
        [attributes addObject:run->name];
    }
    return [attributes objectEnumerator];
}

- (void)byteRange:(HFRange)dyingRange wasReplacedByBytesOfLength:(unsigned long long)replacementLength {
    NSArray *localRuns = [attributeRuns copy];
    NSUInteger idx = 0;
    for(HFByteRangeAttributeRun *run in localRuns) {
        const HFRange runRange = run->range;
        HFRange newRange;
        
        /* Check if we are inserting (not replacing) at either the very beginning of the run, or very end. */
        BOOL insertionAtRunBeginning = (dyingRange.length == 0 && dyingRange.location == runRange.location);
        BOOL insertionAtRunEnd = (dyingRange.length == 0 && dyingRange.location == HFMaxRange(runRange));
        
        if (HFRangeIsSubrangeOfRange(runRange, dyingRange)) {
            /* This run is toast */
            newRange = (HFRange){0, 0};
        } else if (HFRangeIsSubrangeOfRange(dyingRange, runRange) && !insertionAtRunBeginning && !insertionAtRunEnd) {
            /* The replaced range is wholly contained within this run, so expand the run. The location doesn't need to change. */
            newRange.location = run->range.location;
            newRange.length = HFSum(HFSubtract(runRange.length, dyingRange.length), replacementLength);
        } else if (HFMaxRange(dyingRange) <= runRange.location || insertionAtRunBeginning) {
            /* The dying range is wholly before this run, so adjust the run location. The length doesn't need to change. */
            newRange.length = runRange.length;
            newRange.location = HFSum(HFSubtract(runRange.location, dyingRange.length), replacementLength);
        } else if (dyingRange.location >= HFMaxRange(runRange) || insertionAtRunEnd) {
            /* The dying range is wholly after this run, so nothing to do */
            newRange = runRange;
        } else {
            /* The range must intersect */
            HFRange intersection = HFIntersectionRange(dyingRange, runRange);
            HFASSERT(intersection.length > 0);
            
            /* We intersect the range that's being deleted. Figure out where we should be preserved (if at all). */
            HFRange leftRemainingRange = {0, 0}, rightRemainingRange = {0, 0};
            if (runRange.location < intersection.location) {
                leftRemainingRange = HFRangeMake(runRange.location, HFSubtract(intersection.location, runRange.location));
            }
            if (HFMaxRange(runRange) > HFMaxRange(intersection)) {
                rightRemainingRange = HFRangeMake(HFMaxRange(intersection), HFSubtract(HFMaxRange(runRange), HFMaxRange(intersection)));
            }
            
            /* Now we have up to two ranges. Pick the longer one */
            newRange = (leftRemainingRange.length >= rightRemainingRange.length ? leftRemainingRange : rightRemainingRange);
            
            /* One range must be non-empty, otherwise we would have fallen into one of the tests above */
            HFASSERT(newRange.length > 0);
            
            /* The new range location is the smaller of the dying range location and the remaining range location */
            newRange.location = MIN(newRange.location, dyingRange.location + replacementLength);
        }
        
        if (newRange.length == 0) {
            /* Deleted */
            [attributeRuns removeObjectAtIndex:idx--];
        } else if (HFRangeEqualsRange(newRange, runRange)) {
            /* No change */
        } else {
            HFByteRangeAttributeRun *newRun = [[HFByteRangeAttributeRun alloc] initWithName:run->name range:newRange];
            attributeRuns[idx] = newRun;
        }
        idx++;
    }
}

@end

/* Our ATree node class for storing an attribute. */
@interface HFByteRangeAttributeArrayNode : HFAnnotatedTreeNode {
@public
    NSString *attribute;
    HFRange range;
}

- (instancetype)initWithAttribute:(NSString *)attribute range:(HFRange)val;
- (NSString *)attribute;
- (HFRange)range;

@end

@implementation HFByteRangeAttributeArrayNode

- (id)mutableCopyWithZone:(NSZone *)zone {
    HFByteRangeAttributeArrayNode *result = [super mutableCopyWithZone:zone];
    result->attribute = [attribute copy];
    result->range = range;
    return result;
}

- (instancetype)initWithAttribute:(NSString *)attr range:(HFRange)val {
    self = [super init];
    attribute = [attr copy];
    range = val;
    return self;
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

static BOOL applyHandlerForNodesInRange(HFByteRangeAttributeArrayNode *node, HFRange rangeOfInterest, BOOL (^block)(HFByteRangeAttributeArrayNode *, HFRange), BOOL isRoot) {
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
        shouldContinue = applyHandlerForNodesInRange((HFByteRangeAttributeArrayNode *)(node->left), rangeOfInterest, block, NO /* not isRoot */);
    }
    
    /* Now try this node, unless it's root */
    if (shouldContinue && ! isRoot) {
        /* The root node is the base node class, but if we're not root we should have a HFByteRangeAttributeArrayNode */
        EXPECT_CLASS(node, HFByteRangeAttributeArrayNode);
        HFRange intersection = HFIntersectionRange(rangeOfInterest, node->range);
        if (intersection.length > 0) {
            shouldContinue = block(node, intersection);
        }	
    }
    
    /* Now recurse right */
    if (shouldContinue && recurseRight) {
        shouldContinue = applyHandlerForNodesInRange((HFByteRangeAttributeArrayNode *)(node->right), rangeOfInterest, block, NO /* not isRoot */);
    }
    
    return shouldContinue;
}

@end

@interface HFAnnotatedTreeByteRangeAttributeArrayEnumerator : NSEnumerator {
    HFByteRangeAttributeArrayNode *node;
}

- (instancetype)initWithNode:(HFByteRangeAttributeArrayNode *)val;

@end

@implementation HFAnnotatedTreeByteRangeAttributeArray

- (BOOL)walkNodesInRange:(HFRange)range withBlock:(BOOL (^)(HFByteRangeAttributeArrayNode *node, HFRange range))handler {
    return applyHandlerForNodesInRange([self->atree rootNode], range, handler, YES /* isRoot */);
}

- (instancetype)init {
    self = [super init];
    atree = [[HFAnnotatedTree alloc] initWithAnnotater:node_max_range];
    attributesToNodes = [[NSMutableDictionary alloc] init];
    return self;
}

- (NSString *)description {
    NSMutableArray *nodes = [[NSMutableArray alloc] init];
    for (HFAnnotatedTreeNode *node = [atree firstNode]; node != nil; node = [node nextNode]) {
        [nodes addObject:node];
    }
    NSString *result = [NSString stringWithFormat:@"<%@: %p %@>", [self class], self, nodes];
    return result;
}

/* Helper function to insert a value into a set under the given key, creating it if necessary.  This could be more efficient as a CFSet because we want object identity semantics. */
static void insertIntoDictionaryOfSets(NSMutableDictionary *dictionary, NSString *key, id value) {
    NSMutableSet *set = dictionary[key];
    if (! set) {
        set = [[NSMutableSet alloc] init];
        dictionary[key] = set;
    }
    [set addObject:value];
}

static void removeFromDictionaryOfSets(NSMutableDictionary *dictionary, NSString *key, id value) {
    NSMutableSet *set = dictionary[key];
    if (set) {
        [set removeObject:value];
        if (! [set count]) [dictionary removeObjectForKey:key];
    }
}

- (void)populateAttributesToNodes:(NSMutableDictionary *)dictionary {
    [self walkNodesInRange:kEntireRange withBlock:^(HFByteRangeAttributeArrayNode *node, HFRange range) {
        USE(range);
        insertIntoDictionaryOfSets(dictionary, node->attribute, node);
        /* Continue */
        return (BOOL)YES;
    }];
}

#if ! NDEBUG
- (void)verifyIntegrity {
    [super verifyIntegrity];
    
    /* Verify our tree */
    [atree verifyIntegrity];
    
    /* Ensure attributesToNodes is correct */
    NSMutableDictionary *temp = [[NSMutableDictionary alloc] init];
    [self populateAttributesToNodes:temp];
    HFASSERT([temp isEqual:attributesToNodes]);
}
#endif

- (void)addAttribute:(NSString *)attributeName range:(HFRange)range {
    HFByteRangeAttributeArrayNode *node = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:attributeName range:range];
    [atree insertNode:node];
    insertIntoDictionaryOfSets(attributesToNodes, attributeName, node);
}

- (void)removeAttribute:(NSString *)attributeName range:(HFRange)range {
    /* Get the nodes that we will delete */
    NSMutableArray *nodesToDelete = [[NSMutableArray alloc] init];
    [self walkNodesInRange:range withBlock:^(HFByteRangeAttributeArrayNode *node, HFRange rng){
        USE(rng);
        if ([attributeName isEqualToString:node->attribute]) {
            [nodesToDelete addObject:node];
        }
        return YES;
    }];
    
    /* We're going to remove these from the attributesToNodes set */
    NSMutableSet *allNodesWithAttribute = attributesToNodes[attributeName];
    
    for(HFByteRangeAttributeArrayNode *node in nodesToDelete) {
        
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
        }
        if (HFRangeExtendsPastRange(node->range, range)) {
            HFRange rightRemainder = HFRangeMake(HFMaxRange(range), HFMaxRange(node->range) - HFMaxRange(range));
            HFASSERT(rightRemainder.length > 0);
            HFByteRangeAttributeArrayNode *newNode = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:attributeName range:rightRemainder];
            [atree insertNode:newNode];
            [allNodesWithAttribute addObject:newNode];
        }
    }
    
    /* Maybe allNodesWithAttribute is now empty */
    if (! [allNodesWithAttribute count]) {
        [attributesToNodes removeObjectForKey:attributeName];
    }
}

- (void)removeAttribute:(NSString *)attributeName {
    /* We can just remove everything in attributesToNodes */
    NSMutableSet *matchingNodes = attributesToNodes[attributeName];
    if (matchingNodes) {
        for(HFByteRangeAttributeArrayNode *node in matchingNodes) {
            [atree removeNode:node];
        }
        /* We can just remove the entire set */
        [attributesToNodes removeObjectForKey:attributeName];
    }
}

- (void)removeAttributes:(NSSet *)attributeNames {
    /* This may be more efficient by walking the tree */
    for(NSString *name in attributeNames) {
        [self removeAttribute:name];
    }
}

- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length {
    NSMutableSet *attributes = [[NSMutableSet alloc] init];
    __block unsigned long long maxLocation = ULLONG_MAX;
    /* length will contain the length over which the given set of attributes applies.  In case no attributes apply, we need to return that length; so we need to walk the entire tree. */
    [self walkNodesInRange:entireRangeExtendingFromIndex(index) withBlock:^(HFByteRangeAttributeArrayNode *node, HFRange intersection) {
        BOOL shouldContinue;
        /* Store in validLength the maximum length over which all attributes are valid. */
        if (HFLocationInRange(index, intersection)) {
            /* We want this node's attribute */
            [attributes addObject:node->attribute];
            /* This node contains the location we're interested in, so we are valid to the end of the intersection. */
            maxLocation = MIN(maxLocation, HFMaxRange(intersection));
            /* Maybe there's more nodes */
            shouldContinue = YES;
        }
        else {
            /* This node does not contain the location we're interested in (it must start beyond it), so we are valid to the beginning of its range */
            maxLocation = MIN(maxLocation, intersection.location);
            /* Since the nodes are walked left-to-right according to the node's start location, no subsequent node can contain our locationOfInterest, and all subsequent nodes must have a start location at or after this one.  So we're done. */
            shouldContinue = NO;
        }
        return shouldContinue;

    }];
    HFASSERT(maxLocation > index);
    if (length) *length = maxLocation - index;
    return attributes;
}

- (HFRange)rangeOfAttribute:(NSString *)attribute {
    __block HFRange resultRange = {ULLONG_MAX, ULLONG_MAX};
    [self walkNodesInRange:kEntireRange withBlock:^BOOL(HFByteRangeAttributeArrayNode *node, HFRange range) {
        USE(range);
        BOOL result = YES; /* assume continue */
        if ([attribute isEqualToString:node->attribute]) {
            resultRange = node->range;
            result = NO; /* all done */
        }
        return result;
    }];
    return resultRange;
}

- (NSSet *)attributesInRange:(HFRange)range {
    NSMutableSet *result = [NSMutableSet set];
    [self walkNodesInRange:range withBlock:^BOOL(HFByteRangeAttributeArrayNode *node, HFRange rng) {
        USE(rng);
        [result addObject:[node attribute]];
        return YES; /* continue fetching */
    }];
    return result;
}

- (void)transferAttributesFromAttributeArray:(HFAnnotatedTreeByteRangeAttributeArray *)array range:(HFRange)range baseOffset:(unsigned long long)baseOffset validator:(BOOL (^)(NSString *))allowTransferValidator {
    EXPECT_CLASS(array, HFAnnotatedTreeByteRangeAttributeArray);
    [array walkNodesInRange:range withBlock:^(HFByteRangeAttributeArrayNode *node, HFRange intersection) {
        if (allowTransferValidator == NULL || allowTransferValidator(node->attribute)) {            
            intersection.location = HFSum(intersection.location, baseOffset);
            [self addAttribute:node->attribute range:intersection];
        }
        return YES; /* continue transferring */
    }];
}

- (void)byteRange:(HFRange)dyingRange wasReplacedByBytesOfLength:(unsigned long long)replacementLength {
    @autoreleasepool {
    
    NSMapTable *nodesToReplace = [NSMapTable strongToStrongObjectsMapTable];
    const id null = [NSNull null];
    
    HFRange extendedRange = HFRangeMake(dyingRange.location, ULLONG_MAX - dyingRange.location);
    [self walkNodesInRange:extendedRange withBlock:^(HFByteRangeAttributeArrayNode *node, HFRange range) {
        USE(range);
        const HFRange runRange = node->range;
        HFRange newRange;
        
        /* Check if we are inserting (not replacing) at either the very beginning of the run, or very end. */
        BOOL insertionAtRunBeginning = (dyingRange.length == 0 && dyingRange.location == runRange.location);
        BOOL insertionAtRunEnd = (dyingRange.length == 0 && dyingRange.location == HFMaxRange(runRange));

        if (HFRangeIsSubrangeOfRange(runRange, dyingRange)) {
            /* This run is toast */
            newRange = (HFRange){0, 0};
        } else if (HFRangeIsSubrangeOfRange(dyingRange, runRange) && !insertionAtRunBeginning && !insertionAtRunEnd) {
            /* The replaced range is wholly contained within this run, so expand the run. The location doesn't need to change. */
            newRange.location = runRange.location;
            newRange.length = HFSum(HFSubtract(runRange.length, dyingRange.length), replacementLength);
        } else if (HFMaxRange(dyingRange) <= runRange.location || insertionAtRunBeginning) {
            /* The dying range is wholly before this run, so adjust the run location. The length doesn't need to change. */
            newRange.length = runRange.length;
            newRange.location = HFSum(HFSubtract(runRange.location, dyingRange.length), replacementLength);
        } else if (dyingRange.location >= HFMaxRange(runRange) || insertionAtRunEnd) {
            /* The dying range is wholly after this run, so nothing to do */
            newRange = runRange;
        } else {
            /* The range must intersect */
            HFRange intersection = HFIntersectionRange(dyingRange, runRange);
            HFASSERT(intersection.length > 0);
            
            /* We intersect the range that's being deleted. Figure out where we should be preserved (if at all). */
            HFRange leftRemainingRange = {0, 0}, rightRemainingRange = {0, 0};
            if (runRange.location < intersection.location) {
                leftRemainingRange = HFRangeMake(runRange.location, HFSubtract(intersection.location, runRange.location));
            }
            if (HFMaxRange(runRange) > HFMaxRange(intersection)) {
                rightRemainingRange = HFRangeMake(HFMaxRange(intersection), HFSubtract(HFMaxRange(runRange), HFMaxRange(intersection)));
            }
            
            /* Now we have up to two ranges. Pick the longer one */
            newRange = (leftRemainingRange.length >= rightRemainingRange.length ? leftRemainingRange : rightRemainingRange);
            
            /* One range must be non-empty, otherwise we would have fallen into one of the tests above */
            HFASSERT(newRange.length > 0);
            
            /* The new range location is the smaller of the dying range location and the remaining range location */
            newRange.location = MIN(newRange.location, dyingRange.location + replacementLength);
        }
        
        HFASSERT([nodesToReplace objectForKey:node] == nil);
        if (newRange.length == 0) {
            /* Deleted */
            [nodesToReplace setObject:null forKey:node];
        } else if (HFRangeEqualsRange(newRange, runRange)) {
            /* No change */
        } else {
            HFByteRangeAttributeArrayNode *newNode = [[HFByteRangeAttributeArrayNode alloc] initWithAttribute:node->attribute range:newRange];
            [nodesToReplace setObject:newNode forKey:node];
        }
        
        /* Continue */
        return (BOOL)YES;
    }];
    
    /* Apply our replacements */
    NSEnumerator *dyingNodes = [nodesToReplace keyEnumerator];
    HFByteRangeAttributeArrayNode *dyingNode;
    while ((dyingNode = [dyingNodes nextObject])) {
        HFByteRangeAttributeArrayNode *replacementNodeOrNULL = [nodesToReplace objectForKey:dyingNode];
        
        /* Remove existing node */
        [atree removeNode:dyingNode];
        removeFromDictionaryOfSets(attributesToNodes, dyingNode->attribute, dyingNode);
        
        /* Add any replacement */
        if (replacementNodeOrNULL != null) {
            [atree insertNode:replacementNodeOrNULL];
            insertIntoDictionaryOfSets(attributesToNodes, replacementNodeOrNULL->attribute, replacementNodeOrNULL);
        }
    }
    
    } // @autoreleasepool
}

- (id)mutableCopyWithZone:(NSZone *)zone {
    HFAnnotatedTreeByteRangeAttributeArray *result = [[[self class] alloc] init];
    result->atree = [atree mutableCopyWithZone:zone];
    [result populateAttributesToNodes:result->attributesToNodes];
    VERIFY_INTEGRITY(self);
    VERIFY_INTEGRITY(result);
    return result;
}

- (BOOL)isEmpty {
    return [atree isEmpty];
}

- (NSEnumerator *)attributeEnumerator {
    return [[HFAnnotatedTreeByteRangeAttributeArrayEnumerator alloc] initWithNode:[atree firstNode]];
}

@end

@implementation HFAnnotatedTreeByteRangeAttributeArrayEnumerator

- (instancetype)initWithNode:(HFByteRangeAttributeArrayNode *)val {
    self = [super init];
    node = val;
    return self;
}

- (id)nextObject {
    id result = [node attribute];
    node = [node nextNode];
    return result;
}

@end
