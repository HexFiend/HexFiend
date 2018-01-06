//
//  TreeEntry.h
//  BTree
//
//  Created by peter on 2/6/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "HFBTree.h"

@interface TreeEntry : NSObject {
    @public
    HFBTreeIndex length;
    NSString *value;
}

+ (instancetype)entryWithLength:(HFBTreeIndex)len value:(NSString *)val;
- (instancetype)initWithLength:(HFBTreeIndex)len value:(NSString *)val;
- (unsigned long long)length;

@end
