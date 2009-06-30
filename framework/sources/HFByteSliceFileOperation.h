//
//  HFByteSliceFileOperation.h
//  HexFiend_2
//
//  Created by Peter Ammon on 3/9/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFByteSlice, HFFileReference, HFProgressTracker;

typedef enum {
	HFWriteSuccess,
	HFWriteCancelled
} HFByteSliceWriteError;

@interface HFByteSliceFileOperation : NSObject {
    HFRange targetRange;
}

+ identityOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range;
+ externalOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range;
+ internalOperationWithByteSlice:(HFByteSlice *)slice sourceRange:(HFRange)source targetRange:(HFRange)target;

+ chainedOperationWithInternalOperations:(NSArray *)internalOperations;

- (HFRange)sourceRange;
- (HFRange)targetRange;

- (unsigned long long)costToWrite;
- (HFByteSliceWriteError)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error;

@end
