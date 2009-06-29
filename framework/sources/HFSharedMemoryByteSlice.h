//
//  HFSharedMemoryByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 2/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

@interface HFSharedMemoryByteSlice : HFByteSlice {
    NSMutableData *data;
    NSUInteger offset;
    NSUInteger length;
    unsigned char inlineTailLength;
    unsigned char inlineTail[15]; //size chosen to exhaust padding of 32-byte allocator
}

// copies the data
- initWithUnsharedData:(NSData *)data;

// retains, does not copy
- initWithData:(NSMutableData *)data;
- initWithData:(NSMutableData *)data offset:(NSUInteger)offset length:(NSUInteger)length;

// Attempts to create a new slice by efficiently appending data.  This returns nil if it cannot be done efficiently.
- byteSliceByAppendingSlice:(HFByteSlice *)slice;

- initWithSharedData:(NSMutableData *)data offset:(NSUInteger)off length:(NSUInteger)len tail:(const void *)tail tailLength:(NSUInteger)tailLen;

@end
