//
//  HFByteArray_FileWriting.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFFileReference.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFByteSlice.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>
#import "HFByteSliceFileOperation.h"
#import "HFObjectGraph.h"
#import <HexFiend/HFSharedMemoryByteSlice.h>

// When we save a file, and other byte arrays need to break their dependencies on the file by copying some of its data into memory, what's the max amount we should copy (per byte array)?  We currently don't show any progress for this, so this should be a smaller value
#define MAX_MEMORY_TO_USE_FOR_BREAKING_FILE_DEPENDENCIES_ON_SAVE (16 * 1024 * 1024)

static inline BOOL invalidRange(HFRange range) { return range.location == ULLONG_MAX && range.length == ULLONG_MAX; }

@implementation HFByteArray (HFileWriting)

/* Our file writing strategy is as follows:
 1. Divide each ByteSlice into one of the following categories:
 Identity (references data in the file that is not moving - nothing to do)
 External (source data is in memory or in another file)
 Internal (source data is in the file)
 
 2. Estimate cost
 
 3. Compute a graph representing the dependencies in the internal slices, if any.  This graph may be cyclic.
 
 4. Compute the strongly connected components of this graph.
 
 5. Construct a NEW graph representing dependencies between the strongly connected components, in the sense that if A depends on B in the original graph, then their corresponding components depend on each other as well.  This graph must be acyclic.
 
 6. Write this graph in topologically-sorted order.
 
 7. Write the external reps.
 */

static void computeFileOperations(HFByteArray *self, HFFileReference *reference, NSMutableArray *identity, NSMutableArray *external, NSMutableArray *internal) {
#if NDEBUG
    unsigned long long totalLength = [self length];
#endif
    unsigned long long currentOffset = 0;
    for(HFByteSlice * slice in [self byteSlices]) {
        unsigned long long length = [slice length];
        HFRange sourceRange = [slice sourceRangeForFile:reference];
        HFRange targetRange = HFRangeMake(currentOffset, length);
        if (invalidRange(sourceRange)) {
            if (external) [external addObject:[HFByteSliceFileOperation externalOperationWithByteSlice:slice targetRange:targetRange]];
        }
        else {
            HFASSERT(sourceRange.length == length);
            if (sourceRange.location == currentOffset) {
                if (identity) [identity addObject:[HFByteSliceFileOperation identityOperationWithByteSlice:slice targetRange:targetRange]];
            }
            else {
                if (internal) [internal addObject:[HFByteSliceFileOperation internalOperationWithByteSlice:slice sourceRange:sourceRange targetRange:targetRange]];
            }
        }
        currentOffset += length;
    }
#if NDEBUG
    HFASSERT(currentOffset == totalLength);
#endif
}

__attribute__((unused))
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

/* Finds the index of the smallest operation whose min target range is larger than or equal to the given location, or NSUIntegerMax if none */
static NSUInteger binarySearchRight(unsigned long long loc, NSArray *sortedOperations) {
    NSUInteger count = [sortedOperations count];	
    NSUInteger left = 0, right = count;
    while (left < right) {
        NSUInteger mid = left + (right - left)/2;
        HFByteSliceFileOperation *op = sortedOperations[mid];
        unsigned long long targetLoc = [op targetRange].location;
        if (targetLoc >= loc) {
            right = mid;
        }
        else {
            left = mid + 1;
        }
    }
    return left == count ? NSUIntegerMax : left;
}

/* Finds the index of the smallest operation whose target range intersects the given source range; if none returns NSUIntegerMax  */
static NSUInteger binarySearchLeft(HFRange range, NSArray *sortedOperations) {
    NSUInteger count = [sortedOperations count];
    NSUInteger left = 0, right = count;
    while (left < right) {
        NSUInteger mid = left + (right - left)/2;
        HFByteSliceFileOperation *op = sortedOperations[mid];
        HFRange targetRange = [op targetRange];
        if (HFIntersectsRange(range, targetRange)) {
            right = mid;
        }
        else if (range.location > targetRange.location) {
            left = mid + 1;
        }
        else {
            right = mid;
        }
    }
    if (left == count) {
        return NSUIntegerMax;
    }
    else {
        /* It's possible that the range does not actually intersect us */
        HFByteSliceFileOperation *op = sortedOperations[left];
        HFRange targetRange = [op targetRange];
        return HFIntersectsRange(range, targetRange) ? left : NSUIntegerMax;
    }
}

