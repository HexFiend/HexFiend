//
//  HFObjectGraph.h
//  HexFiend_2
//
//  Created by Peter Ammon on 3/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFObjectGraph : NSObject {
    __strong CFMutableDictionaryRef graph;
	NSMutableArray *containedObjects;
}

- (void)addDependency:depend forObject:obj;
- (NSArray *)dependenciesForObject:obj;
- (BOOL)object:obj hasDependency:depend;

/* Returns an NSArray of NSArrays of objects representing the strongly connected components of the graph, via Tarjan's algorithm. */
- (NSArray *)stronglyConnectedComponentsForObjects:(NSArray *)objects;

@end
