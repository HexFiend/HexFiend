//
//  HFByteArray.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFByteSlice;

@interface HFByteArray : NSObject {

}

- (NSArray *)byteSlices;
- (unsigned long long)length;
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range;
- (void)deleteBytesInRange:(HFRange)range;
- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange;

@end
