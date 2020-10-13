//
//  HFByteSliceFileOperation.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFByteSliceFileOperation.h"
#import <HexFiend/HFByteSlice.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFFileReference.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>
#import "HFByteSliceFileOperationQueueEntry.h"
#include <malloc/malloc.h>

enum {
    eTypeIdentity = 1,
    eTypeExternal,
    eTypeInternal
};

#define SHOULD_LOG_IO 0
#define LOG_IO if (SHOULD_LOG_IO) 

@interface HFByteSliceFileOperation (HFForwardDeclares)
- (instancetype)initWithTargetRange:(HFRange)range;
@end

@interface HFByteSliceFileOperationSimple : HFByteSliceFileOperation {
    HFByteSlice *slice;
}

- (instancetype)initWithByteSlice:(HFByteSlice *)val targetRange:(HFRange)range;

@end

@implementation HFByteSliceFileOperationSimple

- (instancetype)initWithByteSlice:(HFByteSlice *)val targetRange:(HFRange)range {
    self = [super initWithTargetRange:range];
    REQUIRE_NOT_NULL(val);
    HFASSERT([val length] == range.length);
    HFASSERT(HFSumDoesNotOverflow(range.location, range.length));
    slice = val;
    return self;
}

@end

@interface HFByteSliceFileOperationIdentity : HFByteSliceFileOperationSimple
@end

@implementation HFByteSliceFileOperationIdentity

- (unsigned long long)costToWrite { return 0; } /* Nothing in the file is moving so this is free! */

@end

@interface HFByteSliceFileOperationExternal : HFByteSliceFileOperationSimple
@end

@implementation HFByteSliceFileOperationExternal

- (unsigned long long)costToWrite {
    /* Judge a file-sourced slice to be twice as expensive as a non-file sourced slice */
    if ([slice isSourcedFromFile]) return HFSum(targetRange.length, targetRange.length);
    else return targetRange.length;
}

- (HFByteSliceWriteError)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error {
    USE(error);
    NSUInteger buffLen = ll2l(MIN(targetRange.length, malloc_good_size(1024 * 1024)));
    unsigned char *buffer = check_malloc(buffLen);
    REQUIRE_NOT_NULL(file);
    HFByteSliceWriteError result = -1;
    const HFRange range = [self targetRange];
    HFASSERT(range.length == [slice length]);
    const BOOL isSourcedFromFile = [slice isSourcedFromFile];
    unsigned long long tempProgress = 0;
    volatile unsigned long long *progressPtr = progressTracker ? &progressTracker->currentProgress : &tempProgress;
    unsigned long long written = 0;
    while (written < range.length) {
        int err;
        NSUInteger amountToWrite = ll2l(MIN(buffLen, range.length - written));
        if (progressTracker && progressTracker->cancelRequested) goto bail;
        [slice copyBytes:buffer range:HFRangeMake(written, amountToWrite)];
        if (isSourcedFromFile) HFAtomicAdd64(amountToWrite, (volatile int64_t *)progressPtr);
        if (progressTracker && progressTracker->cancelRequested) goto bail;
        err = [file writeBytes:buffer length:amountToWrite to:HFSum(written, targetRange.location)];
        HFAtomicAdd64(amountToWrite, (volatile int64_t *)progressPtr);
        if (err) {
            goto bail;
        }
        written += amountToWrite;
    }
    result = HFWriteSuccess;
bail:;
    free(buffer);
    if (result == HFWriteSuccess && progressTracker != NULL && progressTracker->cancelRequested) {
        result = HFWriteCancelled;
    }
    return result;
}

@end

@interface HFByteSliceFileOperationInternal : HFByteSliceFileOperation {
    HFByteSlice *slice;
    NSMutableArray *remainingTargetRanges;
    HFRange sourceRange;
}

- (instancetype)initWithByteSlice:(HFByteSlice *)val sourceRange:(HFRange)source targetRange:(HFRange)target;

- (BOOL)hasRemainingTargetRange;
- (HFByteSliceFileOperationQueueEntry *)createQueueEntryWithBuffer:(unsigned char *)buffer ofLength:(NSUInteger)length forFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker NS_RETURNS_RETAINED;
- (NSUInteger)amountOfOverlapForEntry:(HFByteSliceFileOperationQueueEntry *)potentiallyOverlappingEntry;

