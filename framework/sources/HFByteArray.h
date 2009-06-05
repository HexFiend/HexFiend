//
//  HFByteArray.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFByteSlice, HFProgressTracker, HFFileReference;

@interface HFByteArray : NSObject <NSCopying, NSMutableCopying> {
    NSUInteger changeLockCounter;
    NSUInteger changeGenerationCount;
}

- (NSArray *)byteSlices;
- (NSEnumerator *)byteSliceEnumerator;
- (unsigned long long)length;
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range;
- (void)deleteBytesInRange:(HFRange)range;
- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange;
- (void)insertByteArray:(HFByteArray *)array inRange:(HFRange)lrange;
- (HFByteArray *)subarrayWithRange:(HFRange)range;


// set to a write lock - only reads are possible when the counter is incremented
- (void)incrementChangeLockCounter;
- (void)decrementChangeLockCounter;
- (BOOL)changesAreLocked; //KVO compliant

// change generation count.  Every change to the ByteArray increments this by one or more.
- (NSUInteger)changeGenerationCount;


//returns ULLONG_MAX if not found
- (unsigned long long)indexOfBytesEqualToBytes:(HFByteArray *)findBytes inRange:(HFRange)range searchingForwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker;

@end

@interface HFByteArray (HFFileWriting)

- (BOOL)writeToFile:(NSURL *)targetURL trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error;

// If the receiver were written to this file, what ranges within the file would be modified?  This answers that question.  This is for use in e.g. determining if the clipboard can be preserved after a save operation.  Returns an array of HFRangeWrappers.
- (NSArray *)rangesOfFileModifiedBySaveOperation:(HFFileReference *)reference;

@end
