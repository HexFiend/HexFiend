//
//  HFByteArrayPiece.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArrayPiece.h>
#import <HexFiend/HFByteSlice_Private.h>


@implementation HFByteArrayPiece

- initWithSlice:(HFByteSlice *)sliceParam offset:(unsigned long long)offsetParam {
    REQUIRE_NOT_NULL(sliceParam);
    [super init];
    //retainCount = 1;
    slice = [sliceParam retain];
    pieceRange.location = offsetParam;
    pieceRange.length = [slice length];
    return self;
}

- (void)dealloc {
    [slice release];
    [super dealloc];
}

- (unsigned long long)offset {
    return pieceRange.location;
}

- (void)setOffset:(unsigned long long)offset {
    pieceRange.location = offset;
}

- (unsigned long long)length {
    return pieceRange.length;
}

- (HFByteSlice *)byteSlice {
    return slice;
}

- (HFRange *)tavl_key {
    return &pieceRange;
}

- (void)constructNewArrayPiecesAboutRange:(HFRange)range first:(HFByteArrayPiece **)first second:(HFByteArrayPiece **)second {
    const unsigned long long offset = [self offset];
    const unsigned long long length = [self length];
    
    //clip the range to our extent
    if (range.location < offset) {
        range.length -= llmin(range.length, offset - range.location);
        range.location = offset;
    }
    HFASSERT(range.location >= offset);
    range.length = llmin(range.length, length - (range.location - offset));
    
    HFRange sliceRange = {range.location - offset, range.length};
    HFByteSlice* a = NULL, *b = NULL;
    [[self byteSlice] constructNewByteSlicesAboutRange:sliceRange first:&a second:&b];
    
    if (first) {
        if (a)
            *first = [[[[self class] alloc] initWithSlice:a offset:offset] autorelease];
        else
            *first = nil;
    }
    
    if (second) {
        if (b)
            *second = [[[[self class] alloc] initWithSlice:b offset:range.location + range.length] autorelease];
        else
            *second = nil;
    }
}

- (BOOL)fastPathAppendByteSlice:(HFByteSlice *)additionalSlice atLocation:(unsigned long long)location {
    BOOL result = NO;
    if (location == HFMaxRange(pieceRange)) {
        HFByteSlice *newSlice = [slice byteSliceByAppendingSlice:additionalSlice];
        if (newSlice) {
            [newSlice retain];
            [slice release];
            slice = newSlice;
            pieceRange.length = [slice length];
            result = YES;
        }
    }
    return result;
}

#if 0
- (id)retain {
    HFAtomicIncrement(&retainCount, NO);
    return self;
}

- (void)release {
    if (HFAtomicDecrement(&retainCount, NO) == 0) {
        [self dealloc];
    }
}
#endif

@end
