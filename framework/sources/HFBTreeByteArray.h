//
//  HFBTreeByteArray.h
//  HexFiend_2
//
//  Created by peter on 4/28/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArray.h>

@class HFBTree;

@interface HFBTreeByteArray : HFByteArray {
    HFBTree *btree;
}

- init;

@end
