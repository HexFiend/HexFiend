//
//  HFObjectGraph.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/9/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFObjectGraph.h>


@implementation HFObjectGraph

- init {
    [super init];
    graph = (__strong CFMutableDictionaryRef)CFMakeCollectable(CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks));
    containedObjects = [[NSMutableArray alloc] init]; //containedObjects is necessary to make sure that our key objects are strongly referenced, since we use a NULL-callback dictionary
    return self;
}

- (void)dealloc {
    CFRelease(graph);
    [containedObjects release];
    [super dealloc];
}

- (void)addDependency:depend forObject:obj {
    REQUIRE_NOT_NULL(depend);
    REQUIRE_NOT_NULL(obj);
    NSMutableSet *dependencies = (NSMutableSet *)CFDictionaryGetValue(graph, obj);
    if (! dependencies) {
        dependencies = [[NSMutableSet alloc] init];
        CFDictionarySetValue(graph, obj, dependencies);
        [dependencies release];
        [containedObjects addObject:obj];
    }
    [dependencies addObject:depend];
}

- (BOOL)object:obj hasDependency:depend {
    REQUIRE_NOT_NULL(depend);
    REQUIRE_NOT_NULL(obj);
    BOOL result = NO;
    NSMutableSet *dependencies = (NSMutableSet *)CFDictionaryGetValue(graph, obj);
    result = [dependencies containsObject:depend];
    return result;
}

- (NSSet *)dependenciesForObject:obj {
    REQUIRE_NOT_NULL(obj);
    return (NSSet *)CFDictionaryGetValue(graph, obj);
}

static void tarjan(HFObjectGraph *self, id node, CFMutableDictionaryRef vIndexes, CFMutableDictionaryRef vLowlinks, NSMutableArray *stack, NSUInteger *index, id givenDependencies/*NSSet or NSArray*/, NSMutableArray *resultStronglyConnectedComponents) {
    NSUInteger vLowlink = *index;
    CFDictionarySetValue(vIndexes, node, (void *)*index);
    CFDictionarySetValue(vLowlinks, node, (void *)vLowlink);
    ++*index;
    [stack addObject:node];
    
    id dependencies = (givenDependencies ? givenDependencies : [self dependenciesForObject:node]);
    FOREACH(id, successor, dependencies) {
        NSUInteger successorIndex = -1;
        BOOL successorIndexIsDefined = CFDictionaryGetValueIfPresent(vIndexes, successor, (const void **)&successorIndex);
        if (! successorIndexIsDefined) {
            tarjan(self, successor, vIndexes, vLowlinks, stack, index, NULL, resultStronglyConnectedComponents);
            HFASSERT(CFDictionaryContainsKey(vLowlinks, node) && CFDictionaryContainsKey(vLowlinks, successor));
            NSUInteger possibleNewLowlink = (NSUInteger)CFDictionaryGetValue(vLowlinks, successor);
            if (possibleNewLowlink < vLowlink) {
                vLowlink = possibleNewLowlink;
                CFDictionarySetValue(vLowlinks, node, (void *)vLowlink);
            }
        }
        else if ([stack indexOfObjectIdenticalTo:successor] != NSNotFound) {
            if (successorIndex < vLowlink) {
                vLowlink = successorIndex;
                CFDictionarySetValue(vLowlinks, node, (void *)vLowlink);
            }
        }
    }
    
    HFASSERT(vLowlink == (NSUInteger)CFDictionaryGetValue(vLowlinks, node));
    if (vLowlink == (NSUInteger)CFDictionaryGetValue(vIndexes, node)) {
        NSMutableArray *component = [[NSMutableArray alloc] init];
        id someNode;
        do {
            someNode = [stack lastObject];
            [component addObject:someNode];
            [stack removeLastObject];
        } while (someNode != node);
        [resultStronglyConnectedComponents addObject:component];
        [component release];
    }
}

