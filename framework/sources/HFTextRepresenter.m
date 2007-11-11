//
//  HFTextRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFTextRepresenter.h"
#import "HFRepresenterTextView.h"

@implementation HFTextRepresenter

- (Class)_textViewClass {
    UNIMPLEMENTED();
}

- (NSView *)createView {
    HFRepresenterTextView *view = [[[self _textViewClass] alloc] initWithRepresenter:self];
    NSFont *font = [NSFont fontWithName:@"Monaco" size:10.];
    [view setFont:font];
    return view;
}


- (HFByteArrayDataStringType)byteArrayDataStringType {
    UNIMPLEMENTED();
}

- (void)updateText {
    HFController *controller = [self controller];
    HFASSERT(controller != NULL);
    HFRange displayedContentsRange = [controller displayedContentsRange];
    HFASSERT(displayedContentsRange.length < ULONG_MAX);
    NSString *string = [[controller byteArray] convertRangeOfBytes:displayedContentsRange toStringWithType:[self byteArrayDataStringType] withBytesPerLine:16];
    
    string = @"00009779B22BB00BA88AB33B0DD002200DD0022023324BB456655BB56336F22F0550B33B0AA0EBBE0AA0F55F0330322313316EE61441344330036666FEEF00009BB9B22BA44AB11BADDA5995022059950220833863364EE40DD000003883288237732DD25115322342241AA14AA403306226FEEF5665FEEF5DD5FEEF00009CC9ACCAB11BFFFFAEEA600602206006022083381441344364460AA030030FF048840110333331132EE222225555FEEF399332236556FEEF5CC5FEEF00009669B88BB66BB77B95599AA902209AA902204334633650053EE363369BB9199194490550BBBB0AA0BCCB0AA0BAAB0AA0B99B0AA0D88DFEEFDBBDFEEF0BB001106006FEEF6116FEEF5CC5FEEF011003306CC60CC008800110FFFFFFFF000000008778255260063443EAAE8668D11DE55E50055005000066662DD213310000C77C3553277200001881344323321BB17FF7FFFFAFFAE22E3FF3C77C899880080000000000000000000000000000000000000000000000000000000000000000000000000000000000002EE206600AA0177101102FF21EE11771044000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";
    string = [string stringByAppendingString:string];
    string = [string stringByAppendingString:string];
    
    HFASSERT(string != NULL);
    [[self view] setString:string];
}

- (void)initializeView {
    [super initializeView];
    if ([self controller]) [self updateText];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerContentValue | HFControllerDisplayedRange)) {
        [self updateText];
    }
    [super controllerDidChange:bits];
}

@end
