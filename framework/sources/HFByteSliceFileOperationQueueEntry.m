//
//  HFByteSliceFileOperationQueueEntry.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/15/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteSliceFileOperationQueueEntry.h>
#include <malloc/malloc.h>

#define SOFT_MAX_PER_BUFFER (512 * 1024)

@implementation HFByteSliceFileOperationQueueEntry

@end

@implementation HFByteSliceFileOperationContext

- (void *)allocateMemoryOfLength:(NSUInteger)len {
	HFASSERT(len > 0);
	void *result = check_malloc(len);
	totalAllocatedMemory = HFSumInt(totalAllocatedMemory, len);
	return result;
}

- (void)freeMemory:(void *)buff ofLength:(NSUInteger)len {
	HFASSERT(buff == NULL || len > 0);
	if (buff == NULL && len == 0) return;
	
	HFASSERT(len <= malloc_size(buff));
	HFASSERT(len <= totalAllocatedMemory);
	totalAllocatedMemory -= len;
	free(buff);
}

- (NSUInteger)suggestedAllocationLengthForMinimum:(NSUInteger)minimum maximum:(NSUInteger)maximum {
	HFASSERT(maximum >= minimum);
	NSUInteger minAllocatable = softMaxAllocatedMemory - MIN(softMaxAllocatedMemory, totalAllocatedMemory);
	NSUInteger result = maximum, paddedResult;
	result = MIN(minAllocatable, result);
	result = MIN(SOFT_MAX_PER_BUFFER, result);
	result = MAX(result, minimum);
	HFASSERT(result >= minimum && result <= maximum);
	paddedResult = malloc_good_size(result);
	HFASSERT(paddedResult >= result);
	result = MIN(paddedResult, maximum);
	return result;
}

@end
