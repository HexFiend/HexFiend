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
    NSFont *font = [NSFont fontWithName:@"Monaco" size:(CGFloat)10.];
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
    HFASSERT(displayedContentsRange.length < NSUIntegerMax);
    NSUInteger length = ll2l(displayedContentsRange.length);
    unsigned char *buffer = check_malloc(length);
    [controller copyBytes:buffer range:displayedContentsRange];
    HFRepresenterTextView *view = [self view];
    [view setData:[NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES]];
}

- (void)initializeView {
    [super initializeView];
    if ([self controller]) [self updateText];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerContentValue | HFControllerDisplayedRange)) {
        [self updateText];
    }
    if (bits & (HFControllerSelectedRanges | HFControllerDisplayedRange)) {
        [[self view] updateSelectedRanges];
    }
    [super controllerDidChange:bits];
}

- (NSUInteger)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
    return [[self view] maximumAvailableLinesForViewHeight:viewHeight];
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    return [[self view] maximumBytesPerLineForViewWidth:viewWidth];
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    return [[self view] minimumViewWidthForBytesPerLine:bytesPerLine];
}

- (NSArray *)displayedSelectedContentsRanges {
    HFController *controller = [self controller];
    NSArray *result;
    NSArray *selectedRanges = [controller selectedContentsRanges];
    HFRange displayedRange = [controller displayedContentsRange];
    HFASSERT(displayedRange.length <= NSUIntegerMax);
    NEW_ARRAY(NSValue *, clippedSelectedRanges, [selectedRanges count]);
    NSUInteger clippedRangeIndex = 0;
    FOREACH(HFRangeWrapper *, wrapper, selectedRanges) {
        HFRange selectedRange = [wrapper HFRange];
        BOOL clippedRangeIsVisible;
        NSRange clippedSelectedRange;
        /* Necessary because zero length ranges do not intersect anything */
        if (selectedRange.length == 0) {
            clippedRangeIsVisible = HFRangeIsSubrangeOfRange(selectedRange, displayedRange);
            if (clippedRangeIsVisible) {
                HFASSERT(selectedRange.location >= displayedRange.location);
                clippedSelectedRange.location = ll2l(selectedRange.location - displayedRange.location);
                clippedSelectedRange.length = 0;
            }
        }
        else {
            // selectedRange.length > 0
            clippedRangeIsVisible = HFIntersectsRange(selectedRange, displayedRange);
            if (clippedRangeIsVisible) {
                HFRange intersectionRange = HFIntersectionRange(selectedRange, displayedRange);
                HFASSERT(intersectionRange.location >= displayedRange.location);
                clippedSelectedRange.location = ll2l(intersectionRange.location - displayedRange.location);
                clippedSelectedRange.length = ll2l(intersectionRange.length);
            }
        }
        if (clippedRangeIsVisible) clippedSelectedRanges[clippedRangeIndex++] = [NSValue valueWithRange:clippedSelectedRange];
    }
    result = [NSArray arrayWithObjects:clippedSelectedRanges count:clippedRangeIndex];
    FREE_ARRAY(clippedSelectedRanges);
    return result;
}

- (void)beginSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    HFController *controller = [self controller];
    HFRange displayedRange = [controller displayedContentsRange];
    unsigned long long byteIndex = displayedRange.location + characterIndex;
    HFASSERT(HFLocationInRange(byteIndex, displayedRange) || byteIndex == displayedRange.location + displayedRange.length);
    [controller beginSelectionWithEvent:event forByteIndex:byteIndex];
}

- (void)continueSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    HFController *controller = [self controller];
    HFRange displayedRange = [controller displayedContentsRange];
    unsigned long long byteIndex = displayedRange.location + characterIndex;
    HFASSERT(HFLocationInRange(byteIndex, displayedRange) || byteIndex == displayedRange.location + displayedRange.length);
    [controller continueSelectionWithEvent:event forByteIndex:byteIndex];
}

- (void)endSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    HFController *controller = [self controller];
    HFRange displayedRange = [controller displayedContentsRange];
    unsigned long long byteIndex = displayedRange.location + characterIndex;
    HFASSERT(HFLocationInRange(byteIndex, displayedRange) || byteIndex == displayedRange.location + displayedRange.length);
    [controller endSelectionWithEvent:event forByteIndex:byteIndex];
}

@end
