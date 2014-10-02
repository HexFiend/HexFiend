//
//  HFByteSlice.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>


@implementation HFByteSlice

- (instancetype)init {
    if ([self class] == [HFByteSlice class]) {
        [NSException raise:NSInvalidArgumentException format:@"init sent to HFByteArray, but HFByteArray is an abstract class.  Instantiate one of its subclasses instead."];
    }
    return [super init];
}

- (unsigned long long)length { UNIMPLEMENTED(); }

- (void)copyBytes:(unsigned char*)dst range:(HFRange)range { USE(dst); USE(range); UNIMPLEMENTED_VOID(); }

- (HFByteSlice *)subsliceWithRange:(HFRange)range { USE(range); UNIMPLEMENTED(); }

- (void)constructNewByteSlicesAboutRange:(HFRange)range first:(HFByteSlice **)first second:(HFByteSlice **)second {
    const unsigned long long length = [self length];
    
    //clip the range to our extent
    range.location = llmin(range.location, length);
    range.length = llmin(range.length, length - range.location);
    
    HFRange firstRange = {0, range.location};
    HFRange secondRange = {range.location + range.length, [self length] - (range.location + range.length)};
    
    if (first) {
        if (firstRange.length > 0)
            *first = [self subsliceWithRange:firstRange];
        else
            *first = nil;
    }
    
    if (second) {
        if (secondRange.length > 0)
            *second = [self subsliceWithRange:secondRange];
        else
            *second = nil;
    }
}

- (HFByteSlice *)byteSliceByAppendingSlice:(HFByteSlice *)slice {
    USE(slice);
    return nil;
}

- (HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range {
    USE(range);
    return nil;
}

- (BOOL)isSourcedFromFile {
    return NO;
}

- (HFRange)sourceRangeForFile:(HFFileReference *)reference {
    USE(reference);
    return HFRangeMake(ULLONG_MAX, ULLONG_MAX);
}

- (id)retain {
    HFAtomicIncrement(&retainCount, NO);
    return self;
}

- (oneway void)release {
    if (HFAtomicDecrement(&retainCount, NO) == (NSUInteger)(-1)) {
        [self dealloc];
    }
}

- (NSUInteger)retainCount {
    return 1 + retainCount;
}

@end
