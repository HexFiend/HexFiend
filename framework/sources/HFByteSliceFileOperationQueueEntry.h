//
//  HFByteSliceFileOperationQueueEntry.h
//  HexFiend_2
//
//  Created by Peter Ammon on 3/15/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


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

- (void *)allocateMemoryOfLength:(NSUInteger)len;
- (void)freeMemory:(void *)buff ofLength:(NSUInteger)len;
- (NSUInteger)suggestedAllocationLengthForMinimum:(NSUInteger)minimum maximum:(NSUInteger)maximum;

@end
