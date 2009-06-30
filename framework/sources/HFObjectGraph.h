//
//  HFObjectGraph.h
//  HexFiend_2
//
//  Created by Peter Ammon on 3/9/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFObjectGraph : NSObject {
    __strong CFMutableDictionaryRef graph;
    NSMutableArray *containedObjects;
}

- (void)addDependency:depend forObject:obj;
- (NSSet *)dependenciesForObject:obj;
- (BOOL)object:obj hasDependency:depend;

/* Returns an NSArray of NSArrays of objects representing the strongly connected components of the graph, via Tarjan's algorithm. */
- (NSArray *)stronglyConnectedComponentsForObjects:(NSArray *)objects;

/* Returns an NSArray of the objects topologically sorted via the dependencies in self.  self must be acyclic; if there is a cycle an exception will be thrown. */
- (NSArray *)topologicallySortObjects:(NSArray *)objects;

@end
