//
//  HFObjectGraph.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFObjectGraph.h"
#import "HFTest.h"
#import <HexFiend/HFFrameworkPrefix.h>
#import <HexFiend/HFAssert.h>

@implementation HFObjectGraph
{
    NSMapTable<id, NSMutableSet*> *graph;
}

- (instancetype)init {
    if ((self = [super init]) != nil) {
        graph = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

- (void)addDependency:depend forObject:obj {
    REQUIRE_NOT_NULL(depend);
    REQUIRE_NOT_NULL(obj);
    NSMutableSet *dependencies = [graph objectForKey:obj];
    if (! dependencies) {
        dependencies = [[NSMutableSet alloc] init];
        [graph setObject:dependencies forKey:obj];
    }
    [dependencies addObject:depend];
}

- (BOOL)object:obj hasDependency:depend {
    REQUIRE_NOT_NULL(depend);
    REQUIRE_NOT_NULL(obj);
    BOOL result = NO;
    NSMutableSet *dependencies = [graph objectForKey:obj];
    result = [dependencies containsObject:depend];
    return result;
}

- (NSSet *)dependenciesForObject:obj {
    REQUIRE_NOT_NULL(obj);
    return [graph objectForKey:obj];
}

static void tarjan(HFObjectGraph *self, id node, CFMutableDictionaryRef vIndexes, CFMutableDictionaryRef vLowlinks, NSMutableArray *stack, NSUInteger *index, id givenDependencies/*NSSet or NSArray*/, NSMutableArray *resultStronglyConnectedComponents) {
    NSUInteger vLowlink = *index;
    CFDictionarySetValue(vIndexes, (const void *)node, (void *)*index);
    CFDictionarySetValue(vLowlinks, (const void *)node, (void *)vLowlink);
    ++*index;
    [stack addObject:node];
    
    id dependencies = (givenDependencies ? givenDependencies : [self dependenciesForObject:node]);
    for(id successor in dependencies) {
        NSUInteger successorIndex = -1;
        BOOL successorIndexIsDefined = CFDictionaryGetValueIfPresent(vIndexes, (const void *)successor, (const void **)&successorIndex);
        if (! successorIndexIsDefined) {
            tarjan(self, successor, vIndexes, vLowlinks, stack, index, NULL, resultStronglyConnectedComponents);
            HFASSERT(CFDictionaryContainsKey(vLowlinks, (const void *)node) && CFDictionaryContainsKey(vLowlinks, (const void *)successor));
            NSUInteger possibleNewLowlink = (NSUInteger)CFDictionaryGetValue(vLowlinks, (const void *)successor);
            if (possibleNewLowlink < vLowlink) {
                vLowlink = possibleNewLowlink;
                CFDictionarySetValue(vLowlinks, (const void *)node, (void *)vLowlink);
            }
        }
        else if ([stack indexOfObjectIdenticalTo:successor] != NSNotFound) {
            if (successorIndex < vLowlink) {
                vLowlink = successorIndex;
                CFDictionarySetValue(vLowlinks, (const void *)node, (void *)vLowlink);
            }
        }
    }
    
    HFASSERT(vLowlink == (NSUInteger)CFDictionaryGetValue(vLowlinks, (const void *)node));
    if (vLowlink == (NSUInteger)CFDictionaryGetValue(vIndexes, (const void *)node)) {
        NSMutableArray *component = [[NSMutableArray alloc] init];
        id someNode;
        do {
            someNode = [stack lastObject];
            [component addObject:someNode];
            [stack removeLastObject];
        } while (someNode != node);
        [resultStronglyConnectedComponents addObject:component];
    }
}

- (NSArray *)stronglyConnectedComponentsForObjects:(NSArray *)objects {
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger index = 0;
    NSMutableArray *stack = [[NSMutableArray alloc] init];
    CFMutableDictionaryRef vIndexes = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    CFMutableDictionaryRef vLowlinks = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    NSString *magicStartNode = [[NSString alloc] initWithCString:"Magic Start Node" encoding:NSASCIIStringEncoding];
    tarjan(self, magicStartNode, vIndexes, vLowlinks, stack, &index, objects, result);
    
    /* Remove the one array containing magicStartNode */
    HFASSERT([[result lastObject] count] == 1 && [result lastObject][0] == magicStartNode);
    [result removeLastObject];
    
    CFRelease(vIndexes);
    CFRelease(vLowlinks);
    return result;
}

static void topologicallySort(HFObjectGraph *self, id object, NSMutableArray *result, NSHashTable *pending, NSHashTable *visited) {
    REQUIRE_NOT_NULL(object);
    HFASSERT(! [pending containsObject:object]);
    HFASSERT(! [visited containsObject:object]);
    HFASSERT([result count] == [visited count]);
    NSSet *dependencies = [self dependenciesForObject:object];
    if ([dependencies count] > 0) {
        [pending addObject:object];
        for (id dependency in dependencies) {
            HFASSERT(![pending containsObject:dependency]);
            if (! [visited containsObject:dependency]) {
                topologicallySort(self, dependency, result, pending, visited);
                HFASSERT([visited containsObject:dependency]);
                HFASSERT(![pending containsObject:dependency]);
            }
        }
        HFASSERT([pending containsObject:object]);
        [pending removeObject:object];
    }
    [result addObject:object];
    [visited addObject:object];
}

- (NSArray *)topologicallySortObjects:(NSArray *)objects {
    REQUIRE_NOT_NULL(objects);
    NSUInteger count = [objects count];
    HFASSERT([[NSSet setWithArray:objects] count] == [objects count]);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    NSHashTable *visitedSet = [NSHashTable weakObjectsHashTable];
    NSHashTable *pendingSet = [NSHashTable weakObjectsHashTable];
    for(id object in objects) {
        topologicallySort(self, object, result, pendingSet, visitedSet);
    }
    HFASSERT([result count] == count);
    HFASSERT([[NSSet setWithArray:objects] isEqual:[NSSet setWithArray:result]]);
    return result;
}

#if HFUNIT_TESTS

/* Methods and functions starting with "naive" are meant to be used for verifying the correctness of more sophisticated algorithms. */

static BOOL naiveSearch(HFObjectGraph *self, id start, id goal, NSHashTable *visitedSet) {
    if (start == goal) return YES;
    if ([visitedSet containsObject:start]) {
        return NO;
    }
    [visitedSet addObject:start];
    NSMutableSet *dependencies = [self->graph objectForKey:start];
    for (id dependency in dependencies) {
        if (naiveSearch(self, dependency, goal, visitedSet)) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)naivePathFrom:(id)obj1 to:(id)obj2 {
    REQUIRE_NOT_NULL(obj1);
    REQUIRE_NOT_NULL(obj2);
    if (obj1 == obj2) return YES;

    NSHashTable *objectSet = [NSHashTable weakObjectsHashTable];
    BOOL result = naiveSearch(self, obj1, obj2, objectSet);
    return result;
}

- (NSArray *)naiveStronglyConnectedComponentsForObjects:(NSArray *)objects {
    NSMutableArray *result = [NSMutableArray array];
    /* A super-lame naive algorithm for finding all the strongly connected components of a graph. */
    NSMapTable<id, NSMutableArray*> *components = [NSMapTable weakToStrongObjectsMapTable];
    for(id obj1 in objects) {
        NSMutableArray *loop = [components objectForKey:obj1];
        if (! loop) {
            loop = [NSMutableArray array];
            [components setObject:loop forKey:obj1];
        }
        for(id obj2 in objects) {
            if (! [loop containsObject:obj2] && [self naivePathFrom:obj1 to:obj2] && [self naivePathFrom:obj2 to:obj1]) {
                [components setObject:loop forKey:obj2];
                [loop addObject:obj2];
            }
        }
    }
    for (NSMutableArray *value in [components objectEnumerator]) {
        if ([result indexOfObjectIdenticalTo:value] == NSNotFound) {
            [result addObject:value];
        }
    }
    return result;
}

/* Converts an array nested to the given depth to sets nested to the given depth.  Requires that the array values are all unique. */
static NSSet *arraysToSets(NSArray *array, NSUInteger depth) {
    HFASSERT(depth >= 1);
    id result = nil;
    if (depth == 1) {
        result = [NSSet setWithArray:array];
    }
    else {
        result = [NSMutableSet setWithCapacity:[array count]];
        for(id value in array) {
            [result addObject:arraysToSets(value, depth - 1)];
        }
    }
    HFASSERT([result count] == [array count]);
    return result;
}

+ (void)runHFUnitTests:(HFRegisterTestFailure_b)registerFailure {
    NSUInteger outer;
    for (outer = 0; outer < 100; outer++) @autoreleasepool {
        HFObjectGraph *graph = [[self alloc] init];
        NSUInteger i, objectCount = 2 + (random() % (100 - 2));
        NSUInteger connectionCount = random() % (objectCount * 2);
        NSMutableArray *objects = [NSMutableArray array];
        for (i=0; i < objectCount; i++) [objects addObject:@(i)];
        for (i=0; i < connectionCount; i++) {
            id object1 = objects[random() % objectCount];
            id object2 = objects[random() % objectCount];
            if (! [graph object:object1 hasDependency:object2]) {
                [graph addDependency:object2 forObject:object1];
            }
        }
        
        id naive = [graph naiveStronglyConnectedComponentsForObjects:objects];
        id tarjan = [graph stronglyConnectedComponentsForObjects:objects];
        
        HFTEST([arraysToSets(naive, 2) isEqual:arraysToSets(tarjan, 2)], @"Error in HFObjectGraph tests!\n\tnaive: %@\n\ttarjan: %@\n", naive, tarjan);
    }
}
#endif

@end