__attribute__((unused))
static NSUInteger naiveSearchRight(unsigned long long loc, NSArray *sortedOperations) {
    NSUInteger i, max = [sortedOperations count];
    for (i=0; i < max; i++) {
        HFByteSliceFileOperation *op = sortedOperations[i];
        if ([op targetRange].location >= loc) return i;
    }
    return NSUIntegerMax;
}

__attribute__((unused))
static NSUInteger naiveSearchLeft(HFRange range, NSArray *sortedOperations) {
    NSUInteger i, max = [sortedOperations count];
    for (i=0; i < max; i++) {
        HFByteSliceFileOperation *op = sortedOperations[i];
        if (HFIntersectsRange([op targetRange], range)) return i;
    }
    return NSUIntegerMax;
}

static void computeDependencies(HFByteArray *self, HFObjectGraph *graph, NSArray *targetSortedOperations) {
    REQUIRE_NOT_NULL(graph);
    REQUIRE_NOT_NULL(self);
    HFASSERT([targetSortedOperations isEqual:[targetSortedOperations sortedArrayUsingFunction:compareFileOperationTargetRanges context:(__bridge void*)self]]);
    NSUInteger targetSortedOperationsCount = [targetSortedOperations count];
    for(HFByteSliceFileOperation * sourceOperation in targetSortedOperations) {
        /* "B is a dependency of A" means that B's source range overlaps A's target range. For each operation B, find all the target ranges A its source range overlaps */
        HFRange sourceRange = [sourceOperation sourceRange];
        HFASSERT(sourceRange.length > 0);
        NSUInteger startIndex = binarySearchLeft(sourceRange, targetSortedOperations);
        HFASSERT(naiveSearchLeft(sourceRange, targetSortedOperations) == startIndex);
        NSUInteger endIndex = binarySearchRight(HFMaxRange(sourceRange), targetSortedOperations);
        HFASSERT(naiveSearchRight(HFMaxRange(sourceRange), targetSortedOperations) == endIndex);
        if (startIndex != NSNotFound) {
            NSUInteger index, end = MIN(targetSortedOperationsCount, endIndex); //endIndex may be NSNotFound
            for (index = startIndex; index < end; index++) {
                HFByteSliceFileOperation *targetOperation = targetSortedOperations[index];
                HFASSERT(HFIntersectsRange([sourceOperation sourceRange], [targetOperation targetRange]));
                [graph addDependency:sourceOperation forObject:targetOperation];
            }
        }
    }
}

