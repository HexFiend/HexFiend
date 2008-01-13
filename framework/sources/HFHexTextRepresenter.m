//
//  HFHexTextRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFRepresenterHexTextView.h>
#import <HexFiend/HFPasteboardOwner.h>

@interface HFHexPasteboardOwner : HFPasteboardOwner {
    
}
@end

static unsigned char hex2char(NSUInteger c) {
    HFASSERT(c < 16);
    return "0123456789ABCDEF"[c];
}

@implementation HFHexPasteboardOwner

- (void)pasteboard:(NSPasteboard *)pboard provideDataForType:(NSString *)type {
    if ([type isEqual:NSStringPboardType]) {
        HFByteArray *byteArray = [self byteArray];
        HFASSERT([byteArray length] <= NSUIntegerMax);
        NSUInteger dataLength = ll2l([byteArray length]);
        HFASSERT(dataLength < NSUIntegerMax / 3);
        NSUInteger stringLength = dataLength * 3;
        NSUInteger offset = 0, remaining = dataLength;
        unsigned char * const stringBuffer = check_malloc(stringLength);
        while (remaining > 0) {
            unsigned char dataBuffer[256];
            NSUInteger amountToCopy = MIN(sizeof dataBuffer, remaining);
            [byteArray copyBytes:dataBuffer range:HFRangeMake(offset, amountToCopy)];
            for (NSUInteger i = 0; i < amountToCopy; i++) {
                unsigned char c = dataBuffer[i];
                stringBuffer[offset*3 + i*3] = hex2char(c >> 4);
                stringBuffer[offset*3 + i*3 + 1] = hex2char(c & 0xF);
                stringBuffer[offset*3 + i*3 + 2] = ' ';
            }
            offset += amountToCopy;
            remaining -= amountToCopy;
        }
        NSString *string = [[NSString alloc] initWithBytesNoCopy:stringBuffer length:stringLength - MIN(stringLength, 1) encoding:NSASCIIStringEncoding freeWhenDone:YES];
        [pboard setString:string forType:type];
        [string release];
    }
    else {
        [super pasteboard:pboard provideDataForType:type];
    }
}

@end

@implementation HFHexTextRepresenter

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
            HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
            result = (selectedRange.length == 0 && selectedRange.location == omittedNybbleLocation);
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
    HFASSERT([text length] > 0);
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
    [controller insertData:data replacingPreviousBytes: (shouldReplacePriorByte ? 1 : 0) allowUndoCoalescing:YES];
    if (isMissingLastNybble) {
        HFASSERT([data length] > 0);
        HFASSERT(unpartneredLastNybble == UCHAR_MAX);
        [data getBytes:&unpartneredLastNybble range:NSMakeRange([data length] - 1, 1)];
        NSArray *selectedRanges = [controller selectedContentsRanges];
        HFASSERT([selectedRanges count] == 1);
        HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
        HFASSERT(selectedRange.length == 0);
        omittedNybbleLocation = selectedRange.location;
    }
    else {
        [self _clearOmittedNybble];
    }
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
    }
    else {
        HFHexPasteboardOwner *owner = [HFHexPasteboardOwner ownPasteboard:pb forByteArray:selection withTypes:[NSArray arrayWithObjects:HFPrivateByteArrayPboardType, NSStringPboardType, nil]];
        [owner setBytesPerLine:[self bytesPerLine]];
    }
}

@end