- (void)addQueueEntriesOverlappedByEntry:(HFByteSliceFileOperationQueueEntry *)overlap withContext:(HFByteSliceFileOperationContext *)context;
- (void)addQueueEntryWithContext:(HFByteSliceFileOperationContext *)context;

@end

@implementation HFByteSliceFileOperationInternal

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p (%@ -> %@)>", NSStringFromClass([self class]), self, HFRangeToString([self sourceRange]), HFRangeToString([self targetRange])];
}

- (instancetype)initWithByteSlice:(HFByteSlice *)val sourceRange:(HFRange)source targetRange:(HFRange)target {
    self = [super initWithTargetRange:target];
    REQUIRE_NOT_NULL(val);
    HFASSERT([val length] == source.length);
    HFASSERT([val length] == target.length);
    HFASSERT(HFSumDoesNotOverflow(source.location, source.length));
    HFASSERT(HFSumDoesNotOverflow(target.location, target.length));
    remainingTargetRanges = [[NSMutableArray alloc] initWithObjects:[HFRangeWrapper withRange:targetRange], nil];
    slice = val;
    sourceRange = source;
    return self;
}

- (HFRange)sourceRange {
    return sourceRange;
}

- (unsigned long long)costToWrite {
    /* Have to read from the file and then write to it again, so we count twice. */
    return HFSum(targetRange.length, targetRange.length);
}

- (BOOL)hasRemainingTargetRange {
    return [remainingTargetRanges count] > 0;
}

- (unsigned long long)sourceLocationForTargetLocation:(unsigned long long)loc {
    HFASSERT(HFLocationInRange(loc, targetRange) || loc == HFMaxRange(targetRange));
    HFASSERT(targetRange.length == sourceRange.length);
    return HFSum(loc - targetRange.location, sourceRange.location);
}

- (unsigned long long)targetLocationForSourceLocation:(unsigned long long)loc {
    HFASSERT(HFLocationInRange(loc, sourceRange) || loc == HFMaxRange(sourceRange));
    HFASSERT(targetRange.length == sourceRange.length);
    return HFSum(loc - sourceRange.location, targetRange.location);
}

- (HFByteSliceFileOperationQueueEntry *)createQueueEntryWithBuffer:(unsigned char *)buffer ofLength:(NSUInteger)length forFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker {
    HFASSERT([self hasRemainingTargetRange]);
    REQUIRE_NOT_NULL(buffer);
    HFASSERT(length > 0);
    const HFRange firstRange = [remainingTargetRanges[0] HFRange];
    HFASSERT(HFRangeIsSubrangeOfRange(firstRange, [self targetRange]));
    unsigned long long sourceLocation = [self sourceLocationForTargetLocation:firstRange.location];
    HFByteSliceFileOperationQueueEntry *entry = [[HFByteSliceFileOperationQueueEntry alloc] init];
    entry->bytes = buffer;
    entry->offset = firstRange.location;
    entry->source = sourceLocation;
    if (length >= firstRange.length) {
        entry->length = ll2l(firstRange.length);
        [remainingTargetRanges removeObjectAtIndex:0];
    }
    else {
        entry->length = length;
        HFRange newFirstRange = HFRangeMake(firstRange.location + length, firstRange.length - length);
        remainingTargetRanges[0] = [HFRangeWrapper withRange:newFirstRange];
    }
    LOG_IO NSLog(@"Read {%llu, %lu}", [self sourceLocationForTargetLocation:firstRange.location], (unsigned long)entry->length);
    [file readBytes:buffer length:entry->length from:[self sourceLocationForTargetLocation:firstRange.location]];
    if (progressTracker) HFAtomicAdd64(entry->length, (volatile int64_t *)(&progressTracker->currentProgress));
    return entry;
}