/* Given an array of strongly connected components, and their associated chained HFByteSliceFileOperation, return an ayclic object graph representing the dependencies between the chains */
static HFObjectGraph *createAcyclicGraphFromStronglyConnectedComponents(NSArray *stronglyConnectedComponents, NSArray *chains, HFObjectGraph *cyclicGraph) {
    REQUIRE_NOT_NULL(stronglyConnectedComponents);
    REQUIRE_NOT_NULL(chains);
    HFASSERT([chains count] == [stronglyConnectedComponents count]);
    HFObjectGraph *acyclicGraph = [[HFObjectGraph alloc] init];
    NSUInteger i, max = [stronglyConnectedComponents count];
    /* Construct a dictionary mapping each operation to its contained chain */
    NSMapTable *operationToContainingChain = [NSMapTable weakToWeakObjectsMapTable];

    for (i=0; i < max; i++) {
        HFByteSliceFileOperation *chain = chains[i];
        NSArray *component = stronglyConnectedComponents[i];
        for(HFByteSliceFileOperation * operation in component) {
            EXPECT_CLASS(operation, HFByteSliceFileOperation);
            HFASSERT([operationToContainingChain objectForKey:operation] == NULL);
            [operationToContainingChain setObject:chain forKey:operation];
        }
    }
    
    /* Now add dependencies between chains */
    for (i=0; i < max; i++) {
        NSArray *component = stronglyConnectedComponents[i];
        for(HFByteSliceFileOperation * operation in component) {
            EXPECT_CLASS(operation, HFByteSliceFileOperation);
            HFByteSliceFileOperation *operationChain = [operationToContainingChain objectForKey:operation];
            HFASSERT(operationChain != NULL);
            NSSet *dependencies = [cyclicGraph dependenciesForObject:operation];
            NSUInteger dependencyCount = [dependencies count];
            if (dependencyCount > 0) {
                NSUInteger dependencyIndex;
                for (dependencyIndex = 0; dependencyIndex < dependencyCount; dependencyIndex++) {
                    HFByteSliceFileOperation *dependencyChain = [operationToContainingChain objectForKey:operation];
                    HFASSERT(dependencyChain != NULL);
                    if (dependencyChain != operationChain) {
                        [acyclicGraph addDependency:dependencyChain forObject:operationChain];
                    }
                }
            }
        }
    }

    return acyclicGraph;
}

#if ! NDEBUG

static void verifyDependencies(HFByteArray *self, HFObjectGraph *graph, NSArray *targetSortedOperations) {
    USE(self);
    NSUInteger ind1, ind2, count = [targetSortedOperations count];
    HFByteSliceFileOperation *op1, *op2;
    for (ind1 = 0; ind1 < count; ind1++) {
        op1 = targetSortedOperations[ind1];
        for (ind2 = 0; ind2 < count; ind2++) {
            // op1 = A, op2 = B
            op2 = targetSortedOperations[ind2];
            BOOL shouldDepend = HFIntersectsRange([op1 targetRange], [op2 sourceRange]);
            BOOL doesDepend = ([[graph dependenciesForObject:op1] containsObject:op2]);
            if (shouldDepend != doesDepend) {
                NSLog(@"verifyDependencies failed:\n\t%@\n\t%@\n\tshouldDepend: %s doesDepend: %s", op1, op2, shouldDepend ? "YES" : "NO", doesDepend ? "YES" : "NO");
                exit(EXIT_FAILURE);
            }
        }
    }
}

static void verifyStronglyConnectedComponents(NSArray *stronglyConnectedComponents) {
    NSMutableSet *allComponentsSet = [[NSMutableSet alloc] init];
    for(NSArray * component in stronglyConnectedComponents) {
        NSSet *componentSet = [[NSSet alloc] initWithArray:component];
        HFASSERT(! [allComponentsSet intersectsSet:componentSet]);
        [allComponentsSet unionSet:componentSet];
    }
}

static void verifyEveryObjectInExactlyOneConnectedComponent(NSArray *components, NSArray *operations) {
    NSMutableArray *remaining = [NSMutableArray arrayWithArray:operations];
    for(NSArray * component in components) {
        for(HFByteSliceFileOperation * operation in component) {
            EXPECT_CLASS(operation, HFByteSliceFileOperation);
            NSUInteger arrayIndex = [remaining indexOfObjectIdenticalTo:operation];
            HFASSERT(arrayIndex != NSNotFound);
            [remaining removeObjectAtIndex:arrayIndex];
            HFASSERT([remaining indexOfObjectIdenticalTo:operation] == NSNotFound);
        }
    }
    HFASSERT([remaining count] == 0);
}

#endif

#define CHECK_CANCEL() do { if (progressTracker && progressTracker->cancelRequested) { puts("Cancelled!"); wasCancelled = YES; goto cancelled; } } while (0)

