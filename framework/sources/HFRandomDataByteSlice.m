//
//  HFRandomDataByteSlice.m
//  HexFiend_2
//
//  Created by peter on 1/2/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

/* NOTE - THIS FILE IS COMPILED -O3 EVEN IN DEBUG BUILDS BECAUSE OF THE MUNGE LOOP (extra build flags for this file in Xcode) */

#import "HFRandomDataByteSlice.h"
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

//#if ! NDEBUG

static uint32_t my_random_uniform(uint32_t max) {
    /* Generate a value in the range [0, max), uniformly distributed. To do this, we compute the largest multiple of max that fits in 32 bits, then roll until we get a value equal to or below that. */
    const uint32_t rand_max = (1U << 31);
    HFASSERT(max <= rand_max);
    uint32_t maxRollValue = (uint32_t)(UINT32_MAX - (UINT32_MAX % rand_max));
    uint32_t rollValue;
    do {
        rollValue = (uint32_t)random();
    } while (rollValue > maxRollValue);
    return rollValue % max;
}

static NSData *createPearsonTable(void) {
    // The "inside out" variation of Knuth shuffle
    unsigned char result[256];
    result[0] = 0;
    for (uint32_t i=1; i < 256; i++) {
        uint32_t j = my_random_uniform(i+1); //returns a value in the range [0, i]
        result[i] = result[j];
        result[j] = (unsigned char)i;
    }
    return [[NSData alloc] initWithBytes:result length:sizeof result];
}

__attribute__((always_inline))
static inline unsigned char munge(unsigned long long val64, const unsigned char *restrict pearson) {
    unsigned long long remainingToHash = val64;
    unsigned char result = 0;
    result = pearson[/*result*/0 ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = pearson[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = pearson[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = pearson[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = pearson[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = pearson[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = pearson[result ^ (remainingToHash & 0xFF)]; remainingToHash >>= 8;
    result = pearson[result ^ (remainingToHash & 0xFF)]; //remainingToHash >>= 8;

    return result;
}

@implementation HFRandomDataByteSlice

- (instancetype)initWithLength:(unsigned long long)len pearsonTable:(NSData *)table {
    self = [super init];
    start = 0;
    length = len;
    pearsonTable = [table copy];
    return self;
}

- (instancetype)initWithRandomDataLength:(unsigned long long)len {
    NSData *table = createPearsonTable();
    self = [self initWithLength:len pearsonTable:table];
    return self;
}


- (unsigned long long)length {
    return length;
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, length)));
    HFASSERT(range.length <= NSUIntegerMax);
    const unsigned char *restrict pearson = [pearsonTable bytes];
    unsigned long long i = start + range.location;
    NSUInteger count = ll2l(range.length);
    NSUInteger countPrefix = count % 16;
    NSUInteger countGroups = count / 16;
    while (countPrefix--) {
        *dst++ = munge(i++, pearson);
    }
    while (countGroups--) {
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);
        *dst++ = munge(i++, pearson);        
    }
    
}

- (HFByteSlice *)subsliceWithRange:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, length)));
    HFRandomDataByteSlice *result = [[[self class] alloc] initWithLength:range.length pearsonTable:pearsonTable];
    result->start = self->start + range.location;
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
            unsigned int val = (unsigned int)random();
            *ptr++ = val;
        }
    }
}

- (instancetype)initWithRepeatingDataLength:(unsigned long long)len {
    self = [super init];
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
    HFRepeatingDataByteSlice *result = [[[self class] alloc] initWithRepeatingDataLength:range.length];
    result->start = range.location;
    return result;
}

@end

//#endif //NDEBUG



