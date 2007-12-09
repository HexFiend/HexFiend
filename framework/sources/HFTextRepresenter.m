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
    HFRepresenterTextView *view = [self view];
    HFRange contentsRange = HFRangeMake(0, [controller contentsLength]);
    HFRange displayedRange = [controller displayedContentsRange];
    if (displayedRange.length > 0 && contentsRange.length > 0) {
        HFASSERT(displayedRange.length < NSUIntegerMax);
        HFASSERT(HFIntersectsRange(displayedRange, contentsRange));
        HFRange displayedContentsRange = HFIntersectionRange(displayedRange, contentsRange);
        
        NSUInteger length = ll2l(displayedContentsRange.length);
        unsigned char *buffer = check_malloc(length);
        [controller copyBytes:buffer range:displayedContentsRange];
        [view setData:[NSData dataWithBytesNoCopy:buffer length:length freeWhenDone:YES]];
    }
    else {
        [view setData:[NSData data]];
    }
}

- (void)initializeView {
    [super initializeView];
    if ([self controller]) {
        [[self view] setFont:[[self controller] font]];
        [self updateText];
    }
    else {
        [[self view] setFont:[NSFont fontWithName:@"Monaco" size:(CGFloat)10.]];
    }
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerFont | HFControllerLineHeight)) {
        [[self view] setFont:[[self controller] font]];
    }
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

- (void)insertText:(NSString *)text {
    USE(text);
    UNIMPLEMENTED_VOID();
}

@end