- (BOOL)writeToFile:(NSURL *)targetURL trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error {
    REQUIRE_NOT_NULL(targetURL);
    HFASSERT([targetURL isFileURL]);
    unsigned long long totalCost = 0;
    unsigned long long startLength, endLength;
    HFObjectGraph *cyclicGraph = nil, *acyclicGraph = nil;
    BOOL wasCancelled = NO;
    BOOL result = NO;
    HFFileReference *reference;
    NSMutableArray *identity;
    NSMutableArray *external;
    NSMutableArray *internal;
    NSMutableArray *chains;
    NSMutableArray *allOperations;
    NSArray *stronglyConnectedComponents;
    NSArray *topologicallySortedChains;

    reference = [[HFFileReference alloc] initWritableWithPath:[targetURL path] error:error];
    if (reference == nil) goto bail;
    
    startLength = [reference length];
    endLength = [self length];
    
    CHECK_CANCEL();
    
    if (endLength > startLength) {
        /* If we're extending the file, make it longer so we can detect failure before trying to write anything. */
        if (! [reference setLength:endLength error:error]) {
            goto bail;
        }   
    }
    
    CHECK_CANCEL();
    
    /* Step 1 */
    identity = [NSMutableArray array];
    external = [NSMutableArray array];
    internal = [NSMutableArray array];
    chains = [NSMutableArray array];
    computeFileOperations(self, reference, identity, external, internal);
    
    /* Create an array of all the operations */
    allOperations = [NSMutableArray arrayWithCapacity:[identity count] + [external count] + [internal count]];
    [allOperations addObjectsFromArray:internal];
    [allOperations addObjectsFromArray:external];
    [allOperations addObjectsFromArray:identity];
    
    //NSLog(@"Internal %@ External %@ Identity %@", internal, external, identity);
    
    /* Step 2 */
    /* Estimate the cost of each of our ops */
    for(HFByteSliceFileOperation * op in allOperations) {
        totalCost += [op costToWrite];
    }
    [progressTracker setMaxProgress:totalCost];
    
    CHECK_CANCEL();
    
    /* Step 3 */
    cyclicGraph = [[HFObjectGraph alloc] init];
    computeDependencies(self, cyclicGraph, internal);
#if ! NDEBUG
    verifyDependencies(self, cyclicGraph, internal);
#endif
    
    CHECK_CANCEL();
    
    /* Step 4 */
    stronglyConnectedComponents = [cyclicGraph stronglyConnectedComponentsForObjects:internal];
#if ! NDEBUG
    verifyStronglyConnectedComponents(stronglyConnectedComponents);
    verifyEveryObjectInExactlyOneConnectedComponent(stronglyConnectedComponents, internal);
#endif
    for(NSArray * stronglyConnectedComponent in stronglyConnectedComponents) {
        [chains addObject:[HFByteSliceFileOperation chainedOperationWithInternalOperations:stronglyConnectedComponent]];
    }
    
    CHECK_CANCEL();
    
    /* Step 5 */
    acyclicGraph = createAcyclicGraphFromStronglyConnectedComponents(stronglyConnectedComponents, chains, cyclicGraph);
    
    CHECK_CANCEL();
    
    /* Step 6 */
    topologicallySortedChains = [acyclicGraph topologicallySortObjects:chains];
    if ([topologicallySortedChains count] > 0) {
        for(HFByteSliceFileOperation * chainOp in topologicallySortedChains) {
            HFByteSliceWriteError writeError = [chainOp writeToFile:reference trackingProgress:progressTracker error:error];
            if (writeError == HFWriteCancelled) {
                goto cancelled;
            }
            else if (writeError != HFWriteSuccess) {
                goto bail;
            }
            CHECK_CANCEL();
        }
    }
    
    
    /* Step 7 - write external ops */
    if ([external count] > 0) {
        for(HFByteSliceFileOperation * op2 in external) {
            HFByteSliceWriteError writeError = [op2 writeToFile:reference trackingProgress:progressTracker error:error];
            if (writeError == HFWriteCancelled) {
                goto cancelled;
            }
            else if (writeError != HFWriteSuccess) {
                goto bail;
            }
            CHECK_CANCEL();
        }
    }
    
    CHECK_CANCEL();
    
    if (endLength < startLength) {
        /* If we're shrinking the file, do it now, so we don't lose any data. */
        if (! [reference setLength:endLength error:error]) {
            goto bail;
        }
    }
    
    result = YES;
bail:;
cancelled:;
    
    [reference close];
    return result;
}

