//
//  HFSharedMemoryByteSlice.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteSlice_Private.h>
#import <HexFiend/HFSharedMemoryByteSlice.h>

#define MAX_FAST_PATH_SIZE (1 << 13)

#define MAX_TAIL_LENGTH (sizeof ((HFSharedMemoryByteSlice *)NULL)->inlineTail / sizeof *((HFSharedMemoryByteSlice *)NULL)->inlineTail)

@implementation HFSharedMemoryByteSlice

- (instancetype)initWithUnsharedData:(NSData *)unsharedData {
    self = [super init];
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
        data = [[NSMutableData alloc] initWithBytes:[unsharedData bytes] length:sharedAmount];
    }
    return self;
}

// retains, does not copy
- (instancetype)initWithData:(NSMutableData *)dat {
    REQUIRE_NOT_NULL(dat);
    return [self initWithData:dat offset:0 length:[dat length]];
}

- (instancetype)initWithData:(NSMutableData *)dat offset:(NSUInteger)off length:(NSUInteger)len {
    self = [super init];
    REQUIRE_NOT_NULL(dat);
    HFASSERT(off + len >= off); //check for overflow
    HFASSERT(off + len <= [dat length]);
    offset = off;
    length = len;
    data = [dat retain];
    return self;
}

- (instancetype)initWithSharedData:(NSMutableData *)dat offset:(NSUInteger)off length:(NSUInteger)len tail:(const void *)tail tailLength:(NSUInteger)tailLen {
    self = [super init];
    if (off || len) REQUIRE_NOT_NULL(dat);
    if (tailLen) REQUIRE_NOT_NULL(tail);
    HFASSERT(tailLen <= MAX_TAIL_LENGTH);
    HFASSERT(off + len >= off);
    HFASSERT(off + len <= [dat length]);
    offset = off;
    length = len;
    data = [dat retain];
    HFASSERT(tailLen <= UCHAR_MAX);
    inlineTailLength = (unsigned char)tailLen;
    memcpy(inlineTail, tail, tailLen);
    HFASSERT([self length] == tailLen + len);
    return self;
}

- (void)dealloc {
    [data release];
    [super dealloc];
}

- (unsigned long long)length {
    return length + inlineTailLength;
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)lrange {
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
    if (HFRangeEqualsRange(lrange, HFRangeMake(0, HFSum(length, inlineTailLength)))) return [[self retain] autorelease];
    
    HFByteSlice *result;
    HFASSERT(lrange.length > 0);
    HFASSERT(HFSum(length, inlineTailLength) >= HFMaxRange(lrange));
    NSRange requestedRange = NSMakeRange(ll2l(lrange.location), ll2l(lrange.length));
    NSRange dataRange = NSMakeRange(0, length);
    NSRange tailRange = NSMakeRange(length, inlineTailLength);
    NSRange dataRangeToCopy = NSIntersectionRange(requestedRange, dataRange);
    NSRange tailRangeToCopy = NSIntersectionRange(requestedRange, tailRange);
    HFASSERT(HFSum(dataRangeToCopy.length, tailRangeToCopy.length) == lrange.length);
    
    NSMutableData *resultData = NULL;
    NSUInteger resultOffset = 0;
    NSUInteger resultLength = 0;
    const unsigned char *tail = NULL;
    NSUInteger tailLength = 0;
    if (dataRangeToCopy.length > 0) {
        resultData = data;
        HFASSERT(resultData != NULL);
        resultOffset = offset + dataRangeToCopy.location;
        resultLength = dataRangeToCopy.length;
        HFASSERT(HFSum(resultOffset, resultLength) <= [data length]);
    }
    if (tailRangeToCopy.length > 0) {
        tail = inlineTail + tailRangeToCopy.location - length;
        tailLength = tailRangeToCopy.length;
        HFASSERT(tail >= inlineTail && tail + tailLength <= inlineTail + inlineTailLength);
    }
    HFASSERT(resultLength + tailLength == lrange.length);
    result = [[[[self class] alloc] initWithSharedData:resultData offset:resultOffset length:resultLength tail:tail tailLength:tailLength] autorelease];
    HFASSERT([result length] == lrange.length);
    return result;
}

