//
//  TavlTreeByteArray.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArray.h>


@interface HFTavlTreeByteArray : HFByteArray {
    __strong struct tavltree *tree;
}

- init;

//for unit testing
- (BOOL)offsetsAreCorrect;

@end
