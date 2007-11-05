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
