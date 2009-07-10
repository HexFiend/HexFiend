//
//  HFByteArrayDataProxy.m
//  HexFiend_2
//
//  Created by Peter Ammon on 7/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "HFByteArrayDataProxy.h"


@implementation HFByteArrayDataProxy

- (id)initWithByteArray:(HFByteArray *)array {
    HFASSERT(array != nil);
    HFASSERT([array length] <= NSIntegerMax);
    length = ll2l([array length]);
    [super init];
    byteArray = [array copy];
    return self;
}

- (void)dealloc {
    [byteArray release];
    [underlyingData release];
    [super dealloc];
}

- (NSUInteger)length {
    return length;
}

- (const void *)bytes {
    return NULL;
}

- (id)copyWithZone:(NSZone *)zone {
    USE(zone);
    return [self retain];
}

- (void)getBytes:(void *)buffer {
    return [self getBytes:buffer range:NSMakeRange(0, length)];
}

- (void)getBytes:(void *)buffer length:(NSUInteger)len {
    return [self getBytes:buffer range:NSMakeRange(0, len)];
}

- (void)getBytes:(void *)buffer range:(NSRange)range {
    if (underlyingData) {
	return [underlyingData getBytes:buffer range:range];
    }
    
    HFASSERT(range.length <= length && length - range.length >= range.location);
    if (range.length > 0) {
	//[self getBytes:buffer length:NSMakeRange(0, len)];
    }
}

@end