- (void)addQueueEntryWithContext:(HFByteSliceFileOperationContext *)context {
    REQUIRE_NOT_NULL(context);
    HFASSERT([self hasRemainingTargetRange]);
    const HFRange firstRange = [remainingTargetRanges[0] HFRange];
    HFASSERT(HFRangeIsSubrangeOfRange(firstRange, [self targetRange]));
    unsigned long long sourceLocation = [self sourceLocationForTargetLocation:firstRange.location];
    HFByteSliceFileOperationQueueEntry *entry = [[HFByteSliceFileOperationQueueEntry alloc] init];
    NSUInteger length = [context suggestedAllocationLengthForMinimum:1 maximum:ll2l(MIN(firstRange.length, NSUIntegerMax))];
    HFASSERT(length > 0 && length <= firstRange.length);
    void *buffer = [context allocateMemoryOfLength:length];
    HFASSERT(buffer);
    entry->bytes = buffer;
    entry->offset = firstRange.location;
    entry->source = sourceLocation;
    entry->length = length;
    
    HFRange newFirstRange = HFRangeMake(HFSum(firstRange.location, length), firstRange.length - length);
    if (newFirstRange.length == 0) {
        [remainingTargetRanges removeObjectAtIndex:0];
    }
    else {
        remainingTargetRanges[0] = [HFRangeWrapper withRange:newFirstRange];
    }
    
    LOG_IO NSLog(@"Read {%llu, %lu}", sourceLocation, (unsigned long)entry->length);
    [context->file readBytes:buffer length:length from:sourceLocation];
    if (context->progressTracker) HFAtomicAdd64(entry->length, (volatile int64_t *)(&context->progressTracker->currentProgress));
    
    [context->queue addObject:entry];
}

- (NSUInteger)amountOfOverlapForEntry:(HFByteSliceFileOperationQueueEntry *)overlap {
    REQUIRE_NOT_NULL(overlap);
    HFRange overlapRange = HFRangeMake(overlap->offset, overlap->length);
    HFASSERT(overlapRange.length > 0);
    NSUInteger rangeIndex, rangeCount = [remainingTargetRanges count];
    NSUInteger result = 0;
    for (rangeIndex = 0; rangeIndex < rangeCount; rangeIndex++) {
        /* TODO: binary search */
        HFRange partialTargetRange = [remainingTargetRanges[rangeIndex] HFRange];
        HFASSERT(HFRangeIsSubrangeOfRange(partialTargetRange, [self targetRange]));
        HFRange partialSourceRange = HFRangeMake([self sourceLocationForTargetLocation:partialTargetRange.location], partialTargetRange.length);
        HFASSERT(HFRangeIsSubrangeOfRange(partialSourceRange, [self sourceRange]));
        if (HFIntersectsRange(overlapRange, partialSourceRange)) {
            /* Compute the extent of the overlap */
            unsigned long long left = MAX(overlapRange.location, partialSourceRange.location);
            unsigned long long right = MIN(HFMaxRange(overlapRange), HFMaxRange(partialSourceRange));
            NSUInteger overlapForThisRange;
            HFASSERT(right > left);
            HFASSERT(right - left <= NSUIntegerMax);
            overlapForThisRange = ll2l(right - left);
            HFASSERT(result + overlapForThisRange > result);
            result += overlapForThisRange;
        }
    }
    return result;
}

