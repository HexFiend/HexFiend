//
//  HFASCIITextRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFStringEncodingTextRepresenter.h>
#import <HexFiend/HFRepresenterStringEncodingTextView.h>
#import <HexFiend/HFPasteboardOwner.h>
#import <HexFiend/HFProgressTracker.h>

@interface HFStringEncodingPasteboardOwner : HFPasteboardOwner {
    NSStringEncoding encoding;
}
- (void)setEncoding:(NSStringEncoding)val;
- (NSStringEncoding)encoding;
@end

@implementation HFStringEncodingPasteboardOwner
- (void)setEncoding:(NSStringEncoding)val { encoding = val; }
- (NSStringEncoding)encoding { return encoding; }

- (void)writeDataInBackgroundToPasteboard:(NSPasteboard *)pboard ofLength:(unsigned long long)length forType:(NSString *)type trackingProgress:(HFProgressTracker *)tracker {
    HFASSERT([type isEqual:NSStringPboardType]);
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
	NSUInteger amountToCopy = MIN(32 * 1024, remaining);
	[byteArray copyBytes:stringBuffer + offset range:HFRangeMake(offset, amountToCopy)];
	offset += amountToCopy;
	remaining -= amountToCopy;
	HFAtomicAdd64(amountToCopy, progressReportingPointer);
    }
    if (tracker->cancelRequested) {
	[pboard setString:@"" forType:type];
	free(stringBuffer);
    }
    else {
	NSString *string = [[NSString alloc] initWithBytesNoCopy:stringBuffer length:stringLength encoding:NSASCIIStringEncoding freeWhenDone:YES];
	[pboard setString:string forType:type];
	[string release];
    }
}

- (unsigned long long)stringLengthForDataLength:(unsigned long long)dataLength {
    return dataLength;
}

@end

@implementation HFStringEncodingTextRepresenter

- (id)init {
    [super init];
    stringEncoding = [NSString defaultCStringEncoding];
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    stringEncoding = (NSStringEncoding)[coder decodeInt64ForKey:@"HFStringEncoding"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeInt64:stringEncoding forKey:@"HFStringEncoding"];
}

- (Class)_textViewClass {
    return [HFRepresenterStringEncodingTextView class];
}

- (NSStringEncoding)encoding {
    return stringEncoding;
}

- (void)setEncoding:(NSStringEncoding)encoding {
    stringEncoding = encoding;
    [[self view] setEncoding:encoding];
}

- (void)initializeView {
    [super initializeView];
    [[self view] setEncoding:stringEncoding];
}

- (void)insertText:(NSString *)text {
    REQUIRE_NOT_NULL(text);
    NSData *data = [text dataUsingEncoding:[self encoding] allowLossyConversion:NO];
    if (! data) {
        NSBeep();
    }
    else {
        [[self controller] insertData:data replacingPreviousBytes:0 allowUndoCoalescing:YES];
    }
}

- (NSData *)dataFromPasteboardString:(NSString *)string  {
    REQUIRE_NOT_NULL(string);
    return [string dataUsingEncoding:[self encoding] allowLossyConversion:NO];
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(1, 0);
}

- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb {
    REQUIRE_NOT_NULL(pb);
    HFByteArray *selection = [[self controller] byteArrayForSelectedContentsRanges];
    HFASSERT(selection != NULL);
    if ([selection length] == 0) {
        NSBeep();
    }
    else {
        HFStringEncodingPasteboardOwner *owner = [HFStringEncodingPasteboardOwner ownPasteboard:pb forByteArray:selection withTypes:[NSArray arrayWithObjects:HFPrivateByteArrayPboardType, NSStringPboardType, nil]];
        [owner setEncoding:[self encoding]];
        [owner setBytesPerLine:[self bytesPerLine]];
    }
}

@end
