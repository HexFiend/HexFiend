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
    NSUInteger length = ll2l(displayedContentsRange.length);
    unsigned char *buffer = check_malloc(length);
    [controller copyBytes:buffer range:displayedContentsRange];
    HFRepresenterTextView *view = [self view];
    [view setData:[NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES]];
    [view setNeedsDisplay:YES];
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

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    return [[self view] maximumBytesPerLineForViewWidth:viewWidth];
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    return [[self view] minimumViewWidthForBytesPerLine:bytesPerLine];
}

@end