- (HFByteSlice *)byteSliceByAppendingSlice:(HFByteSlice *)slice {
    REQUIRE_NOT_NULL(slice);
    const unsigned long long sliceLength = [slice length];
    if (sliceLength == 0) return self;
    
    const unsigned long long thisLength = [self length];
    
    HFASSERT(inlineTailLength <= MAX_TAIL_LENGTH);
    NSUInteger spaceRemainingInTail = MAX_TAIL_LENGTH - inlineTailLength;
    
    if (sliceLength <= spaceRemainingInTail) {
        /* We can do our work entirely within the tail */
        NSUInteger newTailLength = (NSUInteger)sliceLength + inlineTailLength;
        unsigned char newTail[MAX_TAIL_LENGTH];
        memcpy(newTail, inlineTail, inlineTailLength);
        [slice copyBytes:newTail + inlineTailLength range:HFRangeMake(0, sliceLength)];
        HFByteSlice *result = [[[[self class] alloc] initWithSharedData:data offset:offset length:length tail:newTail tailLength:newTailLength] autorelease];
        HFASSERT([result length] == HFSum(sliceLength, thisLength));
        return result;
    }
    else {
        /* We can't do our work entirely in the tail; see if we can append some shared data. */
        HFASSERT(offset + length >= offset);
        if (offset + length == [data length]) {
            /* We can append some shared data.  But impose some reasonable limit on how big our slice can get; this is 16 MB */
            if (HFSum(thisLength, sliceLength) < (1ULL << 24)) {
                NSUInteger newDataOffset = offset;
                NSUInteger newDataLength = length;
                unsigned char newDataTail[MAX_TAIL_LENGTH];
                unsigned char newDataTailLength = MAX_TAIL_LENGTH;
                NSMutableData *newData = (data ? data : [[[NSMutableData alloc] init] autorelease]);
                
                NSUInteger sliceLengthInt = ll2l(sliceLength);
                NSUInteger newTotalTailLength = sliceLengthInt + inlineTailLength;
                HFASSERT(newTotalTailLength >= MAX_TAIL_LENGTH);
                NSUInteger amountToShiftIntoSharedData = newTotalTailLength - MAX_TAIL_LENGTH;
                NSUInteger amountToShiftIntoSharedDataFromTail = MIN(amountToShiftIntoSharedData, inlineTailLength);
                NSUInteger amountToShiftIntoSharedDataFromNewSlice = amountToShiftIntoSharedData - amountToShiftIntoSharedDataFromTail;
                
                if (amountToShiftIntoSharedDataFromTail > 0) {
                    HFASSERT(amountToShiftIntoSharedDataFromTail <= inlineTailLength);
                    [newData appendBytes:inlineTail length:amountToShiftIntoSharedDataFromTail];
                    newDataLength += amountToShiftIntoSharedDataFromTail;
                }
                if (amountToShiftIntoSharedDataFromNewSlice > 0) {
                    HFASSERT(amountToShiftIntoSharedDataFromNewSlice <= [slice length]);
                    NSUInteger dataLength = offset + length + amountToShiftIntoSharedDataFromTail;
                    HFASSERT([newData length] == dataLength);
                    [newData setLength:dataLength + amountToShiftIntoSharedDataFromNewSlice];
                    [slice copyBytes:[newData mutableBytes] + dataLength range:HFRangeMake(0, amountToShiftIntoSharedDataFromNewSlice)];
                    newDataLength += amountToShiftIntoSharedDataFromNewSlice;
                }
                
                /* We've updated our data; now figure out the tail */
                NSUInteger amountOfTailFromNewSlice = sliceLengthInt - amountToShiftIntoSharedDataFromNewSlice;
                HFASSERT(amountOfTailFromNewSlice <= MAX_TAIL_LENGTH);
                [slice copyBytes:newDataTail + MAX_TAIL_LENGTH - amountOfTailFromNewSlice range:HFRangeMake(sliceLengthInt - amountOfTailFromNewSlice, amountOfTailFromNewSlice)];
                
                /* Copy the rest, if any, from the end of self */
                NSUInteger amountOfTailFromSelf = MAX_TAIL_LENGTH - amountOfTailFromNewSlice;
                HFASSERT(amountOfTailFromSelf <= inlineTailLength);
                if (amountOfTailFromSelf > 0) {
                    memcpy(newDataTail, inlineTail + inlineTailLength - amountOfTailFromSelf, amountOfTailFromSelf);
                }
                
                HFByteSlice *result = [[[[self class] alloc] initWithSharedData:newData offset:newDataOffset length:newDataLength tail:newDataTail tailLength:newDataTailLength] autorelease];
                HFASSERT([result length] == HFSum([slice length], [self length]));
                return result;
            }
        }
    }
    return nil;
}

@end
