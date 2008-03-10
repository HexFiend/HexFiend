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
        
    2. Compute a graph representing the dependencies in the internal slices, if any.
    
    3. Compute the strongly connected components of this graph.
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
    HFFileReference *reference = [[HFFileReference alloc] initWritableWithPath:[targetURL path]];
    HFASSERT(reference != NULL);

    /* Step 1 */
    NSMutableArray *identity = [NSMutableArray array];
    NSMutableArray *external = [NSMutableArray array];
    NSMutableArray *internal = [NSMutableArray array];
    computeFileOperations(self, reference, identity, external, internal);

    /* Step 2 */
    HFObjectGraph *graph = [[HFObjectGraph alloc] init];
    computeDependencies(self, graph, internal);
#if ! NDEBUG
    verifyDependencies(self, graph, internal);
#endif

    /* Step 3 */
    NSArray *stronglyConnectedComponents = [graph stronglyConnectedComponentsForObjects:internal];
    
    

    [graph release];
    
    [reference close];
    [reference release];
    return YES;
}


@end
