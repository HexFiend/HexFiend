//
//  ByteArray_ToString.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/5/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArray.h>

enum
{
    HFHexDataStringType,
    HFASCIIDataStringType
};

typedef NSUInteger HFByteArrayDataStringType;

@interface HFByteArray (HFToString)

- (NSString *)convertRangeOfBytes:(HFRange)range toStringWithType:(HFByteArrayDataStringType)type withBytesPerLine:(NSUInteger)bytesPerLine;

@end
