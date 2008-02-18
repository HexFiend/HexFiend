//
//  HFSharedMemoryByteSlice.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteSlice_Private.h>
#import <HexFiend/HFSharedMemoryByteSlice.h>
#import <HexFiend/HFSharedData.h>

#define MAX_FAST_PATH_SIZE (1 << 13)

#define MAX_TAIL_LENGTH (sizeof ((HFSharedMemoryByteSlice *)NULL)->inlineTail / sizeof *((HFSharedMemoryByteSlice *)NULL)->inlineTail)

@implementation HFSharedMemoryByteSlice

- initWithUnsharedData:(NSData *)unsharedData {
    [super init];
    REQUIRE_NOT_NULL(unsharedData);
    NSUInteger dataLength = [unsharedData length];
    NSUInteger inlineAmount = MIN(dataLength, MAX_TAIL_LENGTH);
    NSUInteger sharedAmount = dataLength - inlineAmount;
    HFASSERT(inlineAmount <= UCHAR_MAX);
    inlineTailLength = (unsigned char)inlineAmount;
    length = sharedAmount;
    if (inlineAmount > 0) {
        [unsharedData getBytes:inlineTail range:NSMakeRange(dataLength - inlineAmount, inlineAmount)];
    }
    if (sharedAmount > 0) {
        data = [[HFSharedData alloc] initWithBytes:[unsharedData bytes] length:sharedAmount];
        [data incrementUser];
    }
    return self;
}

// retains, does not copy
- initWithData:(HFSharedData *)dat {
    REQUIRE_NOT_NULL(dat);
    return [self initWithData:dat offset:0 length:[dat length]];
}

- initWithData:(HFSharedData *)dat offset:(NSUInteger)off length:(NSUInteger)len {
    [super init];
    REQUIRE_NOT_NULL(dat);
    HFASSERT(off + len >= off); //check for overflow
    HFASSERT(off + len <= [dat length]);
    offset = off;
    length = len;
    data = [dat retain];
    [data incrementUser];
    return self;
}

- initWithSharedData:(HFSharedData *)dat offset:(NSUInteger)off length:(NSUInteger)len tail:(const void *)tail tailLength:(NSUInteger)tailLen {
    [super init];
    if (off || len) REQUIRE_NOT_NULL(dat);
    if (tailLen) REQUIRE_NOT_NULL(tail);
    HFASSERT(tailLen <= MAX_TAIL_LENGTH);
    HFASSERT(off + len >= off);
    HFASSERT(off + len <= [dat length]);
    offset = off;
    length = len;
    data = [dat retain];
    [data incrementUser];
    inlineTailLength = tailLen;
    memcpy(inlineTail, tail, tailLen);
    return self;
}

- (void)dealloc {
    [data decrementUser];
    [data release];
    [super dealloc];
}

- (void)finalize {
    [data decrementUser];
    [super finalize];    
}

- (unsigned long long)length {
    return length + inlineTailLength;
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)lrange  {
    HFASSERT(HFSum(length, inlineTailLength) >= HFMaxRange(lrange));
    NSRange requestedRange = NSMakeRange(ll2l(lrange.location), ll2l(lrange.length));
    NSRange dataRange = NSMakeRange(0, length);
    NSRange tailRange = NSMakeRange(length, inlineTailLength);
    NSRange dataRangeToCopy = NSIntersectionRange(requestedRange, dataRange);
    NSRange tailRangeToCopy = NSIntersectionRange(requestedRange, tailRange);
    HFASSERT(HFSum(dataRangeToCopy.length, tailRangeToCopy.length) == lrange.length);
    
    if (dataRangeToCopy.length > 0) {
        HFASSERT(HFSum(NSMaxRange(dataRangeToCopy), offset) <= [data length]);
        const void *bytes = [data bytes];
        memcpy(dst, bytes + dataRangeToCopy.location + offset, dataRangeToCopy.length);
    }
    if (tailRangeToCopy.length > 0) {
        HFASSERT(tailRangeToCopy.location >= length);
        HFASSERT(NSMaxRange(tailRangeToCopy) - length <= inlineTailLength);
        memcpy(dst + dataRangeToCopy.length, inlineTail + tailRangeToCopy.location - length, tailRangeToCopy.length);
    }
}

- (HFByteSlice *)subsliceWithRange:(HFRange)lrange {
    HFASSERT(lrange.length > 0);
    HFASSERT(HFSum(length, inlineTailLength) >= HFMaxRange(lrange));
    NSRange requestedRange = NSMakeRange(ll2l(lrange.location), ll2l(lrange.length));
    NSRange dataRange = NSMakeRange(0, length);
    NSRange tailRange = NSMakeRange(length, inlineTailLength);
    NSRange dataRangeToCopy = NSIntersectionRange(requestedRange, dataRange);
    NSRange tailRangeToCopy = NSIntersectionRange(requestedRange, tailRange);
    HFASSERT(HFSum(dataRangeToCopy.length, tailRangeToCopy.length) == lrange.length);
    
    HFSharedData *resultData = NULL;
    NSUInteger resultOffset = 0;
    NSUInteger resultLength = 0;
    const unsigned char *tail = NULL;
    NSUInteger tailLength = 0;
    if (dataRangeToCopy.length > 0) {
        resultData = data;
        HFASSERT(resultData != NULL);
        resultOffset = offset + dataRangeToCopy.location;
        resultLength = dataRangeToCopy.length;
        HFASSERT(resultLength > 0 && resultLength < length);
    }
    if (tailRangeToCopy.length > 0) {
        tail = inlineTail + tailRangeToCopy.location - length;
        tailLength = tailRangeToCopy.length;
        HFASSERT(tail >= inlineTail && tail + tailLength <= inlineTail + inlineTailLength);
    }
    HFASSERT(resultLength + tailLength == lrange.length);
    return [[[[self class] alloc] initWithSharedData:resultData offset:resultOffset length:resultLength tail:tail tailLength:tailLength] autorelease];
}

/* Fast path methods */
- (BOOL)fastPathCanAppendAtLocation:(unsigned long long)location {
    HFASSERT(offset + length <= [data length]);
    HFASSERT(offset + length >= offset);
    unsigned dataLength = [data length];
    unsigned targetLength = offset + length;
    HFASSERT(dataLength > 0);
    HFASSERT(targetLength > 0);
    if (dataLength > targetLength) {
	//try to do the fast path delete
	if ([data userCount]==1) { //only one?  Gotta be us!
	    [data setLength:targetLength];
	    dataLength = [data length];
	}
    }
    return location==length && targetLength == dataLength;
}


- (HFByteSlice *)fastPathAppendByteSlice:(HFByteSlice *)slice atLocation:(unsigned long long)location {
    HFASSERT(MAX_FAST_PATH_SIZE <= UINT_MAX);
    
    if (! [self fastPathCanAppendAtLocation:location]) return nil;
    
    unsigned dataLength = [data length];
    unsigned long long ullSliceLength = [slice length];
    
    HFASSERT(dataLength + ullSliceLength >= ullSliceLength);
    
    
    if (ullSliceLength + [data length] > MAX_FAST_PATH_SIZE) return nil;
    
    [data increaseLengthBy:ll2l(ullSliceLength)];
    [slice copyBytes:dataLength + (unsigned char*)[data mutableBytes]
	       range:HFRangeMake(0, ullSliceLength)];
    
    return [[[[self class] alloc] initWithData:data offset:offset length:ll2l(length + ullSliceLength)] autorelease];
}


@end
