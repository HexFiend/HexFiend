//
//  HFObjectGraph.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFObjectGraph : NSObject

- (void)addDependency:depend forObject:obj;
- (nullable NSSet *)dependenciesForObject:obj;
- (BOOL)object:obj hasDependency:depend;

/* Returns an NSArray of NSArrays of objects representing the strongly connected components of the graph, via Tarjan's algorithm. */
- (NSArray *)stronglyConnectedComponentsForObjects:(nullable NSArray *)objects;

/* Returns an NSArray of the objects topologically sorted via the dependencies in self.  self must be acyclic; if there is a cycle an exception will be thrown. */
- (NSArray *)topologicallySortObjects:(NSArray *)objects;

@end

NS_ASSUME_NONNULL_END
