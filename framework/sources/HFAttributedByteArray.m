//
//  HFAttributedByteArray.m
//  HexFiend_2
//
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFAttributedByteArray.h>
#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFByteSlice.h>
#import <HexFiend/HFByteRangeAttributeArray.h>
#import <HexFiend/HFByteRangeAttribute.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

@implementation HFAttributedByteArray

- (instancetype)initWithImplementingByteArray:(HFByteArray *)newImpl attributes:(HFByteRangeAttributeArray *)newAttrs {
    self = [super init];
    impl = newImpl;
    attributes = newAttrs;
    return self;
}

- (instancetype)init {
    HFBTreeByteArray *arr = [[HFBTreeByteArray alloc] init];
    HFByteRangeAttributeArray *attr = [[HFAnnotatedTreeByteRangeAttributeArray alloc] init];
    self = [self initWithImplementingByteArray:arr attributes:attr];
    return self;
}

/* Interesting HFByteArray overrides */

- (HFByteArray *)subarrayWithRange:(HFRange)range {
    
    HFRange beforeRange = HFRangeMake(0, range.location), afterRange = HFRangeMake(HFMaxRange(range), [self length] - HFMaxRange(range));
    
    HFByteArray *newImpl = [impl subarrayWithRange:range];
    HFByteRangeAttributeArray *newAttrs = [attributes mutableCopy];
    
    // Fix up the ranges. Be sure to do the after range first, since the before range will affect the subsequence offsets!
    if (afterRange.length) [newAttrs byteRange:afterRange wasReplacedByBytesOfLength:0];
    if (beforeRange.length) [newAttrs byteRange:beforeRange wasReplacedByBytesOfLength:0];
    
    HFAttributedByteArray *result = [[[self class] alloc] initWithImplementingByteArray:newImpl attributes:newAttrs];
    return result;
}

- (void)deleteBytesInRange:(HFRange)range {
    [impl deleteBytesInRange:range];
    [attributes byteRange:range wasReplacedByBytesOfLength:0];
}

/* Hack to avoid certain attributes coming along for the ride (for example, in copy/paste). Attributes should really be a class. */
- (BOOL)shouldTransferAttribute:(NSString *)attribute {
    if ([attribute isEqualToString:kHFAttributeDiffInsertion] || [attribute isEqualToString:kHFAttributeFocused]) {
        /* Don't move Insertion or Focused attributes (related to diff documents). */
        return NO;
    } else if (HFBookmarkFromBookmarkAttribute(attribute) != NSNotFound) {
        /* Disallow duplicate bookmarks */
        return HFRangeEqualsRange([attributes rangeOfAttribute:attribute], HFRangeMake(ULLONG_MAX, ULLONG_MAX));
    } else {
        return YES;
    }
}

- (void)insertByteArray:(HFByteArray *)array inRange:(HFRange)lrange {
    const unsigned long long insertedLength = [array length];
    [impl insertByteArray:array inRange:lrange];
    [attributes byteRange:lrange wasReplacedByBytesOfLength:insertedLength];
    HFByteRangeAttributeArray *insertedAttributes = [array byteRangeAttributeArray];    
    if (insertedAttributes && ! [insertedAttributes isEmpty]) {
        /* Transfer attributes */
        [attributes transferAttributesFromAttributeArray:insertedAttributes range:HFRangeMake(0, insertedLength) baseOffset:lrange.location validator:^(NSString *attr) {
            return [self shouldTransferAttribute:attr]; 
        }];
    }
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
        [result transferAttributesFromAttributeArray:attributes range:range baseOffset:0 validator:NULL];
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
- (NSEnumerator *)byteSliceEnumerator { return [impl byteSliceEnumerator]; }
- (NSArray *)byteSlices { return [impl byteSlices]; }
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range { [impl copyBytes:dst range:range]; }
- (unsigned long long)length { return [impl length]; }

@end

@implementation HFByteArray (HFAttributeExtensions)

- (HFByteRangeAttributeArray *)byteRangeAttributeArray {
    return nil;
}

- (HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range {
    HFByteRangeAttributeArray *result = [[HFAnnotatedTreeByteRangeAttributeArray alloc] init];
    HFASSERT(range.length < NSUIntegerMax);
    const unsigned long long rangeEnd = HFMaxRange(range);
    HFASSERT(rangeEnd <= [self length]);
    HFRange remainingRange = range;
    while (remainingRange.length > 0) {
        unsigned long long beginningOffset;
        HFByteSlice *slice = [self sliceContainingByteAtIndex:remainingRange.location beginningOffset:&beginningOffset];
        HFASSERT(beginningOffset <= remainingRange.location);
        unsigned long long sliceLength = [slice length];
        HFRange sliceRange = HFRangeMake(beginningOffset, sliceLength);
        HFRange overlap = HFIntersectionRange(sliceRange, remainingRange);
        
        HFByteRangeAttributeArray *sliceAttributes = [slice attributesForBytesInRange:HFRangeMake(overlap.location - beginningOffset, overlap.length)];
        if (sliceAttributes) {
            [result transferAttributesFromAttributeArray:sliceAttributes range:HFRangeMake(0, sliceLength) baseOffset:beginningOffset validator:NULL];
        }
        
        HFASSERT(overlap.location == remainingRange.location);
        remainingRange.location = HFSum(remainingRange.location, overlap.length);
        remainingRange.length = HFSubtract(remainingRange.length, overlap.length);
    }
    
    /* Transfer from arrayAttributes */
    HFByteRangeAttributeArray *arrayAttributes = [self byteRangeAttributeArray];
    if (arrayAttributes && ! [arrayAttributes isEmpty]) {
        [result transferAttributesFromAttributeArray:arrayAttributes range:range baseOffset:0 validator:NULL];
    }
    
    return result;
}

@end
