//
//  HFTavlTreeByteArrayEnumerator.m
//  HexFiend_2
//
//  Created by peter on 9/19/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFTavlTreeByteArrayEnumerator.h>
#import <HexFiend/HFByteArrayPiece.h>

@implementation HFTavlTreeByteArrayEnumerator

- initWithByteArray:(HFTavlTreeByteArray *)array tree:(struct tavltree *)treeParam {
    REQUIRE_NOT_NULL(array);
    [super init];
    byteArray = [array retain];
    tree = treeParam;
    node = tavl_reset(tree);
    return self;
}

- (id)nextObject {
    HFByteArrayPiece* arrayPiece = nil;
    node = tavl_succ(node);
    if (node) {
        tavl_getdata(tree, node, &arrayPiece);
        REQUIRE_NOT_NULL(arrayPiece);
    }
    else {
        [byteArray release];
        byteArray = nil;
    }
    return [arrayPiece byteSlice];
}

- (void)dealloc {
    [byteArray release];
    [super dealloc];
}

@end
