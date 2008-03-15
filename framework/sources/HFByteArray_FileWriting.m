//
//  HFByteArray_FileWriting.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArray.h>
#import <HexFiend/HFFileReference.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFByteSlice.h>
#import <HexFiend/HFByteSliceFileOperation.h>
#import <HexFiend/HFObjectGraph.h>

static inline BOOL invalidRange(HFRange range) { return range.location == ULLONG_MAX && range.length == ULLONG_MAX; }

@implementation HFByteArray (HFileWriting)

/* Our file writing strategy is as follows:
    1. Divide each ByteSlice into one of the following categories:
        Identity (references data in the file that is not moving - nothing to do)
        External (source data is in memory or in another file)
        Internal (source data is in the file)
    
    2. Estimate cost
    
    3. Compute a graph representing the dependencies in the internal slices, if any.
    
    4. Compute the strongly connected components of this graph.
    
	5. Write the strongly connected components.
	
    6. Write the external reps
*/

static void computeFileOperations(HFByteArray *self, HFFileReference *reference, NSMutableArray *identity, NSMutableArray *external, NSMutableArray *internal) {
#if NDEBUG
    unsigned long long totalLength = [self length];
#endif
    unsigned long long currentOffset = 0;
    FOREACH(HFByteSlice *, slice, [self byteSlices]) {
        unsigned long long length = [slice length];
        HFRange sourceRange = [slice sourceRangeForFile:reference];
        HFRange targetRange = HFRangeMake(currentOffset, length);
        if (invalidRange(sourceRange)) {
            [external addObject:[HFByteSliceFileOperation externalOperationWithByteSlice:slice targetRange:targetRange]];
        }
        else {
            HFASSERT(sourceRange.length == length);
            if (sourceRange.location == currentOffset) {
                [identity addObject:[HFByteSliceFileOperation identityOperationWithByteSlice:slice targetRange:targetRange]];
            }
            else {
                [internal addObject:[HFByteSliceFileOperation internalOperationWithByteSlice:slice sourceRange:sourceRange targetRange:targetRange]];
            }
        }
		currentOffset += length;
    }
    
}

#if ! NDEBUG
static NSComparisonResult compareFileOperationTargetRanges(id a, id b, void *self) {
    USE(self);
    REQUIRE_NOT_NULL(a);
    REQUIRE_NOT_NULL(b);
    HFByteSliceFileOperation *op1 = a, *op2 = b;
    HFRange range1 = [op1 targetRange];
    HFRange range2 = [op2 targetRange];
    HFASSERT(range1.length > 0);
    HFASSERT(range2.length > 0);
    HFASSERT(! HFIntersectsRange(range1, range2));
    if (range1.location < range2.location) return -1;
    else return 1;
}
#endif

static NSUInteger binarySearchTargetRanges(unsigned long long location, NSArray *sortedOperations) {
    NSUInteger left = 0, right = [sortedOperations count];
    while (left + 1 < right) {
        NSUInteger mid = left + (right - left)/2;
        HFByteSliceFileOperation *op = [sortedOperations objectAtIndex:mid];
        HFRange targetRange = [op targetRange];
        if (HFLocationInRange(location, targetRange)) {
            return mid;
        }
        else if (location < targetRange.location) {
            left = mid + 1;
        }
        else {
            right = mid;
        }
    }
    return NSNotFound;
}

static void computeDependencies(HFByteArray *self, HFObjectGraph *graph, NSArray *targetSortedOperations) {
    REQUIRE_NOT_NULL(graph);
    REQUIRE_NOT_NULL(self);
    HFASSERT([targetSortedOperations isEqual:[targetSortedOperations sortedArrayUsingFunction:compareFileOperationTargetRanges context:self]]);
    NSUInteger targetSortedOperationsCount = [targetSortedOperations count];
    FOREACH(HFByteSliceFileOperation *, op, targetSortedOperations) {
        /* "A depends on B" means that A's target range overlaps B's source range. For each operation B, find all the target ranges A its source range overlaps */
        HFRange sourceRange = [op sourceRange];
        HFASSERT(sourceRange.length > 0);
        NSUInteger startIndex = binarySearchTargetRanges(sourceRange.location, targetSortedOperations);
        NSUInteger endIndex = binarySearchTargetRanges(HFMaxRange(sourceRange) - 1, targetSortedOperations);
        if (startIndex != NSNotFound) {
            NSUInteger index, end = MIN(targetSortedOperationsCount - 1, endIndex); //endIndex may be NSNotFound
            for (index = startIndex; index <= end; index++) {
                [graph addDependency:[targetSortedOperations objectAtIndex:index] forObject:op];
            }
        }
    }
}