- (NSArray *)stronglyConnectedComponentsForObjects:(NSArray *)objects {
    NSMutableArray *result = [NSMutableArray array];
    NSUInteger index = 0;
    NSMutableArray *stack = [[NSMutableArray alloc] init];
    CFMutableDictionaryRef vIndexes = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    CFMutableDictionaryRef vLowlinks = CFDictionaryCreateMutable(NULL, 0, NULL, NULL);
    id magicStartNode = [[NSString alloc] initWithCString:"Magic Start Node" encoding:NSASCIIStringEncoding];
    tarjan(self, magicStartNode, vIndexes, vLowlinks, stack, &index, objects, result);
    
    /* Remove the one array containing magicStartNode */
    HFASSERT([[result lastObject] count] == 1 && [[result lastObject] objectAtIndex:0] == magicStartNode);
    [result removeLastObject];
    
    [magicStartNode release];
    CFRelease(vIndexes);
    CFRelease(vLowlinks);
    [stack release];
    return result;
}

static void topologicallySort(HFObjectGraph *self, id object, NSMutableArray *result, CFMutableSetRef pending, CFMutableSetRef visited) {
    REQUIRE_NOT_NULL(object);
    HFASSERT(! CFSetContainsValue(pending, object));
    HFASSERT(! CFSetContainsValue(visited, object));
    HFASSERT((CFIndex)[result count] == CFSetGetCount(visited));
    NSSet *dependencies = [self dependenciesForObject:object];
    NSUInteger i, dependencyCount = [dependencies count];
    if (dependencyCount > 0) {
        CFSetAddValue(pending, object);
        NEW_ARRAY(id, dependencyArray, dependencyCount);
        CFSetGetValues((CFSetRef)dependencies, (const void **)dependencyArray);
        for (i=0; i < dependencyCount; i++) {
            HFASSERT(!CFSetContainsValue(pending, dependencyArray[i]));
            if (! CFSetContainsValue(visited, dependencyArray[i])) {
                topologicallySort(self, dependencyArray[i], result, pending, visited);
                HFASSERT(CFSetContainsValue(visited, dependencyArray[i]));
                HFASSERT(!CFSetContainsValue(pending, dependencyArray[i]));
            }
        }
        FREE_ARRAY(dependencyArray);
        HFASSERT(CFSetContainsValue(pending, object));
        CFSetRemoveValue(pending, object);
    }
    [result addObject:object];
    CFSetAddValue(visited, object);
}

- (NSArray *)topologicallySortObjects:(NSArray *)objects {
    REQUIRE_NOT_NULL(objects);
    NSUInteger count = [objects count];
    HFASSERT([[NSSet setWithArray:objects] count] == [objects count]);
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:count];
    CFMutableSetRef visitedSet = CFSetCreateMutable(NULL, count, NULL);
    CFMutableSetRef pendingSet = CFSetCreateMutable(NULL, count, NULL);
    FOREACH(id, object, objects) {
        topologicallySort(self, object, result, pendingSet, visitedSet);
    }
    CFRelease(visitedSet);
    CFRelease(pendingSet);
    HFASSERT([result count] == count);
    HFASSERT([[NSSet setWithArray:objects] isEqual:[NSSet setWithArray:result]]);
    return result;
}

#if HFUNIT_TESTS

/* Methods and functions starting with "naive" are meant to be used for verifying the correctness of more sophisticated algorithms. */

static BOOL naiveSearch(HFObjectGraph *self, id start, id goal, id *visitedSet, NSUInteger *visitedSetCount) {
    if (start == goal) return YES;
    NSUInteger i, visitedSetTempCount = *visitedSetCount;
    for (i=0; i < visitedSetTempCount; i++) if (visitedSet[i] == start) return NO;
    visitedSet[visitedSetTempCount++] = start;
    *visitedSetCount = visitedSetTempCount;
    CFSetRef dependencies = CFDictionaryGetValue(self->graph, start);
    if (dependencies) {
        NSUInteger max = CFSetGetCount(dependencies);
        NEW_ARRAY(id, dependencyObjects, max);
        CFSetGetValues(dependencies, (const void **)dependencyObjects);
        for (i=0; i < max; i++) {
            if (naiveSearch(self, dependencyObjects[i], goal, visitedSet, visitedSetCount)) return YES;
        }
        FREE_ARRAY(dependencyObjects);
    }
    return NO;
}

