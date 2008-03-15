//
//  HFByteSliceFileOperation.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteSliceFileOperation.h>
#import <HexFiend/HFByteSlice.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFFileReference.h>
#import <HexFiend/HFByteSliceFileOperationQueueEntry.h>

enum {
    eTypeIdentity = 1,
    eTypeExternal,
    eTypeInternal
};

@interface HFByteSliceFileOperation (HFForwardDeclares)
- initWithTargetRange:(HFRange)range;
@end

@interface HFByteSliceFileOperationSimple : HFByteSliceFileOperation {
    HFByteSlice *slice;
}

- initWithByteSlice:(HFByteSlice *)val targetRange:(HFRange)range;

@end

@implementation HFByteSliceFileOperationSimple

- initWithByteSlice:(HFByteSlice *)val targetRange:(HFRange)range {
    [super initWithTargetRange:range];
    REQUIRE_NOT_NULL(val);
    HFASSERT([val length] == range.length);
    HFASSERT(HFSumDoesNotOverflow(range.location, range.length));
    slice = [val retain];
    return self;
}

- (void)dealloc {
    [slice release];
    [super dealloc];
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

- (BOOL)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error withAuxilliaryBuffer:(unsigned char *)buffer ofLength:(NSUInteger)buffLen {
    REQUIRE_NOT_NULL(buffer);
    REQUIRE_NOT_NULL(file);
    BOOL result = NO;
    const HFRange range = [self targetRange];
	HFASSERT(range.length == [slice length]);
    const BOOL isSourcedFromFile = [slice isSourcedFromFile];
    unsigned long long tempProgress = 0;
    volatile unsigned long long *progressPtr = progressTracker ? &progressTracker->currentProgress : &tempProgress;
    unsigned long long written = 0;
    while (written < range.length) {
        int err;
        NSUInteger amountToWrite = ll2l(MIN(buffLen, range.length - written));
        [slice copyBytes:buffer range:HFRangeMake(written, amountToWrite)];
        if (isSourcedFromFile) HFAtomicAdd64(amountToWrite, (volatile int64_t *)progressPtr);
        err = [file writeBytes:buffer length:amountToWrite to:HFSum(written, targetRange.location)];
        HFAtomicAdd64(amountToWrite, (volatile int64_t *)progressPtr);
        if (err) {
            goto bail;
        }
		written += amountToWrite;
    }
    result = YES;
bail:;
    return result;
}

@end

@interface HFByteSliceFileOperationInternal : HFByteSliceFileOperation {
    HFByteSlice *slice;
	NSMutableArray *remainingTargetRanges;
    HFRange sourceRange;
}

- initWithByteSlice:(HFByteSlice *)val sourceRange:(HFRange)source targetRange:(HFRange)target;

- (BOOL)hasRemainingTargetRange;
- (HFByteSliceFileOperationQueueEntry *)createQueueEntryWithBuffer:(unsigned char *)buffer ofLength:(NSUInteger)length forFile:(HFFileReference *)file;
- (void)addQueueEntriesOverlappedByEntry:(HFByteSliceFileOperationQueueEntry *)overlap toQueue:(NSMutableArray *)queue forFile:(HFFileReference *)file;

@end

@implementation HFByteSliceFileOperationInternal

- initWithByteSlice:(HFByteSlice *)val sourceRange:(HFRange)source targetRange:(HFRange)target {
    [super initWithTargetRange:target];
    REQUIRE_NOT_NULL(val);
    HFASSERT([val length] == source.length);
    HFASSERT([val length] == target.length);
    HFASSERT(HFSumDoesNotOverflow(source.location, source.length));
    HFASSERT(HFSumDoesNotOverflow(target.location, target.length));
	remainingTargetRanges = [[NSMutableArray alloc] initWithObjects:[HFRangeWrapper withRange:targetRange], nil];
    slice = [val retain];
    sourceRange = source;
    return self;
}

- (void)dealloc {
    [remainingTargetRanges release];
    [slice release];
    [super dealloc];
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
	HFASSERT(HFLocationInRange(loc, targetRange));
	HFASSERT(targetRange.length == sourceRange.length);
	return HFSum(loc - targetRange.location, sourceRange.location);
}

- (unsigned long long)targetLocationForSourceLocation:(unsigned long long)loc {
	HFASSERT(HFLocationInRange(loc, sourceRange));
	HFASSERT(targetRange.length == sourceRange.length);
	return HFSum(loc - sourceRange.location, targetRange.location);
}

- (HFByteSliceFileOperationQueueEntry *)createQueueEntryWithBuffer:(unsigned char *)buffer ofLength:(NSUInteger)length forFile:(HFFileReference *)file {
	HFASSERT([self hasRemainingTargetRange]);
	REQUIRE_NOT_NULL(buffer);
	HFASSERT(length > 0);
	const HFRange firstRange = [[remainingTargetRanges objectAtIndex:0] HFRange];
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
		[remainingTargetRanges replaceObjectAtIndex:0 withObject:[HFRangeWrapper withRange:newFirstRange]];
	}
	[file readBytes:buffer length:entry->length from:[self sourceLocationForTargetLocation:firstRange.location]];
	return entry;
}

