//
//  HFFileByteSlice.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFByteSlice_Private.h"
#import <HexFiend/HFFileByteSlice.h>
#import <HexFiend/HFFileReference.h>
#import <HexFiend/HFByteRangeAttribute.h>
#import <HexFiend/HFByteRangeAttributeArray.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

@implementation HFFileByteSlice

- (instancetype)initWithFile:(HFFileReference *)file {
    REQUIRE_NOT_NULL(file);
    return [self initWithFile:file offset:0 length:[file length]];
}

- (instancetype)initWithFile:(HFFileReference *)file offset:(unsigned long long)off length:(unsigned long long)len {
    HFASSERT(HFSum(off, len) <= [file length]);
    REQUIRE_NOT_NULL(file);
    self = [super init];
    fileReference = file;
    offset = off;
    length = len;
    return self;
}

- (unsigned long long)length { return length; }

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(dst != NULL || range.length == 0);
    HFASSERT(range.length <= NSUIntegerMax);
    HFASSERT(range.length <= length);
    [fileReference readBytes:dst length:ll2l(range.length) from:HFSum(range.location, offset)];
}

- (HFByteSlice *)subsliceWithRange:(HFRange)range {
    HFASSERT(offset + length >= offset);
    HFASSERT(range.length > 0);
    HFASSERT(range.location < [self length]);
    HFASSERT([self length] - range.location >= range.length);
    if (range.location == 0 && range.length == length) return self;
    return [[[self class] alloc] initWithFile:fileReference offset:range.location + offset length:range.length];
}

- (BOOL)isSourcedFromFile {
    return YES;
}

- (HFRange)sourceRangeForFile:(HFFileReference *)reference {
    REQUIRE_NOT_NULL(reference);
    HFRange result = {ULLONG_MAX, ULLONG_MAX};
    if ([fileReference isEqual:reference]) {
        result.location = offset;
        result.length = length;
    }
    return result;
}

- (HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range {
    HFByteRangeAttributeArray *result = nil;
    HFASSERT(HFMaxRange(range) <= [self length]);
    /* Middle half of file is magic */
    unsigned long long fileLength = [fileReference length];
    HFRange magicRange = HFRangeMake(fileLength / 4, fileLength / 2);
//    printf("Magic location: %llu\n", fileLength / 4);
    HFRange intersectionRange = HFIntersectionRange(magicRange, range);
    if (intersectionRange.length > 0) {
        //result = [[[HFByteRangeAttributeArray alloc] init] autorelease];
        [result addAttribute:kHFAttributeMagic range:intersectionRange];
    }
    return result;
}

@end
