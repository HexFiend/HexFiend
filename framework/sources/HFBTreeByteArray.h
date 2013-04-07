//
//  HFBTreeByteArray.h
//  HexFiend_2
//
//  Created by peter on 4/28/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArray.h>

@class HFBTree;

/*! @class HFBTreeByteArray
@brief The principal efficient implementation of HFByteArray.

HFBTreeByteArray is an efficient subclass of HFByteArray that stores @link HFByteSlice HFByteSlices@endlink, using a 10-way B+ tree.  This allows for insertion, deletion, and searching in approximately log-base-10 time.

Create an HFBTreeByteArray via \c -init.  It has no methods other than those on HFByteArray.
*/

@interface HFBTreeByteArray : HFByteArray {
@private
    HFBTree *btree;
}

/*! Designated initializer for HFBTreeByteArray.
*/
- (id)init;

@end
