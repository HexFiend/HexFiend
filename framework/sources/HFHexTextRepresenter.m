//
//  HFHexTextRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFRepresenterHexTextView.h>
#import <HexFiend/HFPasteboardOwner.h>
#import <HexFiend/HFProgressTracker.h>

@interface HFHexPasteboardOwner : HFPasteboardOwner {
    NSUInteger _bytesPerColumn;
}
@property (nonatomic) NSUInteger bytesPerColumn;
@end

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
        [string release];
    }
}

@end

@implementation HFHexTextRepresenter

/* No extra NSCoder support needed */

- (Class)_textViewClass {
    return [HFRepresenterHexTextView class];
}

- (void)initializeView {
    [super initializeView];
    [[self view] setBytesBetweenVerticalGuides:4];
    unpartneredLastNybble = UCHAR_MAX;
    omittedNybbleLocation = ULLONG_MAX;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, 0);
}

- (void)_clearOmittedNybble {
    unpartneredLastNybble = UCHAR_MAX;
    omittedNybbleLocation = ULLONG_MAX;
}

- (BOOL)_insertionShouldDeleteLastNybble {
    /* Either both the omittedNybbleLocation and unpartneredLastNybble are invalid (set to their respective maxima), or neither are */
    HFASSERT((omittedNybbleLocation == ULLONG_MAX) == (unpartneredLastNybble == UCHAR_MAX));
    /* We should delete the last nybble if our omittedNybbleLocation is the point where we would insert */
    BOOL result = NO;
    if (omittedNybbleLocation != ULLONG_MAX) {
        HFController *controller = [self controller];
        NSArray *selectedRanges = [controller selectedContentsRanges];
        if ([selectedRanges count] == 1) {
            HFRange selectedRange = [selectedRanges[0] HFRange];
            result = (selectedRange.length == 0 && selectedRange.location > 0 && selectedRange.location - 1 == omittedNybbleLocation);
        }
    }
    return result;
}

- (BOOL)_canInsertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    NSCharacterSet *characterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789ABCDEFabcdef"];
    return [text rangeOfCharacterFromSet:characterSet].location != NSNotFound;
}

- (void)insertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    if (! [self _canInsertText:text]) {
        /* The user typed invalid data, and we can ignore it */
        return;
    }
    
    BOOL shouldReplacePriorByte = [self _insertionShouldDeleteLastNybble];
    if (shouldReplacePriorByte) {
        HFASSERT(unpartneredLastNybble < 16);
        /* Prepend unpartneredLastNybble as a nybble */
        text = [NSString stringWithFormat:@"%1X%@", unpartneredLastNybble, text];
    }
    BOOL isMissingLastNybble;
    NSData *data = HFDataFromHexString(text, &isMissingLastNybble);
    HFASSERT([data length] > 0);
    HFASSERT(shouldReplacePriorByte != isMissingLastNybble);
    HFController *controller = [self controller];
    BOOL success = [controller insertData:data replacingPreviousBytes: (shouldReplacePriorByte ? 1 : 0) allowUndoCoalescing:YES];
    if (isMissingLastNybble && success) {
        HFASSERT([data length] > 0);
        HFASSERT(unpartneredLastNybble == UCHAR_MAX);
        [data getBytes:&unpartneredLastNybble range:NSMakeRange([data length] - 1, 1)];
        NSArray *selectedRanges = [controller selectedContentsRanges];
        HFASSERT([selectedRanges count] >= 1);
        HFRange selectedRange = [selectedRanges[0] HFRange];
        HFASSERT(selectedRange.location > 0);
        omittedNybbleLocation = HFSubtract(selectedRange.location, 1);
    }
    else {
        [self _clearOmittedNybble];
    }
}

- (NSData *)dataFromPasteboardString:(NSString *)string {
    REQUIRE_NOT_NULL(string);
    return HFDataFromHexString(string, NULL);
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    [super controllerDidChange:bits];
    if (bits & (HFControllerContentValue | HFControllerContentLength | HFControllerSelectedRanges)) {
        [self _clearOmittedNybble];
    }
}

- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb {
    REQUIRE_NOT_NULL(pb);
    HFByteArray *selection = [[self controller] byteArrayForSelectedContentsRanges];
    HFASSERT(selection != NULL);
    if ([selection length] == 0) {
        NSBeep();
    } else {
        HFHexPasteboardOwner *owner = [HFHexPasteboardOwner ownPasteboard:pb forByteArray:selection withTypes:@[HFPrivateByteArrayPboardType, NSStringPboardType]];
        [owner setBytesPerLine:[self bytesPerLine]];
        owner.bytesPerColumn = self.bytesPerColumn;
    }
}

@end