- (BOOL)naivePathFrom:(id)obj1 to:(id)obj2 {
    REQUIRE_NOT_NULL(obj1);
    REQUIRE_NOT_NULL(obj2);
    if (obj1 == obj2) return YES;
    
    //    CFMutableSetRef set = CFSetCreateMutable(NULL, 0, NULL);
    NSUInteger objectCount = [containedObjects count];
    NSUInteger visitedSetCount = 0;
    NEW_ARRAY(id, objectSet, objectCount);
    BOOL result = naiveSearch(self, obj1, obj2, objectSet, &visitedSetCount);
    FREE_ARRAY(objectSet);
    return result;
}

static void collectDictionaryValues(const void *key, const void *value, void *context) {
    USE(key);
    if ([(id)context indexOfObjectIdenticalTo:(id)value] == NSNotFound) [(id)context addObject:(id)value];
}

- (NSArray *)naiveStronglyConnectedComponentsForObjects:(NSArray *)objects {
    NSMutableArray *result = [NSMutableArray array];
    /* A super-lame naive algorithm for finding all the strongly connected components of a graph. */
    CFMutableDictionaryRef components = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    FOREACH(id, obj1, objects) {
        NSMutableArray *loop = (id)CFDictionaryGetValue(components, obj1);
        if (! loop) {
            loop = [NSMutableArray array];
            CFDictionarySetValue(components, obj1, loop);
        }
        FOREACH(id, obj2, objects) {
            if (! [loop containsObject:obj2] && [self naivePathFrom:obj1 to:obj2] && [self naivePathFrom:obj2 to:obj1]) {
                CFDictionarySetValue(components, obj2, loop);
                [loop addObject:obj2];
            }
        }
    }
    CFDictionaryApplyFunction(components, collectDictionaryValues, result);
    CFRelease(components);
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
        FOREACH(id, value, array) {
            [result addObject:arraysToSets(value, depth - 1)];
        }
    }
    HFASSERT([result count] == [array count]);
    return result;
}

+ (void)runTests {
    NSUInteger outer;
    for (outer = 0; outer < 100; outer++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        HFObjectGraph *graph = [[self alloc] init];
        NSUInteger i, objectCount = 2 + (random() % (100 - 2));
        NSUInteger connectionCount = random() % (objectCount * 2);
        NSMutableArray *objects = [NSMutableArray array];
        for (i=0; i < objectCount; i++) [objects addObject:[NSNumber numberWithUnsignedLong:i]];
        for (i=0; i < connectionCount; i++) {
            id object1 = [objects objectAtIndex: random() % objectCount];
            id object2 = [objects objectAtIndex: random() % objectCount];
            if (! [graph object:object1 hasDependency:object2]) {
                [graph addDependency:object2 forObject:object1];
            }
        }
        
        id naive = [graph naiveStronglyConnectedComponentsForObjects:objects];
        id tarjan = [graph stronglyConnectedComponentsForObjects:objects];
        
        if (! [arraysToSets(naive, 2) isEqual:arraysToSets(tarjan, 2)]) {
            printf("Error in HFObjectGraph tests!\n\tnaive: %s\n\ttarjan: %s\n", [[naive description] UTF8String], [[tarjan description] UTF8String]);
            exit(EXIT_FAILURE);
        }
        
        [graph release];
        [pool drain];
    }
}

+ (void)initialize {
    if (self == [HFObjectGraph class]) {
        [self runTests];
    }
}
#endif

@end
