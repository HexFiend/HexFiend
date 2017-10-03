//
//  HFSharedMemoryByteSlice.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

NS_ASSUME_NONNULL_BEGIN

/*! @class HFSharedMemoryByteSlice
    @brief A subclass of HFByteSlice for working with data stored in memory.
    
    HFSharedMemoryByteSlice is a subclass of HFByteSlice that represents a portion of data from memory, e.g. typed or pasted in by the user.  The term "shared" refers to the ability for mutiple HFSharedMemoryByteSlices to reference the same NSData; it does not mean that the data is in shared memory or shared between processes.
    
    Instances of HFSharedMemoryByteSlice are immutable (like all instances of HFByteSlice).  However, to support efficient typing, the backing data is an instance of NSMutableData that may be grown.  A referenced range of the NSMutableData will never have its contents changed, but it may be allowed to grow larger, so that the data does not have to be copied merely to append a single byte.  This is implemented by overriding the  -byteSliceByAppendingSlice: method of HFByteSlice.
*/
@interface HFSharedMemoryByteSlice : HFByteSlice {
    NSMutableData *data;
    NSUInteger offset;
    NSUInteger length;
    unsigned char inlineTailLength;
    unsigned char inlineTail[15]; //size chosen to exhaust padding of 32-byte allocator
}

// copies the data
- (instancetype)initWithUnsharedData:(NSData *)data;

// retains, does not copy
- (instancetype)initWithData:(NSMutableData *)data;
- (instancetype)initWithData:(NSMutableData *)data offset:(NSUInteger)offset length:(NSUInteger)length;

@end

NS_ASSUME_NONNULL_END
