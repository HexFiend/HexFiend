//
//  HFByteSliceFileOperation.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFByteSlice, HFFileReference, HFProgressTracker;

typedef NS_ENUM(NSInteger, HFByteSliceWriteError) {
	HFWriteSuccess,
	HFWriteCancelled
};

@interface HFByteSliceFileOperation : NSObject {
    HFRange targetRange;
}

+ (id)identityOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range;
+ (id)externalOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range;
+ (id)internalOperationWithByteSlice:(HFByteSlice *)slice sourceRange:(HFRange)source targetRange:(HFRange)target;

+ (id)chainedOperationWithInternalOperations:(NSArray *)internalOperations;

- (HFRange)sourceRange;
- (HFRange)targetRange;

- (unsigned long long)costToWrite;
- (HFByteSliceWriteError)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error;

@end
