//
//  HFByteSliceFileOperationQueueEntry.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFByteSliceFileOperationQueueEntry : NSObject {
	@public
	NSUInteger length;
	unsigned long long offset; //target location
	unsigned char *bytes;
	unsigned long long source; //for debugging
}

@end

@class HFFileReference, HFProgressTracker;

@interface HFByteSliceFileOperationContext : NSObject {
	@public
	NSUInteger softMaxAllocatedMemory;
	NSUInteger totalAllocatedMemory;
	//the following ivars are not retained
	HFFileReference *file; 
	HFProgressTracker *progressTracker;
	NSMutableArray *queue;
}

- (void *)allocateMemoryOfLength:(NSUInteger)len NS_RETURNS_INNER_POINTER;
- (void)freeMemory:(void *)buff ofLength:(NSUInteger)len;
- (NSUInteger)suggestedAllocationLengthForMinimum:(NSUInteger)minimum maximum:(NSUInteger)maximum;

@end

NS_ASSUME_NONNULL_END
