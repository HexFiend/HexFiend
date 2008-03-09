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
    NSMutableArray *dependencies = CFDictionaryGetValue(graph, obj);
    if (! dependencies) {
        dependencies = [[NSMutableArray alloc] init];
        CFDictionarySetValue(graph, obj, dependencies);
        [dependencies release];
    }
    HFASSERT([dependencies indexOfObjectIdenticalTo:depend] == NSNotFound);
    [dependencies addObject:depend];
}

- (NSArray *)dependenciesForObject:obj {
    REQUIRE_NOT_NULL(obj);
    NSArray *result = (NSArray *)CFDictionaryGetValue(graph, obj);
    return result ? result : [NSArray array];
}

@end