- (NSArray *)rangesOfFileModifiedIfSavedToFile:(HFFileReference *)reference {
    /* Compute our file operations as if we were about to save the file, except we don't care about the identity operations */
    NSMutableArray *external = [[NSMutableArray alloc] init];
    NSMutableArray *internal = [[NSMutableArray alloc] init];
    computeFileOperations(self, reference, nil/*identity*/, external, internal);
    
    NSMutableArray *resultRanges = [NSMutableArray arrayWithCapacity:[external count] + [internal count]];
    
    for(HFByteSliceFileOperation * op in external) {
        [resultRanges addObject:[HFRangeWrapper withRange:[op targetRange]]];
    }
    
    for(HFByteSliceFileOperation * op2 in internal) {
        [resultRanges addObject:[HFRangeWrapper withRange:[op2 targetRange]]];    
    }
    
    /* If we are going to truncate the file, then the last part of the file is dirty too */
    unsigned long long currentLength = [reference length];
    unsigned long long proposedLength = [self length];
    if (proposedLength < currentLength) {
        [resultRanges addObject:[HFRangeWrapper withRange:HFRangeMake(proposedLength, currentLength - proposedLength)]];
    }
    
    return [HFRangeWrapper organizeAndMergeRanges:resultRanges];
}

static HFRange dirtyRangeToSliceRange(HFRange rangeInFile, HFRange proposedFileSubrange) {
    HFRange actualFileSubrange = HFIntersectionRange(rangeInFile, proposedFileSubrange);
    HFRange rangeInSlice = HFRangeMake(actualFileSubrange.location - rangeInFile.location, actualFileSubrange.length);
    return rangeInSlice;
}

/* Given an HFByteSlice occupying the given range in a file, construct an array of new byte slices that do not intersect the dirty ranges, or return nil if we can't */
static HFByteArray *constructNewSlices(HFByteSlice *slice, HFRange rangeInFile, NSArray *dirtyRanges, NSUInteger *inoutMemoryRemainingForCopying) {
    HFASSERT(rangeInFile.length == [slice length]);
    
    // Count how much memory is needed to copy
    unsigned long long memoryRequiredForCopying = 0;
    for(HFRangeWrapper * rangeWrapper in dirtyRanges) {
        memoryRequiredForCopying = HFSum(memoryRequiredForCopying, HFIntersectionRange([rangeWrapper HFRange], rangeInFile).length);
    }
    
    if(memoryRequiredForCopying == 0) {
        // Easy, there weren't actually any intersected dirty ranges.
        return [[HFBTreeByteArray alloc] initWithByteSlice:slice];
    }
    
    if(memoryRequiredForCopying > *inoutMemoryRemainingForCopying) {
        // Too much memory required, give up.
        return nil;
    }
    
    // Subtract off the memory we need.
    *inoutMemoryRemainingForCopying -= ll2l(memoryRequiredForCopying);
    
    // Start with the slice, then replace dirty chunks with shared memory copies.
    HFByteArray *resultByteArray = [[HFBTreeByteArray alloc] initWithByteSlice:slice];
    for(HFRangeWrapper * rangeWrapper in dirtyRanges) {
        HFRange subRange = dirtyRangeToSliceRange(rangeInFile, [rangeWrapper HFRange]);

        NSMutableData *data = [[NSMutableData alloc] initWithLength:ll2l(subRange.length)];
        [slice copyBytes:[data mutableBytes] range:subRange];
        HFByteSlice *newSlice = [[HFSharedMemoryByteSlice alloc] initWithData:data];
        [resultByteArray insertByteSlice:newSlice inRange:subRange];
    }

    HFASSERT([resultByteArray length] == rangeInFile.length);
    return resultByteArray;
}

