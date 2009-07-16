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

static unsigned char munge(unsigned long long val64, unsigned char randomizer) __attribute__((always_inline));
static inline unsigned char munge(unsigned long long val64, unsigned char randomizer) {
    uint32_t val32 = (uint32_t)val64 ^ (uint32_t)(val64 >> 32);
    uint16_t val16 = (uint16_t)val32 ^ (uint16_t)(val32 >> 16);
    uint8_t val8 = (uint8_t)val16 ^ (uint8_t)(val16 >> 8);
    return randomizer ^ (unsigned char)val8;
}

@implementation HFRandomDataByteSlice

- (id)initWithRandomDataLength:(unsigned long long)len {
    [super init];
    start = 0;
    length = len;    
    randomizer = (unsigned char)random();
    return self;
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
    HFRandomDataByteSlice *result = [[[[self class] alloc] initWithRandomDataLength:range.length] autorelease];
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
            unsigned int val = (unsigned int)random();
            if (random() & 1) {
                val |= (1u << 31);
            }
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