#if ! NDEBUG

static void verifyDependencies(HFByteArray *self, HFObjectGraph *graph, NSArray *targetSortedOperations) {
    USE(self);
    NSUInteger ind1, ind2, count = [targetSortedOperations count];
    HFByteSliceFileOperation *op1, *op2;
    for (ind1 = 0; ind1 < count; ind1++) {
        op1 = [targetSortedOperations objectAtIndex:ind1];
        for (ind2 = 0; ind2 < count; ind2++) {
            op2 = [targetSortedOperations objectAtIndex:ind2];
            BOOL shouldDepend = HFIntersectsRange([op1 targetRange], [op2 sourceRange]);
            BOOL doesDepend = ([[graph dependenciesForObject:op1] indexOfObjectIdenticalTo:op2] != NSNotFound);
            if (shouldDepend != doesDepend) {
                NSLog(@"verifyDependencies failed:\n\t%@\n\t%@\n\tshouldDepend: %s doesDepend: %s", op1, op2, shouldDepend ? "YES" : "NO", doesDepend ? "YES" : "NO");
                exit(EXIT_FAILURE);
            }
        }
    }
}

#endif

- (BOOL)writeToFile:(NSURL *)targetURL trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error {
    REQUIRE_NOT_NULL(targetURL);
    HFASSERT([targetURL isFileURL]);
    unsigned long long totalCost = 0;
    unsigned long long startLength, endLength;
    HFFileReference *reference = [[HFFileReference alloc] initWritableWithPath:[targetURL path]];
    HFASSERT(reference != NULL);
    startLength = [reference length];
    endLength = [self length];
    BOOL result = NO;

	size_t malloc_good_size(size_t);
	NSUInteger auxBufferSize = malloc_good_size(1024 * 1024 * 1);
    unsigned char *auxBuffer = NULL;

    if (endLength > startLength) {
        /* If we're extending the file, make it longer so we can detect failure before trying to write anything. */
        int err = [reference setLength:endLength];
        if (err != 0) {
            
            goto bail;
        }
    }

    /* Step 1 */
    NSMutableArray *identity = [NSMutableArray array];
    NSMutableArray *external = [NSMutableArray array];
    NSMutableArray *internal = [NSMutableArray array];
	NSMutableArray *chains = [NSMutableArray array];
    NSMutableArray *allOperations;
    computeFileOperations(self, reference, identity, external, internal);
    
    /* Create an array of all the operations */
    allOperations = [NSMutableArray arrayWithCapacity:[identity count] + [external count] + [internal count]];
    [allOperations addObjectsFromArray:internal];
    [allOperations addObjectsFromArray:external];
    [allOperations addObjectsFromArray:identity];

	NSLog(@"Internal %@ External %@ Identity %@", internal, external, identity);

    /* Step 2 */
    /* Estimate the cost of each of our ops */
    FOREACH(HFByteSliceFileOperation *, op, allOperations) {
        totalCost += [op costToWrite];
    }
    [progressTracker setMaxProgress:totalCost];


    /* Step 3 */
    HFObjectGraph *graph = [[HFObjectGraph alloc] init];
    computeDependencies(self, graph, internal);
#if ! NDEBUG
    verifyDependencies(self, graph, internal);
#endif

    /* Step 4 */
    NSArray *stronglyConnectedComponents = [graph stronglyConnectedComponentsForObjects:internal];
	FOREACH(NSArray *, stronglyConnectedComponent, stronglyConnectedComponents) {
		[chains addObject:[HFByteSliceFileOperation chainedOperationWithInternalOperations:internal]];
	}
	
    
    /* Step 5 */
	if ([chains count] > 0) {
        if (! auxBuffer) auxBuffer = malloc(auxBufferSize);
		if (! auxBuffer) goto bail;
		FOREACH(HFByteSliceFileOperation *, chainOp, chains) {
			if (! [chainOp writeToFile:reference trackingProgress:progressTracker error:error withAuxilliaryBuffer:auxBuffer ofLength:auxBufferSize]) {
				goto bail;
			}
		}
	}
    
    /* Step 6 - write external ops */
    if ([external count] > 0) {
        if (! auxBuffer) auxBuffer = malloc(auxBufferSize);
        if (! auxBuffer) goto bail;
        FOREACH(HFByteSliceFileOperation *, op2, external) {
            if (! [op2 writeToFile:reference trackingProgress:progressTracker error:error withAuxilliaryBuffer:auxBuffer ofLength:auxBufferSize]) {
                goto bail;
            }
        }
    }
	
	result = YES;
bail:;

    free(auxBuffer);
    [graph release];
    
    [reference close];
    [reference release];
    return result;
}


@end
