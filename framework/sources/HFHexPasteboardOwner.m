//
//  HFHexPasteboardOwner.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFHexPasteboardOwner.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFByteArray.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

static inline unsigned char hex2char(NSUInteger c) {
    HFASSERT(c < 16);
    return "0123456789ABCDEF"[c];
}

@implementation HFHexPasteboardOwner

- (unsigned long long)stringLengthForDataLength:(unsigned long long)dataLength {
    if(!dataLength) return 0;
    // -1 because no trailing space for an exact multiple.
    unsigned long long spaces = _bytesPerColumn ? (dataLength-1)/_bytesPerColumn : 0;
    if ((ULLONG_MAX - spaces)/2 <= dataLength) return ULLONG_MAX;
    else return dataLength*2 + spaces;
}

- (void)writeDataInBackgroundToPasteboard:(NSPasteboard *)pboard ofLength:(unsigned long long)length forType:(NSString *)type trackingProgress:(HFProgressTracker *)tracker {
    HFASSERT([type isEqual:NSPasteboardTypeString]);
    if(length == 0) {
        [pboard setString:@"" forType:type];
        return;
    }
    HFByteArray *byteArray = [self byteArray];
    NSString *string = [self stringFromByteArray:byteArray ofLength:length trackingProgress:tracker];
    [pboard setString:string forType:type];
}

- (NSString *)stringFromByteArray:(HFByteArray *)byteArray ofLength:(unsigned long long)length trackingProgress:(HFProgressTracker *)tracker {
    HFASSERT(length <= NSUIntegerMax);
    NSUInteger dataLength = ll2l(length);
    NSUInteger stringLength = ll2l([self stringLengthForDataLength:length]);
    HFASSERT(stringLength < ULLONG_MAX);
    NSUInteger offset = 0, stringOffset = 0, remaining = dataLength;
    volatile long long * const progressReportingPointer = (volatile long long *)&tracker->currentProgress;
    [tracker setMaxProgress:dataLength];
    unsigned char * restrict const stringBuffer = check_malloc(stringLength);
    if (_bytesPerColumn > 0) {
        memset(stringBuffer, ' ', stringLength);
    }
    while (remaining > 0) {
        if (tracker->cancelRequested) break;
        unsigned char dataBuffer[32 * 1024];
        NSUInteger amountToCopy = MIN(sizeof dataBuffer, remaining);
        [byteArray copyBytes:dataBuffer range:HFRangeMake(offset, amountToCopy)];

        for (NSUInteger i = 0; i < amountToCopy; i++, offset++, stringOffset += 2) {
            if (_bytesPerColumn > 0 && offset > 0 && (offset % _bytesPerColumn) == 0) {
                stringOffset++;
            }
            HFASSERT(i < sizeof(dataBuffer) && i < amountToCopy);
            unsigned char c = dataBuffer[i];
            HFASSERT(stringOffset < (stringLength - 1));
            stringBuffer[stringOffset] = hex2char(c >> 4);
            stringBuffer[stringOffset + 1] = hex2char(c & 0xF);
        }

        remaining -= amountToCopy;
        HFAtomicAdd64(amountToCopy, progressReportingPointer);
    }
    if (tracker->cancelRequested) {
        free(stringBuffer);
        return @"";
    } else {
        NSString *string = [[NSString alloc] initWithBytesNoCopy:stringBuffer length:stringLength encoding:NSASCIIStringEncoding freeWhenDone:YES];
        HFASSERT(string != nil);
        return string;
    }
}

@end
