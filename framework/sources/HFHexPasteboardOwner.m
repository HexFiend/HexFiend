//
//  HFHexPasteboardOwner.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFHexPasteboardOwner.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFByteArray.h>


static inline unsigned char hex2char(NSUInteger c) {
    HFASSERT(c < 16);
    return "0123456789ABCDEF"[c];
}

@implementation HFHexPasteboardOwner

@synthesize bytesPerColumn = _bytesPerColumn;

- (unsigned long long)stringLengthForDataLength:(unsigned long long)dataLength {
    if(!dataLength) return 0;
    // -1 because no trailing space for an exact multiple.
    unsigned long long spaces = _bytesPerColumn ? (dataLength-1)/_bytesPerColumn : 0;
    if ((ULLONG_MAX - spaces)/2 <= dataLength) return ULLONG_MAX;
    else return dataLength*2 + spaces;
}

- (void)writeDataInBackgroundToPasteboard:(NSPasteboard *)pboard ofLength:(unsigned long long)length forType:(NSString *)type trackingProgress:(HFProgressTracker *)tracker {
    HFASSERT([type isEqual:NSStringPboardType]);
    if(length == 0) {
        [pboard setString:@"" forType:type];
        return;
    }
    HFByteArray *byteArray = [self byteArray];
    HFASSERT(length <= NSUIntegerMax);
    NSUInteger dataLength = ll2l(length);
    NSUInteger stringLength = ll2l([self stringLengthForDataLength:length]);
    HFASSERT(stringLength < ULLONG_MAX);
    NSUInteger offset = 0, stringOffset = 0, remaining = dataLength;
    volatile long long * const progressReportingPointer = (volatile long long *)&tracker->currentProgress;
    [tracker setMaxProgress:dataLength];
    unsigned char * restrict const stringBuffer = check_malloc(stringLength);
    while (remaining > 0) {
        if (tracker->cancelRequested) break;
        unsigned char dataBuffer[32 * 1024];
        NSUInteger amountToCopy = MIN(sizeof dataBuffer, remaining);
        NSUInteger bound = offset + amountToCopy - 1;
        [byteArray copyBytes:dataBuffer range:HFRangeMake(offset, amountToCopy)];

        if(_bytesPerColumn > 0 && offset > 0) { // ensure offset > 0 to skip adding a leading space
            NSUInteger left = _bytesPerColumn - (offset % _bytesPerColumn);
            if(left != _bytesPerColumn) {
                while(left-- > 0 && offset <= bound) {
                    unsigned char c = dataBuffer[offset++];
                    stringBuffer[stringOffset] = hex2char(c >> 4);
                    stringBuffer[stringOffset + 1] = hex2char(c & 0xF);
                    stringOffset += 2;
                }
            }
            if(offset <= bound)
                stringBuffer[stringOffset++] = ' ';
        }

        if(_bytesPerColumn > 0) while(offset+_bytesPerColumn <= bound) {
            for(NSUInteger j = 0; j < _bytesPerColumn; j++) {
                unsigned char c = dataBuffer[offset++];
                stringBuffer[stringOffset] = hex2char(c >> 4);
                stringBuffer[stringOffset + 1] = hex2char(c & 0xF);
                stringOffset += 2;
            }
            stringBuffer[stringOffset++] = ' ';
        }

        while (offset <= bound) {
            unsigned char c = dataBuffer[offset++];
            stringBuffer[stringOffset] = hex2char(c >> 4);
            stringBuffer[stringOffset + 1] = hex2char(c & 0xF);
            stringOffset += 2;
        }

        remaining -= amountToCopy;
        HFAtomicAdd64(amountToCopy, progressReportingPointer);
    }
    if (tracker->cancelRequested) {
        [pboard setString:@"" forType:type];
        free(stringBuffer);
    } else {
        NSString *string = [[NSString alloc] initWithBytesNoCopy:stringBuffer length:stringLength encoding:NSASCIIStringEncoding freeWhenDone:YES];
        [pboard setString:string forType:type];
    }
}

@end