- (void)addQueueEntriesOverlappedByEntry:(HFByteSliceFileOperationQueueEntry *)overlap withContext:(HFByteSliceFileOperationContext *)context {
    REQUIRE_NOT_NULL(overlap);
    REQUIRE_NOT_NULL(context);
    HFASSERT([self hasRemainingTargetRange]);
    HFRange overlapRange = HFRangeMake(overlap->offset, overlap->length);
    HFASSERT(overlapRange.length > 0);
    NSUInteger rangeIndex, rangeCount = [remainingTargetRanges count];
    for (rangeIndex = 0; rangeIndex < rangeCount; rangeIndex++) {
        if (context->progressTracker && context->progressTracker->cancelRequested) goto bail;
        /* TODO: binary search */
        HFRange partialTargetRange = [remainingTargetRanges[rangeIndex] HFRange];
        HFASSERT(HFRangeIsSubrangeOfRange(partialTargetRange, [self targetRange]));
        HFRange partialSourceRange = HFRangeMake([self sourceLocationForTargetLocation:partialTargetRange.location], partialTargetRange.length);
        HFASSERT(HFRangeIsSubrangeOfRange(partialSourceRange, [self sourceRange]));
        if (HFIntersectsRange(overlapRange, partialSourceRange)) {
            /* Compute the extent of the overlap */
            unsigned long long left = MAX(overlapRange.location, partialSourceRange.location);
            unsigned long long right = MIN(HFMaxRange(overlapRange), HFMaxRange(partialSourceRange));
            HFASSERT(right > left);
            HFASSERT(right - left <= NSUIntegerMax);
            NSUInteger minAmountToRead = ll2l(right - left);
            NSUInteger maxAmountToRead = ll2l(MIN(partialSourceRange.length, NSUIntegerMax));
            NSUInteger amountToRead = [context suggestedAllocationLengthForMinimum:minAmountToRead maximum:maxAmountToRead];
            unsigned long long leftExtension = MIN(amountToRead - minAmountToRead, left - partialSourceRange.location);
            unsigned long long rightExtension = MIN(amountToRead - minAmountToRead - leftExtension, HFMaxRange(partialSourceRange) - right);
            HFASSERT(leftExtension <= left);
            left -= leftExtension;
            right = HFSum(right, rightExtension);
            HFASSERT(right <= HFMaxRange(partialSourceRange));
            HFASSERT(amountToRead == ll2l(right - left));
            
            HFByteSliceFileOperationQueueEntry *entry = [[HFByteSliceFileOperationQueueEntry alloc] init];
            entry->length = amountToRead;
            entry->offset = [self targetLocationForSourceLocation:left];
            entry->bytes = [context allocateMemoryOfLength:entry->length];
            entry->source = left;
            LOG_IO NSLog(@"Read {%llu, %lu}", left, (unsigned long)entry->length);
            [context->file readBytes:entry->bytes length:entry->length from:left];
            if (context->progressTracker) HFAtomicAdd64(entry->length, (volatile int64_t *)(&context->progressTracker->currentProgress));
            [context->queue addObject:entry];
            
            /* Now we have to remove this range.  We may have zero, one, or two fragments to add */
            HFASSERT(left >= partialSourceRange.location);
            HFASSERT(right <= HFMaxRange(partialSourceRange));
            HFRange leftFragment = HFRangeMake([self targetLocationForSourceLocation:partialSourceRange.location], left - partialSourceRange.location);
            HFRange rightFragment = HFRangeMake([self targetLocationForSourceLocation:right], HFMaxRange(partialSourceRange) - right);
            [remainingTargetRanges removeObjectAtIndex:rangeIndex];
            rangeCount -= 1;
            rangeIndex -= 1;
            if (leftFragment.length > 0) {
                HFASSERT(HFRangeIsSubrangeOfRange(leftFragment, [self targetRange]));
                [remainingTargetRanges insertObject:[HFRangeWrapper withRange:leftFragment] atIndex:++rangeIndex];
                rangeCount += 1;
            }
            if (rightFragment.length > 0) {
                HFASSERT(HFRangeIsSubrangeOfRange(rightFragment, [self targetRange]));
                [remainingTargetRanges insertObject:[HFRangeWrapper withRange:rightFragment] atIndex:++rangeIndex];
                rangeCount += 1;
            }
        }
    }
bail:;
}

@end

@interface HFByteSliceFileOperationChained : HFByteSliceFileOperation {
    NSArray *internalOperations;
    NSUInteger totalAllocatedMemory;
    NSUInteger maximumAllocatedMemory;
}

- (instancetype)initWithInternalOperations:(NSArray *)ops;

@end

@implementation HFByteSliceFileOperationChained

- (instancetype)initWithInternalOperations:(NSArray *)ops {
    REQUIRE_NOT_NULL(ops);
    self = [super initWithTargetRange:HFRangeMake(ULLONG_MAX, ULLONG_MAX)];
    maximumAllocatedMemory = 1024 * 1024 * 4;
#if ! NDEBUG
    for(id op in ops) {
        HFASSERT([op isKindOfClass:[HFByteSliceFileOperationInternal class]]);
    }
#endif
    internalOperations = [ops copy];
    return self;
}

- (unsigned long long)costToWrite {
    unsigned long long result = 0;
    for(HFByteSliceFileOperationInternal *op in internalOperations) {
        result += [op costToWrite];
    }
    return result;
}

- (int)applyQueueEntry:(HFByteSliceFileOperationQueueEntry *)entry toFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker {
    REQUIRE_NOT_NULL(entry);
    REQUIRE_NOT_NULL(file);
    int err;
    LOG_IO NSLog(@"Applying {%llu, %lu} -> {%llu, %lu}", entry->source, (unsigned long)entry->length, entry->offset, (unsigned long)entry->length);
    err = [file writeBytes:entry->bytes length:entry->length to:entry->offset];
    if (progressTracker) HFAtomicAdd64(entry->length, (volatile int64_t *)(&progressTracker->currentProgress));
    return err;
}

