//
//  HFByteArrayPiece.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFByteSlice;

@interface HFByteArrayPiece : NSObject {
    @private
    HFByteSlice *slice;
    @public
    HFRange range;
}

- initWithSlice:(HFByteSlice *)slice offset:(unsigned long long)offset;
- (unsigned long long)offset;
- (unsigned long long)length;
- (void)setOffset:(unsigned long long)offset;
- (HFByteSlice *)byteSlice;

@end
