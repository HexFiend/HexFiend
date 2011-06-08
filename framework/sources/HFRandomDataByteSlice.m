//
//  HFRandomDataByteSlice.m
//  HexFiend_2
//
//  Created by peter on 1/2/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

/* NOTE - THIS FILE IS COMPILED -O3 EVEN IN DEBUG BUILDS BECAUSE OF THE MUNGE LOOP (extra build flags for this file in Xcode) */

#import <HexFiend/HFRandomDataByteSlice.h>

//#if ! NDEBUG

const unsigned char kPearsonTable[256] = {43, 253, 36, 72, 5, 247, 65, 255,
    192, 34, 112, 238, 180, 246, 155, 114, 91, 99, 172, 152, 157, 89, 145, 44, 119, 9, 116, 83, 4, 53, 213, 143, 245, 39, 135, 109, 133, 56, 78, 138, 232, 170, 191, 215, 7, 249, 237, 6, 159, 113, 2, 55, 23, 63, 121, 88, 166, 21, 251, 136, 8, 169, 252, 225, 229, 97, 70, 216, 51, 103, 184, 243, 176, 198, 219, 79, 204, 236, 14, 235, 217, 47, 96, 163, 242, 158, 48, 153, 223, 208, 98, 95, 210, 30, 146, 13, 74, 50, 86, 122, 94, 203, 211, 131, 102, 190, 33, 218, 224, 118, 248, 178, 181, 108, 196, 80, 20, 24, 93, 162, 0, 46, 231, 38, 132, 194, 123, 40, 142, 151, 125, 197, 35, 28, 164, 10, 49, 110, 71, 32, 175, 92, 67, 58, 200, 179, 195, 31, 201, 61, 161, 189, 107, 168, 52, 209, 250, 139, 75, 29, 59, 64, 134, 128, 160, 227, 239, 205, 100, 149, 177, 41, 54, 130, 1, 233, 185, 84, 182, 207, 188, 156, 101, 117, 22, 199, 3, 141, 167, 27, 69, 26, 226, 202, 12, 124, 127, 106, 73, 17, 60, 62, 129, 115, 57, 212, 187, 15, 126, 104, 25, 148, 120, 105, 165, 154, 76, 240, 150, 193, 77, 111, 137, 173, 254, 87, 11, 16, 144, 19, 68, 140, 147, 45, 174, 37, 214, 241, 90, 230, 171, 66, 221, 220, 81, 244, 228, 186, 206, 222, 18, 183, 42, 85, 234, 82};


static unsigned char munge(unsigned long long val64, unsigned char randomizer) __attribute__((always_inline));
static inline unsigned char munge(unsigned long long val64, unsigned char randomizer) {
    unsigned long long remainingToHash = val64;
    unsigned char result = randomizer;
    result = kPearsonTable[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = kPearsonTable[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = kPearsonTable[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = kPearsonTable[result ^ (remainingToHash)];
    return result;
}

@implementation HFRandomDataByteSlice

- (id)initWithLength:(unsigned long long)len randomizer:(unsigned char)val {
    [super init];
    start = 0;
    length = len;    
    randomizer = val;
    return self;
}

- (id)initWithRandomDataLength:(unsigned long long)len {
    return [self initWithLength:len randomizer:(unsigned char)arc4random()];
}


- (unsigned long long)length {
    return length;
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, length)));
    HFASSERT(range.length <= NSUIntegerMax);
    const unsigned long long localRandomizer = randomizer;
    unsigned long long i = start + range.location;
    NSUInteger count = ll2l(range.length);
    NSUInteger countPrefix = count % 16;
    NSUInteger countGroups = count / 16;
    while (countPrefix--) {
        *dst++ = munge(i++, localRandomizer);
    }
    while (countGroups--) {
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);
        *dst++ = munge(i++, localRandomizer);        
    }
    
}

- (HFByteSlice *)subsliceWithRange:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, length)));
    HFRandomDataByteSlice *result = [[[[self class] alloc] initWithLength:range.length randomizer:randomizer] autorelease];
    result->start = range.location;
    return result;
}


@end

@implementation HFRepeatingDataByteSlice

#define REPEATING_DATA_LENGTH (1024 * 1024 * 4)
static unsigned char *kRepeatingData;

+ (void)initialize {
    if (! kRepeatingData) {
        kRepeatingData = malloc(REPEATING_DATA_LENGTH);
        unsigned int *ptr = (unsigned int *)kRepeatingData;
        NSUInteger i = REPEATING_DATA_LENGTH / sizeof *ptr;
        while (i--) {
            unsigned int val = (unsigned int)arc4random();
            *ptr++ = val;
        }
    }
}

- (id)initWithRepeatingDataLength:(unsigned long long)len {
    [super init];
    start = 0;
    length = len;
    return self;
}

- (unsigned long long)length {
    return length;
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, length)));
    HFASSERT(range.length <= NSUIntegerMax);
    NSUInteger offset = ll2l(HFSum(start, range.location) % REPEATING_DATA_LENGTH);
    NSUInteger remaining = ll2l(range.length);
    NSUInteger copied = 0;
    while (remaining > 0) {
        NSUInteger amountToCopy = MIN(remaining, REPEATING_DATA_LENGTH - offset);
        memcpy(dst + copied, kRepeatingData + offset, amountToCopy);
        remaining -= amountToCopy;
        copied += amountToCopy;
        offset = 0;
    }
}

- (HFByteSlice *)subsliceWithRange:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, length)));
    HFRepeatingDataByteSlice *result = [[[[self class] alloc] initWithRepeatingDataLength:range.length] autorelease];
    result->start = range.location;
    return result;
}

@end

//#endif //NDEBUG
