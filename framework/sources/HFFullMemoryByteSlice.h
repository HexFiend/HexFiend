//
//  HFFullMemoryByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

/*!
@class HFFullMemoryByteArray

  HFFullMemoryByteSlice is a simple subclass of HFByteSlice that wraps an NSData.  It is not especially efficient.  Prefer using HFSharedMemoryByteSlice instead.
*/
@interface HFFullMemoryByteSlice : HFByteSlice {
    NSData *data;
}

/*! Init with a given NSData, which is copied. */
- initWithData:(NSData *)val;

@end
