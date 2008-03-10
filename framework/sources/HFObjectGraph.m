//
//  HFObjectGraph.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFObjectGraph.h>


@implementation HFObjectGraph

- init {
    [super init];
    graph = (__strong CFMutableDictionaryRef)CFMakeCollectable(CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
    return self;
}

- (void)dealloc {
    CFRelease(graph);
    [super dealloc];
}

- (void)addDependency:depend forObject:obj {
    REQUIRE_NOT_NULL(depend);
    REQUIRE_NOT_NULL(obj);
    NSMutableArray *dependencies = (NSMutableArray *)CFDictionaryGetValue(graph, obj);
    if (! dependencies) {
        dependencies = [[NSMutableArray alloc] init];
        CFDictionarySetValue(graph, obj, dependencies);
        [dependencies release];
    }
    HFASSERT([dependencies indexOfObjectIdenticalTo:depend] == NSNotFound);
    [dependencies addObject:depend];
}

- (BOOL)object:obj hasDependency:depend {
    REQUIRE_NOT_NULL(depend);
    REQUIRE_NOT_NULL(obj);
    BOOL result = NO;
    NSMutableArray *dependencies = (NSMutableArray *)CFDictionaryGetValue(graph, obj);
    if (dependencies) {
        result = ([dependencies indexOfObjectIdenticalTo:depend] != NSNotFound);
    }
    return result;
}

- (NSArray *)dependenciesForObject:obj {
    REQUIRE_NOT_NULL(obj);
    NSArray *result = (NSArray *)CFDictionaryGetValue(graph, obj);
    return result ? result : [NSArray array];
}

static void tarjan(HFObjectGraph *self, id node, CFMutableDictionaryRef vIndexes, CFMutableDictionaryRef vLowlinks, NSMutableArray *stack, NSUInteger *index, NSArray *givenDependencies, NSMutableArray *resultStronglyConnectedComponents) {
    NSUInteger vLowlink = *index;
    CFDictionarySetValue(vIndexes, node, (void *)*index);
    CFDictionarySetValue(vLowlinks, node, (void *)vLowlink);
    ++*index;
    [stack addObject:node];
    
    NSArray *dependencies = (givenDependencies ? givenDependencies : [self dependenciesForObject:node]);
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



#if ! NDEBUG


/* Methods and functions starting with "naive" are meant to be used for verifying more sophisticated algorithms. */

static BOOL naiveSearch(HFObjectGraph *self, id start, id goal, CFMutableSetRef visited) {
    if (start == goal) return YES;
    if (CFSetContainsValue(visited, start)) return NO;
    CFSetAddValue(visited, start);
    FOREACH(id, dependency, [self dependenciesForObject:start]) {
        if (naiveSearch(self, dependency, goal, visited)) return YES;
    }
    return NO;
}

- (BOOL)naivePathFrom:(id)obj1 to:(id)obj2 {
    REQUIRE_NOT_NULL(obj1);
    REQUIRE_NOT_NULL(obj2);
    if (obj1 == obj2) return YES;
    
    CFMutableSetRef set = CFSetCreateMutable(NULL, 0, NULL);
    BOOL result = naiveSearch(self, obj1, obj2, set);
    CFRelease(set);
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
        for (i=0; i < objectCount; i++) [objects addObject:[NSNumber numberWithUnsignedInt:i]];
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
