//
//  HFByteArray.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFByteSlice, HFProgressTracker;

@interface HFByteArray : NSObject <NSCopying, NSMutableCopying> {
    NSUInteger changeLockCounter;
}

- (NSArray *)byteSlices;
- (unsigned long long)length;
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range;
- (void)deleteBytesInRange:(HFRange)range;
- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange;
- (void)insertByteArray:(HFByteArray *)array inRange:(HFRange)lrange;
- (HFByteArray *)subarrayWithRange:(HFRange)range;

//returns ULLONG_MAX if not found
- (unsigned long long)indexOfBytesEqualToBytes:(HFByteArray *)findBytes inRange:(HFRange)range searchingForwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker;

// set to a write lock - only reads are possible when the counter is incremented
- (void)incrementChangeLockCounter;
- (void)decrementChangeLockCounter;
- (BOOL)changesAreLocked;

@end
