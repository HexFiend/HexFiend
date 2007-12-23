//
//  HFByteArray.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArray.h>
#import <HexFiend/HFFullMemoryByteSlice.h>


@implementation HFByteArray

- init {
    if ([self class] == [HFByteArray class]) {
        [NSException raise:NSInvalidArgumentException format:@"init sent to HFByteArray, but HFByteArray is an abstract class.  Instantiate one of its subclasses instead."];
    }
    return [super init];
}

- (NSArray *)byteSlices { UNIMPLEMENTED(); }
- (unsigned long long)length { UNIMPLEMENTED(); }
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range { USE(dst); USE(range); UNIMPLEMENTED_VOID(); }
- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange { USE(slice); USE(lrange); UNIMPLEMENTED_VOID(); }


- (void)insertByteArray:(HFByteArray*)array inRange:(HFRange)lrange {
    REQUIRE_NOT_NULL(array);
    NSArray* slices = [array byteSlices];
    unsigned i, max=[slices count];
    if (max==0) [self deleteBytesInRange:lrange];
    else {
	for (i=0; i < max; i++) {
            HFByteSlice* slice = [slices objectAtIndex:i];
            [self insertByteSlice:slice inRange:lrange];
            lrange.location += [slice length];
            lrange.length = 0;
	}
    }
}

- (HFByteArray *)subarrayWithRange:(HFRange)range { USE(range); UNIMPLEMENTED(); }

- (void)deleteBytesInRange:(HFRange)lrange {
    HFByteSlice* slice = [[HFFullMemoryByteSlice alloc] initWithData:[NSData data]];
    [self insertByteSlice:slice inRange:lrange];
    [slice release];
}

- (BOOL)isEqual:v {
    REQUIRE_NOT_NULL(v);
    if (self == v) return YES;
    else if (! [v isKindOfClass:[HFByteArray class]]) return NO;
    else {
        HFByteArray* obj = v;
        unsigned long long length = [self length];
        if (length != [obj length]) return NO;
        unsigned long long offset;
        unsigned char buffer1[1024];
        unsigned char buffer2[sizeof buffer1 / sizeof *buffer1];
        for (offset = 0; offset < length; offset += sizeof buffer1) {
            size_t amountToGrab = sizeof buffer1;
            if (amountToGrab > length - offset) amountToGrab = ll2l(length - offset);
            [self copyBytes:buffer1 range:HFRangeMake(offset, amountToGrab)];
            [obj copyBytes:buffer2 range:HFRangeMake(offset, amountToGrab)];
            if (memcmp(buffer1, buffer2, amountToGrab)) return NO;
        }
    }
    return YES;
}

- (BOOL)_debugIsEqual:v {
    REQUIRE_NOT_NULL(v);
    if (! [v isKindOfClass:[HFByteArray class]]) return NO;
    HFByteArray* obj = v;
    unsigned long long length = [self length];
    if (length != [obj length]) return NO;
    
    unsigned long long offset;
    unsigned char buffer1[1024];
    unsigned char buffer2[sizeof buffer1 / sizeof *buffer1];
    for (offset = 0; offset < length; offset += sizeof buffer1) {
        memset(buffer1, 0, sizeof buffer1);
        memset(buffer2, 0, sizeof buffer2);
        size_t amountToGrab = sizeof buffer1;
        if (amountToGrab > length - offset) amountToGrab = ll2l(length - offset);
        [self copyBytes:buffer1 range:HFRangeMake(offset, amountToGrab)];
        [obj copyBytes:buffer2 range:HFRangeMake(offset, amountToGrab)];
        size_t i;
        for (i=0; i < amountToGrab; i++) {
            if (buffer1[i] != buffer2[i]) {
                printf("Inconsistency found at %llu (%02x versus %02x)\n", i + offset, buffer1[i], buffer2[i]);
                return NO;
            }
        }
    }
    return YES;
}

@end
