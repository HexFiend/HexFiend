//
//  HFFullMemoryByteSlice.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

/*! @class HFFullMemoryByteSlice

    @brief A simple subclass of HFByteSlice that wraps an NSData.  For most uses, prefer HFSharedMemoryByteSlice.
*/
@interface HFFullMemoryByteSlice : HFByteSlice {
    NSData *data;
}

/*! Init with a given NSData, which is copied via the \c -copy message. */
- (instancetype)initWithData:(NSData *)val;

@end
