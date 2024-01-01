//
//  HFASCIITextRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFStringEncodingTextRepresenter.h>
#import <HexFiend/HFAssert.h>
#import <HexFiend/HFRepresenterStringEncodingTextView.h>
#import <HexFiend/HFPasteboardOwner.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFEncodingManager.h>
#import <HexFiend/HFFunctions.h>

@interface HFStringEncodingPasteboardOwner : HFPasteboardOwner
@property HFStringEncoding* encoding;
@end

@implementation HFStringEncodingPasteboardOwner

- (void)writeDataInBackgroundToPasteboard:(NSPasteboard *)pboard ofLength:(unsigned long long)length forType:(NSString *)type trackingProgress:(HFProgressTracker *)tracker {
    HFASSERT([type isEqual:NSPasteboardTypeString]);
    HFByteArray *byteArray = [self byteArray];
    HFASSERT(length <= NSUIntegerMax);
    NSUInteger dataLength = ll2l(length);
    NSUInteger stringLength = dataLength;
    NSUInteger offset = 0, remaining = dataLength;
    volatile long long * const progressReportingPointer = (volatile long long *)&tracker->currentProgress;
    [tracker setMaxProgress:dataLength];
    unsigned char * restrict const stringBuffer = check_malloc(stringLength);
    while (remaining > 0) {
        if (tracker->cancelRequested) break;
        NSUInteger amountToCopy = MIN(32u * 1024u, remaining);
        [byteArray copyBytes:stringBuffer + offset range:HFRangeMake(offset, amountToCopy)];
        offset += amountToCopy;
        remaining -= amountToCopy;
        HFAtomicAdd64(amountToCopy, progressReportingPointer);
    }
    NSString *string = @"";
    if (!tracker->cancelRequested) {
        string = [self.encoding stringFromBytes:stringBuffer length:stringLength];
    }
    free(stringBuffer);
    [pboard setString:string forType:type];
}

- (unsigned long long)stringLengthForDataLength:(unsigned long long)dataLength {
    return dataLength;
}

@end

@implementation HFStringEncodingTextRepresenter
{
    HFStringEncoding *stringEncoding;
}

- (instancetype)init {
    self = [super init];
    stringEncoding = [HFEncodingManager shared].ascii;
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    stringEncoding = [coder decodeObjectForKey:@"HFStringEncoding"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:stringEncoding forKey:@"HFStringEncoding"];
}

- (Class)_textViewClass {
    return [HFRepresenterStringEncodingTextView class];
}

- (HFStringEncoding *)encoding {
    return stringEncoding;
}

- (void)setEncoding:(HFStringEncoding *)encoding {
    stringEncoding = encoding;
    [(HFRepresenterStringEncodingTextView *)[self view] setEncoding:encoding];
    [[self controller] representer:self changedProperties:HFControllerViewSizeRatios];
}

- (void)initializeView {
    [(HFRepresenterStringEncodingTextView *)[self view] setEncoding:stringEncoding];
    [super initializeView];
}

- (void)insertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    NSData *data = [self.encoding dataFromString:text];
    if (! data) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSString *key = @"HFStringEncodingConversionFailureShowAlert";
            if (![[NSUserDefaults standardUserDefaults] objectForKey:key]) {
                NSAlert *alert = [[NSAlert alloc] init];
                alert.messageText = NSLocalizedString(@"Failed to convert text", "");
                alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"The text \"%@\" could not be converted to the current encoding \"%@\". The encoding may not support these characters.", ""), text, self.encoding.name];
                (void)[alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
                (void)[alert addButtonWithTitle:NSLocalizedString(@"Do Not Show Again", "")];
                if ([alert runModal] == NSAlertSecondButtonReturn) {
                    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
                }
            }
        });
        NSLog(@"%s: Can't convert \"%@\" to encoding %@", __PRETTY_FUNCTION__, text, self.encoding.name);
        NSBeep();
    }
    else if ([data length]) { // a 0 length text can come about via e.g. option-e
        [[self controller] insertData:data replacingPreviousBytes:0 allowUndoCoalescing:YES];
    }
}

- (NSData *)dataFromPasteboardString:(NSString *)string {
    REQUIRE_NOT_NULL(string);
    return [self.encoding dataFromString:string];
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(3, 0);
}

- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb {
    return [self copySelectedBytesToPasteboard:pb encoding:[self encoding]];
}

- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb encoding:(HFStringEncoding *)enc {
    REQUIRE_NOT_NULL(pb);
    HFByteArray *selection = [[self controller] byteArrayForSelectedContentsRanges];
    HFASSERT(selection != NULL);
    if ([selection length] == 0) {
        NSBeep();
    }
    else {
        HFStringEncodingPasteboardOwner *owner = [HFStringEncodingPasteboardOwner ownPasteboard:pb forByteArray:selection withTypes:@[HFPrivateByteArrayPboardType, NSPasteboardTypeString]];
        [owner setEncoding:enc];
        [owner setBytesPerLine:[self bytesPerLine]];
    }
}

@end
