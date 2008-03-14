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
    HFRange sourceRange;
}

- initWithByteSlice:(HFByteSlice *)val sourceRange:(HFRange)source targetRange:(HFRange)target;

@end

@implementation HFByteSliceFileOperationInternal

- initWithByteSlice:(HFByteSlice *)val sourceRange:(HFRange)source targetRange:(HFRange)target {
    [super initWithTargetRange:target];
    REQUIRE_NOT_NULL(val);
    HFASSERT([val length] == source.length);
    HFASSERT([val length] == target.length);
    HFASSERT(HFSumDoesNotOverflow(source.location, source.length));
    HFASSERT(HFSumDoesNotOverflow(target.location, target.length));
    slice = [val retain];
    sourceRange = source;
    return self;
}

- (void)dealloc {
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

- (BOOL)writeToFile:(HFFileReference *)file trackingProgress:(HFProgressTracker *)progressTracker error:(NSError **)error withAuxilliaryBuffer:(unsigned char *)buffer ofLength:(NSUInteger)buffLen {
    REQUIRE_NOT_NULL(buffer);
    REQUIRE_NOT_NULL(file);
    unsigned long long tempProgress = 0;
    volatile unsigned long long *progressPtr = progressTracker ? &progressTracker->currentProgress : &tempProgress;
    while ([remainingTargetRanges count] > 0) {
        /* Carve off a range to write */
        HFRangeWrapper *rangeWrapper = [remainingTargetRanges objectAtIndex:0];
        HFRange firstRange = [rangeWrapper HFRange];
        HFRange rangeToWrite = HFRangeMake(firstRange.location, MIN(buffLen, firstRange.length));
        
        /* Modify remainingTargetRanges */
        if (rangeToWrite.length == firstRange.length) {
            [remainingTargetRanges removeObjectAtIndex:0];
        }
        else {
            [remainingTargetRanges replaceObjectAtIndex:0 withObject:[HFRangeWrapper withRange:HFRangeMake(HFMaxRange(rangeToWrite), firstRange.length - rangeToWrite.length)]];
        }
        
        
    }
    return 0;
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

- initWithTargetRange:(HFRange)range {
    [super init];
    targetRange = range;
    remainingTargetRanges = [[NSMutableArray alloc] initWithObjects:[HFRangeWrapper withRange:targetRange], nil];
    return self;
}

- (void)dealloc {
    [remainingTargetRanges release];
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



@end
