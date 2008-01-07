//
//  HFASCIITextRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFStringEncodingTextRepresenter.h>
#import <HexFiend/HFRepresenterStringEncodingTextView.h>


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
        [[self controller] insertData:data replacingPreviousBytes:0];
    }
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(1, 0);
}

@end
