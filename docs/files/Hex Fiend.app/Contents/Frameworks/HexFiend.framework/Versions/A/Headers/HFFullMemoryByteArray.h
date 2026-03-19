//
//  HFFullMemoryByteArray.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArray.h>

/*!
  @class HFFullMemoryByteArray
  @brief A naive subclass of HFByteArray suitable mainly for testing.  Use HFBTreeByteArray instead.

  HFFullMemoryByteArray is a simple subclass of HFByteArray that does not store any byte slices.  Because it stores all data in an NSMutableData, it is not efficient.  It is mainly useful as a naive implementation for testing.  Use HFBTreeByteArray instead.
*/
@interface HFFullMemoryByteArray : HFByteArray {
    NSMutableData *data;
}


@end
