//
//  HFFullMemoryByteSlice.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFFullMemoryByteSlice.h"


@implementation HFFullMemoryByteSlice

- initWithData:(NSData *)val {
    REQUIRE_NOT_NULL(val);
    [super init];
    data = [val copy];
    return self;
}

- (void)dealloc {
    [data release];
    [super dealloc];
}

- (unsigned long long)length { return [data length]; }

- (void)copyBytes:(unsigned char *)dst range:(HFRange)lrange  {
    NSRange range;
    assert(lrange.location <= ULONG_MAX);
    assert(lrange.length <= ULONG_MAX);
    assert(lrange.location + lrange.length >= lrange.location);
    range.location = ll2l(lrange.location);
    range.length = ll2l(lrange.length);
    [data getBytes:dst range:range];
}

- (HFByteSlice *)subsliceWithRange:(HFRange)range {
    assert(range.length > 0);
    assert(range.location < [self length]);
    assert([self length] - range.location >= range.length);
    assert(range.location <= ULONG_MAX);
    assert(range.length <= ULONG_MAX);
    return [[[[self class] alloc] initWithData:[data subdataWithRange:NSMakeRange(ll2l(range.location), ll2l(range.length))]] autorelease];
}

@end
