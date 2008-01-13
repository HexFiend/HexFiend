//
//  HFASCIITextRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFStringEncodingTextRepresenter.h>
#import <HexFiend/HFRepresenterStringEncodingTextView.h>
#import <HexFiend/HFPasteboardOwner.h>

@interface HFStringEncodingPasteboardOwner : HFPasteboardOwner {
    NSStringEncoding encoding;
}
- (void)setEncoding:(NSStringEncoding)val;
- (NSStringEncoding)encoding;
@end

@implementation HFStringEncodingPasteboardOwner
- (void)setEncoding:(NSStringEncoding)val { encoding = val; }
- (NSStringEncoding)encoding { return encoding; }

- (void)pasteboard:(NSPasteboard *)pboard provideDataForType:(NSString *)type {
    if ([type isEqualToString:NSStringPboardType]) {
        /* Don't know how to handle these yet - is this sufficient to assert that the string encoding has one byte per character?  Ack */
        HFASSERT(HFStringEncodingIsSupersetOfASCII(encoding));
        HFByteArray *bytes = [self byteArray];
        HFASSERT([bytes length] <= NSUIntegerMax);
        NSUInteger length = ll2l([bytes length]);
        unsigned char * const buffer = check_malloc(length);
        [bytes copyBytes:buffer range:HFRangeMake(0, length)];
        NSString *string = [[NSString alloc] initWithBytesNoCopy:buffer length:length encoding:encoding freeWhenDone:YES];
        [pboard setString:string forType:type];
        [string release];
    }
    else {
        [super pasteboard:pboard provideDataForType:type];
    }
}

@end

@implementation HFStringEncodingTextRepresenter

- (Class)_textViewClass {
    return [HFRepresenterStringEncodingTextView class];
}

- (NSStringEncoding)encoding {
    return [[self view] encoding];
}

- (void)setEncoding:(NSStringEncoding)encoding {
    [[self view] setEncoding:encoding];
}

- (void)initializeView {
    [super initializeView];
    [[self view] setEncoding:NSMacOSRomanStringEncoding];
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
