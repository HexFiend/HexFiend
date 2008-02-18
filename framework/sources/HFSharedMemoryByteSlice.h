//
//  HFSharedMemoryByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 2/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

@class HFSharedData;

@interface HFSharedMemoryByteSlice : HFByteSlice {
    HFSharedData *data;
    NSUInteger offset;
    NSUInteger length;
    unsigned char inlineTailLength;
    unsigned char inlineTail[15]; //size chosen to exhaust padding of 32-byte allocator
}

- initWithUnsharedData:(NSData *)data;

// retains, does not copy
- initWithData:(HFSharedData *)data;
- initWithData:(HFSharedData *)data offset:(NSUInteger)offset length:(NSUInteger)length;

- initWithSharedData:(HFSharedData *)data offset:(NSUInteger)off length:(NSUInteger)len tail:(const void *)tail tailLength:(NSUInteger)tailLen;

@end
