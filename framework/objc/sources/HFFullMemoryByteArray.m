//
//  HFFullMemoryByteArray.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "HFByteArray_Internal.h"
#import "HFFullMemoryByteArray.h"
#import "HFFullMemoryByteSlice.h"
#import "HFByteSlice.h"
#import "HFByteRangeAttributeArray.h"
#import "HFFunctions.h"
#import "HFAssert.h"

@implementation HFFullMemoryByteArray

- (instancetype)init {
    self = [super init];
    data = [[NSMutableData alloc] init];
    return self;
}

- (unsigned long long)length {
    return [data length];
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(range.length == 0 || dst != NULL);
    HFASSERT(HFSumDoesNotOverflow(range.location, range.length));
    HFASSERT(range.location + range.length <= [self length]);
    unsigned char* bytes = [data mutableBytes];
    memmove(dst, bytes + ll2l(range.location), ll2l(range.length));
}

- (HFByteArray *)subarrayWithRange:(HFRange)lrange {
    HFRange entireRange = HFRangeMake(0, [self length]);
    HFASSERT(HFRangeIsSubrangeOfRange(lrange, entireRange));
    NSRange range;
    range.location = ll2l(lrange.location);
    range.length = ll2l(lrange.length);
    HFFullMemoryByteArray* result = [[[self class] alloc] init];
    [result->data setData:[data subdataWithRange:range]];
    return result;
}

- (NSArray *)byteSlices {
    return @[[[HFFullMemoryByteSlice alloc] initWithData:data]];
}

- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange {
    [self incrementGenerationOrRaiseIfLockedForSelector:_cmd];
    HFASSERT([slice length] <= NSUIntegerMax);
    NSUInteger length = ll2l([slice length]);
    NSRange range;
    HFASSERT(lrange.location <= NSUIntegerMax);
    HFASSERT(lrange.length <= NSUIntegerMax);
    HFASSERT(HFSumDoesNotOverflow(lrange.location, lrange.length));
    range.location = ll2l(lrange.location);
    range.length = ll2l(lrange.length);
    
    void* buff = check_malloc(length);
    [slice copyBytes:buff range:HFRangeMake(0, length)];
    [data replaceBytesInRange:range withBytes:buff length:length];
    free(buff);    
}

@end
