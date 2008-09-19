//
//  HFTavlTreeByteArrayEnumerator.h
//  HexFiend_2
//
//  Created by peter on 9/19/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFTavlTreeByteArray.h>
#import <HexFiend/tavltree.h>

@class HFTavlTreeByteArray;

@interface HFTavlTreeByteArrayEnumerator : NSEnumerator {
    TAVL_nodeptr node;
    struct tavltree *tree;
    HFTavlTreeByteArray *byteArray;
}

- initWithByteArray:(HFTavlTreeByteArray *)array tree:(struct tavltree *)treeParam;

@end