- (BOOL)clearDependenciesOnRanges:(NSArray *)ranges inFile:(HFFileReference *)reference hint:(NSMutableDictionary *)hint {
    REQUIRE_NOT_NULL(reference);
    REQUIRE_NOT_NULL(ranges);
    BOOL success = YES;
    // sliceToNewSlicesDictionary maps the old slices to the replacements.  It is a CFDictionary so that it won't try to copy the keys.
    // Try to fetch them from the dictionary so that we can share
    CFMutableDictionaryRef sliceToNewSlicesDictionary = (__bridge CFMutableDictionaryRef)hint[@"sliceToNewSlicesDictionary"];
    BOOL releaseObjects = NO;
    
    // If we couldn't fetch it, we'll have to create it
    if (! sliceToNewSlicesDictionary) {
        sliceToNewSlicesDictionary = CFDictionaryCreateMutable(NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
        
        // Put the slice dictionary in the hint dictionary for everyone else.  Note that we may have a nil dictionary, so we can't count on this retaining it.
        hint[@"sliceToNewSlicesDictionary"] = (__bridge id)sliceToNewSlicesDictionary;
        releaseObjects = YES;
    }
    
    NSMutableDictionary *rangesToOldSlices = [[NSMutableDictionary alloc] init];
    NSEnumerator *enumer = [self byteSliceEnumerator];
    HFByteSlice *slice;
    
    /* Start by computing all the replacement slice arrays we need */
    NSUInteger memoryRemainingForCopying = MAX_MEMORY_TO_USE_FOR_BREAKING_FILE_DEPENDENCIES_ON_SAVE;
    unsigned long long offset = 0;
    while (success && (slice = [enumer nextObject])) {
        unsigned long long sliceLength = [slice length];
        HFRange rangeInFile = [slice sourceRangeForFile:reference];
        if (! invalidRange(rangeInFile)) {
            /* Our slice is sourced from the file */
            rangesToOldSlices[[HFRangeWrapper withRange:HFRangeMake(offset, sliceLength)]] = slice;
            HFByteArray *newSlices = CFDictionaryGetValue(sliceToNewSlicesDictionary, (__bridge const void *)slice);
            if (! newSlices) {
                newSlices = constructNewSlices(slice, rangeInFile, ranges, &memoryRemainingForCopying);
                if (newSlices) {
                    HFASSERT([newSlices length] == [slice length]);
                    CFDictionarySetValue(sliceToNewSlicesDictionary, (const void *)slice, (const void *)newSlices);
                }
                else {
                    /* We couldn't make these slices - we probably exceeded our memory threshold */
                    success = NO;
                }
            }
        }
        offset = HFSum(offset, sliceLength);
    }
    
    /* Now apply the replacements, if we did not run out of memory */
    if (success) {
        NSEnumerator *keyEnumerator = [rangesToOldSlices keyEnumerator];
        HFRangeWrapper *rangeWrapper;
        while ((rangeWrapper = [keyEnumerator nextObject])) {
            HFRange replacementRange = [rangeWrapper HFRange];
            slice = rangesToOldSlices[rangeWrapper];
            HFASSERT(slice != nil);
            HFByteArray *replacementSlices = CFDictionaryGetValue(sliceToNewSlicesDictionary, (const void *)slice);
            HFASSERT(replacementSlices != nil);
            [self insertByteArray:replacementSlices inRange:replacementRange];
        }
    }
    
    if (releaseObjects) {
        CFRelease(sliceToNewSlicesDictionary);
    }
    
#if ! NDEBUG
    if (success) {
        /* Make sure we actually worked */
        enumer = [self byteSliceEnumerator];
        NSUInteger dirtyRangeCount = [ranges count];
        while ((slice = [enumer nextObject])) {
            HFRange rangeInFile = [slice sourceRangeForFile:reference];
            if (! invalidRange(rangeInFile)) {
                NSUInteger i;
                for (i=0; i < dirtyRangeCount; i++) {
                    HFRange dirtyRange = [ranges[i] HFRange];
                    HFASSERT(! HFIntersectsRange(dirtyRange, rangeInFile));
                }
            }
        }
    }
#endif
    
    return success;
}

@end
