//
//  TreeEntry.m
//  BTree
//
//  Created by peter on 2/6/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "TreeEntry.h"

@implementation TreeEntry

- (id)initWithLength:(HFBTreeIndex)len value:(NSString *)val {
    length = len;
    value = [val copy];
    return self;
}

+ entryWithLength:(HFBTreeIndex)len value:(NSString *)val {
    TreeEntry *result = [[[self alloc] init] autorelease];
    result->length = len;
    result->value = [val copy];
    return result;
}

- (unsigned long long)length {
    return length;
}

- (void)dealloc {
    [value release];
    [super dealloc];
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p (%@)>", NSStringFromClass([self class]), self, value];
}

- (id)retain {
    HFAtomicIncrement(&rc, NO);
    return self;
}

- (void)release {
    NSUInteger result = HFAtomicDecrement(&rc, NO);
    if (result == (NSUInteger)(-1)) {
        [self dealloc];
    }
}

- (NSUInteger)retainCount {
    return 1 + rc;
}

@end
