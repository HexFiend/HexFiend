//
//  HFSharedData.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFSharedData.h>
#include <malloc/malloc.h>

@implementation HFSharedData

- (void *)mutableBytes {
    return bytes;
}

- (void *)bytes {
    return bytes;
}

- (NSUInteger)length {
    return length;
}

- (void)setLength:(NSUInteger)newLength {
    if (newLength > capacity) {
        NSUInteger newCapacity = malloc_good_size(newLength);
        HFASSERT(newCapacity >= newLength);
        HFASSERT(newCapacity > length);
        void *newData;
        if (objc_collectingEnabled()) {
            newData = NSReallocateCollectable(bytes, newCapacity, 0);
        }
        else {
           newData = realloc(bytes, newCapacity);
        }
        if (! newData) {
            [NSException raise:NSMallocException format:@"malloc failed to allocate %lu bytes", (unsigned long)newCapacity];
        }
        bytes = newData;
        capacity = newCapacity;
    }
    
    /* Zero out any new data */
    if (newLength > length) {
        bzero(bytes + length, newLength - length);
    }
    length = newLength;
}

- (void)incrementUser {
    if (0 == HFAtomicIncrement(&userCount, NO)) {
        [NSException raise:NSInvalidArgumentException format:@"User overflow for HFSharedData %@", self];
    }
}

- (void)decrementUser {
    if (NSUIntegerMax == HFAtomicDecrement(&userCount, NO)) {
        [NSException raise:NSInvalidArgumentException format:@"User underflow for HFSharedData %@", self];
    }
}

- (NSUInteger)userCount {
    return userCount;
}

- (void)dealloc {
    free(bytes);
    [super dealloc];
}

- initWithBytes:(const void *)inputBytes length:(NSUInteger)inputLen {
    [super init];
    [self setLength:inputLen];
    HFASSERT(inputLen == 0 || inputBytes != NULL);
    if (inputLen > 0) memcpy(bytes, inputBytes, inputLen);
    return self;
}

- initWithData:(NSData *)data {
    REQUIRE_NOT_NULL(data);
    return [self initWithBytes:[data bytes] length:[data length]];
}

@end
