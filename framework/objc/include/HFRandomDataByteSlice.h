//
//  HFRandomDataByteSlice.h
//  HexFiend_2
//
//  Created by peter on 1/2/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

/* A byte slice used for testing, that represents a large amount of random data. */

#import "HFByteSlice.h"

//#if ! NDEBUG

@interface HFRandomDataByteSlice : HFByteSlice {
    unsigned long long start;
    unsigned long long length;
    NSData *pearsonTable;
}

- (instancetype)initWithRandomDataLength:(unsigned long long)length;

@end

@interface HFRepeatingDataByteSlice : HFByteSlice {
    unsigned long long start;
    unsigned long long length;
}

- (instancetype)initWithRepeatingDataLength:(unsigned long long)length;

@end

//#endif
