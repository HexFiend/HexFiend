//
//  TreeEntry.m
//  BTree
//
//  Created by peter on 2/6/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "TreeEntry.h"

@implementation TreeEntry

- (instancetype)initWithLength:(HFBTreeIndex)len value:(NSString *)val {
    length = len;
    value = [val copy];
    return self;
}

+ (instancetype)entryWithLength:(HFBTreeIndex)len value:(NSString *)val {
    TreeEntry *result = [[self alloc] init];
    result->length = len;
    result->value = [val copy];
    return result;
}

- (unsigned long long)length {
    return length;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p (%@)>", NSStringFromClass([self class]), self, value];
}

@end
