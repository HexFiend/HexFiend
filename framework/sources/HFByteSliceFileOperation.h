//
//  HFByteSliceFileOperation.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

@class HFByteSlice, HFFileReference, HFProgressTracker;

typedef NS_ENUM(NSInteger, HFByteSliceWriteError) {
	HFWriteSuccess,
	HFWriteCancelled
};

@interface HFByteSliceFileOperation : NSObject {
    HFRange targetRange;
}

+ (instancetype)identityOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range;
+ (instancetype)externalOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range;
+ (instancetype)internalOperationWithByteSlice:(HFByteSlice *)slice sourceRange:(HFRange)source targetRange:(HFRange)target;

+ (instancetype)chainedOperationWithInternalOperations:(NSArray *)internalOperations;

- (HFRange)sourceRange;
- (HFRange)targetRange;

- (unsigned long long)costToWrite;
- (HFByteSliceWriteError)writeToFile:(HFFileReference *)file trackingProgress:(nullable HFProgressTracker *)progressTracker error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
