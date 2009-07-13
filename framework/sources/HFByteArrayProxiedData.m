//
//  HFByteArrayDataProxy.m
//  HexFiend_2
//
//  Created by Peter Ammon on 7/9/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "HFByteArrayProxiedData.h"
#import <HexFiend/HFByteArray.h>


static BOOL backingIsByteArray(id val) {
    return [val isKindOfClass:[HFByteArray class]];
}

static NSData *newDataFromByteArray(HFByteArray *array) {
    HFASSERT(array != nil);
    HFASSERT([array length] <= NSIntegerMax);
    NSUInteger length = ll2l([array length]);
    if (length == 0) return [[NSData alloc] init];
    
    void *ptr = malloc(length);
    if (! ptr) return NULL;
    [array copyBytes:ptr range:HFRangeMake(0, length)];
    return [[NSData alloc] initWithBytesNoCopy:ptr length:length freeWhenDone:YES];
}

@implementation HFByteArrayProxiedData

- (id)initWithByteArray:(HFByteArray *)array {
    HFASSERT(array != nil);
    HFASSERT([array length] <= NSIntegerMax);
    NSUInteger dataLength = ll2l([array length]);
    [super init];
    length = dataLength;
    byteArray = [array copy];
    return self;
}

- (void)dealloc {
    [byteArray release];
    [serializedData release];
    [super dealloc];
}

- (NSUInteger)length {
    return length;
}

- (id)_getRetainedBacking {
    id result = nil;
    @synchronized(self) {
        if (serializedData) result = [serializedData retain];
        else result = [byteArray retain];
    }
    return result;
    
}

- (const void *)bytes {
    HFByteArray *byteArrayToRelease = nil;
    NSData *resultingData = nil;
    @synchronized(self) {
        if (serializedData == nil) {
            HFASSERT(byteArray != nil);
            serializedData = newDataFromByteArray(byteArray);
            byteArrayToRelease = byteArray;
            byteArray = nil;
        }
        resultingData = serializedData;
    }
    [byteArrayToRelease release];
    return [resultingData bytes];
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
    id backing = [self _getRetainedBacking];
    if (backingIsByteArray(backing)) {
        [(HFByteArray *)backing copyBytes:buffer range:HFRangeMake(range.location, range.length)];
    }
    else {
        [(NSData *)backing getBytes:buffer range:range];
    }
    [backing release];
}

@end
