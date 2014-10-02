//
//  HFFullMemoryByteSlice.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "HFFullMemoryByteSlice.h"


@implementation HFFullMemoryByteSlice

- (instancetype)initWithData:(NSData *)val {
    REQUIRE_NOT_NULL(val);
    self = [super init];
    data = [val copy];
    return self;
}

- (void)dealloc {
    [data release];
    [super dealloc];
}

- (unsigned long long)length { return [data length]; }

- (void)copyBytes:(unsigned char *)dst range:(HFRange)lrange {
    NSRange range;
    HFASSERT(lrange.location <= NSUIntegerMax);
    HFASSERT(lrange.length <= NSUIntegerMax);
    HFASSERT(lrange.location + lrange.length >= lrange.location);
    range.location = ll2l(lrange.location);
    range.length = ll2l(lrange.length);
    [data getBytes:dst range:range];
}

- (HFByteSlice *)subsliceWithRange:(HFRange)range {
    HFASSERT(range.length > 0);
    HFASSERT(range.location < [self length]);
    HFASSERT([self length] - range.location >= range.length);
    HFASSERT(range.location <= NSUIntegerMax);
    HFASSERT(range.length <= NSUIntegerMax);
    return [[[[self class] alloc] initWithData:[data subdataWithRange:NSMakeRange(ll2l(range.location), ll2l(range.length))]] autorelease];
}

@end