- (void)addQueueEntriesOverlappedByEntry:(HFByteSliceFileOperationQueueEntry *)overlap toQueue:(NSMutableArray *)queue forFile:(HFFileReference *)file {
	REQUIRE_NOT_NULL(overlap);
	REQUIRE_NOT_NULL(queue);
	HFASSERT([self hasRemainingTargetRange]);
	HFRange overlapRange = HFRangeMake(overlap->offset, overlap->length);
	HFASSERT(overlapRange.length > 0);
	NSUInteger rangeIndex, rangeCount = [remainingTargetRanges count];
	for (rangeIndex = 0; rangeIndex < rangeCount; rangeIndex++) {
		/* TODO: binary search */
		HFRange partialTargetRange = [[remainingTargetRanges objectAtIndex:rangeIndex] HFRange];
		HFASSERT(HFRangeIsSubrangeOfRange(partialTargetRange, [self targetRange]));
		HFRange partialSourceRange = HFRangeMake([self sourceLocationForTargetLocation:partialTargetRange.location], partialTargetRange.length);
		HFASSERT(HFRangeIsSubrangeOfRange(partialSourceRange, [self sourceRange]));
		if (HFIntersectsRange(overlapRange, partialSourceRange)) {
			/* Compute the extent of the overlap */
			unsigned long long left = MAX(overlapRange.location, partialSourceRange.location);
			unsigned long long right = MIN(HFMaxRange(overlapRange), HFMaxRange(partialSourceRange));
			HFASSERT(right > left);
			HFASSERT(right - left <= NSUIntegerMax);
			HFByteSliceFileOperationQueueEntry *entry = [[HFByteSliceFileOperationQueueEntry alloc] init];
			entry->length = ll2l(right - left);
			entry->offset = [self targetLocationForSourceLocation:left];
			entry->bytes = check_malloc(entry->length);
			entry->source = left;
			[file readBytes:entry->bytes length:entry->length from:left];
			[queue addObject:entry];
			[entry release];
			
			/* Now we have to remove this range.  We may have zero, one, or two fragments to add */
			HFASSERT(left >= partialSourceRange.location);
			HFASSERT(right <= HFMaxRange(partialSourceRange));
			HFRange leftFragment = HFRangeMake(partialSourceRange.location, left - partialSourceRange.location);
			HFRange rightFragment = HFRangeMake(right, HFMaxRange(partialSourceRange) - right);
			[remainingTargetRanges removeObjectAtIndex:rangeIndex];
			rangeCount -= 1;
			rangeIndex -= 1;
			if (leftFragment.length > 0) {
				[remainingTargetRanges insertObject:[HFRangeWrapper withRange:leftFragment] atIndex:rangeIndex];
				rangeIndex += 1;
				rangeCount += 1;
			}
			if (rightFragment.length > 0) {
				[remainingTargetRanges insertObject:[HFRangeWrapper withRange:rightFragment] atIndex:rangeIndex];
				rangeIndex += 1;
				rangeCount += 1;
			}
		}
	}
}

@end

@interface HFByteSliceFileOperationChained : HFByteSliceFileOperation {
	NSArray *internalOperations;
}

- initWithInternalOperations:(NSArray *)ops;

@end

@implementation HFByteSliceFileOperationChained

- initWithInternalOperations:(NSArray *)ops {
	REQUIRE_NOT_NULL(ops);
	[super initWithTargetRange:HFRangeMake(ULLONG_MAX, ULLONG_MAX)];
#if ! NDEBUG
	FOREACH(id, op, ops) {
		HFASSERT([op isKindOfClass:[HFByteSliceFileOperationInternal class]]);
	}
#endif
	internalOperations = [ops copy];
	return self;
}

- (unsigned long long)costToWrite {
    unsigned long long result = 0;
	FOREACH(HFByteSliceFileOperationInternal *, op, internalOperations) {
		result += [op costToWrite];
	}
	return result;
}

