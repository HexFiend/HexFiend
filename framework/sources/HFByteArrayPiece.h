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
    HFRange pieceRange;
}

- initWithSlice:(HFByteSlice *)slice offset:(unsigned long long)offset;
- (unsigned long long)offset;
- (unsigned long long)length;
- (void)setOffset:(unsigned long long)offset;
- (HFByteSlice *)byteSlice;

- (HFRange *)tavl_key;

//constructs two new ByteArrayPieces on either side of range
//returns nil by reference if that array piece would hold no data
//range must be wholly contained within this piece
- (void)constructNewArrayPiecesAboutRange:(HFRange)range first:(HFByteArrayPiece**)first second:(HFByteArrayPiece**)second;

- (BOOL)fastPathAppendByteSlice:(HFByteSlice *)slice atLocation:(unsigned long long)location;

@end