- (void)queueUpEntriesOverlappedByEntry:(HFByteSliceFileOperationQueueEntry *)entry withIncompleteOperations:(NSMutableArray *)incompleteOperations context:(HFByteSliceFileOperationContext *)context {
    NSUInteger incompleteOperationIndex, incompleteOperationCount = [incompleteOperations count];
    for (incompleteOperationIndex = 0; incompleteOperationIndex < incompleteOperationCount; incompleteOperationIndex++) {
        HFByteSliceFileOperationInternal *potentialOverlap = incompleteOperations[incompleteOperationIndex];
        if (context->progressTracker && context->progressTracker->cancelRequested) return;
        [potentialOverlap addQueueEntriesOverlappedByEntry:entry withContext:context];
        if (! [potentialOverlap hasRemainingTargetRange]) {
            [incompleteOperations removeObjectAtIndex:incompleteOperationIndex];
            incompleteOperationCount -= 1;
            incompleteOperationIndex -= 1;
        }
    }
}

#define CHECK_CANCEL() do { if (progressTracker && progressTracker->cancelRequested) goto bail; } while (0)
- (HFByteSliceWriteError)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error {
    USE(error);
    REQUIRE_NOT_NULL(file);
    HFByteSliceWriteError result = -1;
    NSMutableArray *queue = [[NSMutableArray alloc] init];
    NSMutableArray *incompleteOperations = [[NSMutableArray alloc] initWithArray:internalOperations];
    HFASSERT([[NSSet setWithArray:incompleteOperations] count] == [incompleteOperations count]);
    
    HFByteSliceFileOperationContext *context = [[HFByteSliceFileOperationContext alloc] init];
    context->softMaxAllocatedMemory = maximumAllocatedMemory;
    context->totalAllocatedMemory = 0;
    context->file = file;
    context->progressTracker = progressTracker;
    context->queue = queue;
    
    while ([incompleteOperations count]) {
        HFByteSliceFileOperationInternal *operation = incompleteOperations[0];
        HFASSERT([operation hasRemainingTargetRange]);
        
        CHECK_CANCEL();
        [operation addQueueEntryWithContext:context];
        CHECK_CANCEL();
        if (! [operation hasRemainingTargetRange]) [incompleteOperations removeObjectAtIndex:0];
        
        while ([queue count]) {
            int err;
            HFByteSliceFileOperationQueueEntry *entry = queue[0];
            CHECK_CANCEL();
            [self queueUpEntriesOverlappedByEntry:entry withIncompleteOperations:incompleteOperations context:context];
            CHECK_CANCEL();
            /* It's safe to fire away with this entry */
            err = [self applyQueueEntry:entry toFile:file trackingProgress:progressTracker];
            CHECK_CANCEL();
            /* Dequeue and destroy it */
            [context freeMemory:entry->bytes ofLength:entry->length];
            entry->bytes = NULL;
            [queue removeObjectAtIndex:0];
            if (err) {
                NSLog(@"Got err %d (%s)", err, strerror(err));
                goto bail;
            }
        }
    }
    result = HFWriteSuccess;
    
bail:;
    if (progressTracker && progressTracker->cancelRequested) result = HFWriteCancelled;
    return result;	
}
#undef CHECK_CANCEL

@end

@implementation HFByteSliceFileOperation

+ (instancetype)identityOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range {
    return [[HFByteSliceFileOperationIdentity alloc] initWithByteSlice:slice targetRange:range];
}

+ (instancetype)externalOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range {
    return [[HFByteSliceFileOperationExternal alloc] initWithByteSlice:slice targetRange:range];
}

+ (instancetype)internalOperationWithByteSlice:(HFByteSlice *)slice sourceRange:(HFRange)source targetRange:(HFRange)target {
    return [[HFByteSliceFileOperationInternal alloc] initWithByteSlice:slice sourceRange:source targetRange:target];
}

+ (instancetype)chainedOperationWithInternalOperations:(NSArray *)internalOperations {
    return [[HFByteSliceFileOperationChained alloc] initWithInternalOperations:internalOperations];
}

- (instancetype)initWithTargetRange:(HFRange)range {
    self = [super init];
    HFASSERT(! [self isMemberOfClass:[HFByteSliceFileOperation class]]);
    targetRange = range;
    return self;
}

- (HFRange)sourceRange {
    return HFRangeMake(ULLONG_MAX, ULLONG_MAX);
}

- (HFRange)targetRange {
    return targetRange;
}

- (unsigned long long)costToWrite {
    UNIMPLEMENTED();
}

- (HFByteSliceWriteError)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error {
    USE(file);
    USE(progressTracker);
    USE(error);
    UNIMPLEMENTED();
}

@end

