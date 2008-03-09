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
}

- (void)addDependency:depend forObject:obj;
- (NSArray *)dependenciesForObject:obj;

@end
