//
//  HFByteSliceFileOperation.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/9/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteSliceFileOperation.h>

enum {
    eTypeIdentity = 1,
    eTypeExternal,
    eTypeInternal
};

@interface HFByteSliceFileOperationSimple : HFByteSliceFileOperation {
    HFByteSlice *slice;
    HFRange targetRange;
}

- initWithByteSlice:(HFByteSlice *)val targetRange:(HFRange)range;

@end

@implementation HFByteSliceFileOperationSimple

- initWithByteSlice:(HFByteSlice *)val targetRange:(HFRange)range {
    [super init];
    REQUIRE_NOT_NULL(val);
    HFASSERT([val length] == range.length);
    HFASSERT(HFSumDoesNotOverflow(range.location, range.length));
    targetRange = range;
    slice = [val retain];
    return self;
}

- (void)dealloc {
    [slice release];
    [super dealloc];
}

- (HFRange)targetRange {
    return targetRange;
}

@end

@interface HFByteSliceFileOperationIdentity : HFByteSliceFileOperationSimple
@end

@implementation HFByteSliceFileOperationIdentity
@end

@interface HFByteSliceFileOperationExternal : HFByteSliceFileOperationSimple
@end

@implementation HFByteSliceFileOperationExternal
@end

@interface HFByteSliceFileOperationInternal : HFByteSliceFileOperation {
    HFByteSlice *slice;
    HFRange sourceRange;
    HFRange targetRange;
}

- initWithByteSlice:(HFByteSlice *)val sourceRange:(HFRange)source targetRange:(HFRange)target;

@end

@implementation HFByteSliceFileOperationInternal

- initWithByteSlice:(HFByteSlice *)val sourceRange:(HFRange)source targetRange:(HFRange)target {
    [super init];
    REQUIRE_NOT_NULL(val);
    HFASSERT([val length] == source.length);
    HFASSERT([val length] == target.length);
    HFASSERT(HFSumDoesNotOverflow(source.location, source.length));
    HFASSERT(HFSumDoesNotOverflow(target.location, target.length));
    slice = [val retain];
    sourceRange = source;
    targetRange = target;
    return self;
}

- (void)dealloc {
    [slice release];
    [super dealloc];
}

- (HFRange)sourceRange {
    return sourceRange;
}

- (HFRange)targetRange {
    return targetRange;
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

- (HFRange)sourceRange {
    return HFRangeMake(ULLONG_MAX, ULLONG_MAX);
}

- (HFRange)targetRange {
    return HFRangeMake(ULLONG_MAX, ULLONG_MAX);
}

@end