- (int)applyQueueEntry:(HFByteSliceFileOperationQueueEntry *)entry toFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker {
	REQUIRE_NOT_NULL(entry);
	REQUIRE_NOT_NULL(file);
	int err;
	NSLog(@"Applying {%llu, %u} -> {%llu, %u}", entry->source, entry->length, entry->offset, entry->length);
	err = [file writeBytes:entry->bytes length:entry->length to:entry->offset];
	if (progressTracker) HFAtomicAdd64(entry->length, (volatile int64_t *)(&progressTracker->currentProgress));
	return err;
}

- (BOOL)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error withAuxilliaryBuffer:(unsigned char *)buffer ofLength:(NSUInteger)buffLen {
    REQUIRE_NOT_NULL(buffer);
    REQUIRE_NOT_NULL(file);
	BOOL result = NO;
	NSMutableArray *queue = [[NSMutableArray alloc] init];
	NSMutableArray *incompleteOperations = [[NSMutableArray alloc] initWithArray:internalOperations];
	while ([incompleteOperations count]) {
		HFByteSliceFileOperationInternal *operation = [incompleteOperations objectAtIndex:0];
		HFByteSliceFileOperationQueueEntry *entry = [operation createQueueEntryWithBuffer:buffer ofLength:buffLen forFile:file]; //must be released
		[queue addObject:entry];
		[entry release];
		if (! [operation hasRemainingTargetRange]) [incompleteOperations removeObjectAtIndex:0];
		while ([queue count] > 0) {
			int err;
			HFByteSliceFileOperationQueueEntry *entry = [queue objectAtIndex:0];
			/* Create queue entries for all ranges that our entry overlaps */
			NSUInteger incompleteOperationIndex, incompleteOperationCount = [incompleteOperations count];
			for (incompleteOperationIndex = 0; incompleteOperationIndex < incompleteOperationCount; incompleteOperationIndex++) {
				HFByteSliceFileOperationInternal *potentialOverlap = [incompleteOperations objectAtIndex:incompleteOperationIndex];
				[potentialOverlap addQueueEntriesOverlappedByEntry:entry toQueue:queue forFile:file];
				if (! [potentialOverlap hasRemainingTargetRange]) {
					[incompleteOperations removeObjectAtIndex:incompleteOperationCount];
					incompleteOperationCount -= 1;
					incompleteOperationIndex -= 1;
				}
			}
			/* It's safe to fire away with this entry */
			err = [self applyQueueEntry:entry toFile:file trackingProgress:progressTracker];
			
			/* Dequeue and destroy it */
			if (entry->bytes != buffer) free(entry->bytes);
			entry->bytes = (unsigned char *)(-1);
			[queue removeObjectAtIndex:0];
			if (err) {
				NSLog(@"Got err %d (%s)", err, strerror(err));
				goto bail;
			}
		}
	}
	
	result = YES;
	
bail:;
	[incompleteOperations release];
	[queue release];
    return result;
}

- (void)dealloc {
	[internalOperations release];
	[super dealloc];
}

@end

@implementation HFByteSliceFileOperation

+ identityOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range {
    return [[[HFByteSliceFileOperationIdentity alloc] initWithByteSlice:slice targetRange:range] autorelease];
}

+ externalOperationWithByteSlice:(HFByteSlice *)slice targetRange:(HFRange)range {
    return [[[HFByteSliceFileOperationExternal alloc] initWithByteSlice:slice targetRange:range] autorelease];
}

+ internalOperationWithByteSlice:(HFByteSlice *)slice sourceRange:(HFRange)source targetRange:(HFRange)target {
    return [[[HFByteSliceFileOperationInternal alloc] initWithByteSlice:slice sourceRange:source targetRange:target] autorelease];
}

+ chainedOperationWithInternalOperations:(NSArray *)internalOperations {
    return [[[HFByteSliceFileOperationChained alloc] initWithInternalOperations:internalOperations] autorelease];
}

- initWithTargetRange:(HFRange)range {
    [super init];
	HFASSERT(! [self isMemberOfClass:[HFByteSliceFileOperation class]]);
    targetRange = range;
    return self;
}

- (void)dealloc {
    [super dealloc];
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

- (BOOL)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error withAuxilliaryBuffer:(unsigned char *)buffer ofLength:(NSUInteger)buffLen {
	USE(file);
	USE(progressTracker);
	USE(error);
	USE(buffer);
	USE(buffLen);
	UNIMPLEMENTED();
}

@end
