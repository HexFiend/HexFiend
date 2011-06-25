//
//  HFAttributedByteArray.m
//  HexFiend_2
//
//  Created by Peter Ammon on 6/25/11.
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFAttributedByteArray.h>
#import <HexFiend/HFByteRangeAttributeArray.h>

@implementation HFAttributedByteArray

- (id)initWithImplementingByteArray:(HFByteArray *)newImpl attributes:(HFByteRangeAttributeArray *)newAttrs {
    [super init];
    impl = [newImpl retain];
    attributes = [newAttrs retain];
    return self;
}

- (id)init {
    HFBTreeByteArray *arr = [[HFBTreeByteArray alloc] init];
    HFByteRangeAttributeArray *attr = [[HFByteRangeAttributeArray alloc] init];
    [self initWithImplementingByteArray:arr attributes:attr];
    [arr release];
    [attr release];
    return self;
}

- (void)dealloc {
    [attributes release];
    [impl release];
    [super dealloc];
}

/* Interesting HFByteArray overrides */

- (HFByteArray *)subarrayWithRange:(HFRange)range {
    
    HFRange beforeRange = HFRangeMake(0, range.location), afterRange = HFRangeMake(HFMaxRange(range), [self length] - HFMaxRange(range));
    
    HFByteArray *newImpl = [[impl subarrayWithRange:range] retain];
    HFByteRangeAttributeArray *newAttrs = [attributes mutableCopy];
    
    // Fix up the ranges. Be sure to do the after range first, since the before range will affect the subsequence offsets!
    if (afterRange.length) [newAttrs byteRange:afterRange wasReplacedByBytesOfLength:0];
    if (beforeRange.length) [newAttrs byteRange:beforeRange wasReplacedByBytesOfLength:0];
    
    HFAttributedByteArray *result = [[[self class] alloc] initWithImplementingByteArray:newImpl attributes:newAttrs];
    [newImpl release];
    [newAttrs release];
    return result;
}

- (void)deleteBytesInRange:(HFRange)range {
    [impl deleteBytesInRange:range];
    [attributes byteRange:range wasReplacedByBytesOfLength:0];
}

- (void)insertByteArray:(HFByteArray *)array inRange:(HFRange)lrange {
    [impl insertByteArray:array inRange:lrange];
    [attributes byteRange:lrange wasReplacedByBytesOfLength:[array length]];
}

- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange {
    [impl insertByteSlice:slice inRange:lrange];
    [attributes byteRange:lrange wasReplacedByBytesOfLength:[slice length]];
}

- (HFByteSlice *)sliceContainingByteAtIndex:(unsigned long long)offset beginningOffset:(unsigned long long *)actualOffset {
    return [impl sliceContainingByteAtIndex:offset beginningOffset:actualOffset];
}

- (HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range {
    HFByteRangeAttributeArray *result = [impl attributesForBytesInRange:range];
    /* Transfer from attributes */
    if (! [attributes isEmpty]) {
        [result transferAttributesFromAttributeArray:attributes range:range baseOffset:0];
    }
    return result;
}

- (HFByteRangeAttributeArray *)byteRangeAttributeArray {
    return attributes;
}

/* Boring HFByteArray overrides */

- (void)incrementGenerationOrRaiseIfLockedForSelector:(SEL)sel {
    /* Nobody should call this */
    [NSException raise:NSInternalInconsistencyException format:@"incrementGenerationOrRaiseIfLockedForSelector:@selector(%s) called directly on HFAttributedByteArray", sel_getName(sel)];
}

- (NSUInteger)changeGenerationCount { return [impl changeGenerationCount]; }
- (void)incrementChangeLockCounter { [impl incrementChangeLockCounter]; }
- (void)decrementChangeLockCounter { [impl decrementChangeLockCounter]; }
- (BOOL)changesAreLocked { return [impl changesAreLocked]; }

- (NSEnumerator *)byteSliceEnumerator {
    return [impl byteSliceEnumerator];
}

- (NSArray *)byteSlices {
    return [impl byteSlices];
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    [impl copyBytes:dst range:range];
}

- (unsigned long long)length {
    return [impl length];
}

@end
