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
    [view setAutoresizingMask:NSViewHeightSizable];
    return view;
}

- (HFByteArrayDataStringType)byteArrayDataStringType {
    UNIMPLEMENTED();
}

- (HFRange)entireDisplayedRange {
    HFController *controller = [self controller];
    unsigned long long contentsLength = [controller contentsLength];
    HFASSERT(controller != NULL);
    HFFPRange displayedLineRange = [controller displayedLineRange];
    NSUInteger bytesPerLine = [controller bytesPerLine];
    unsigned long long lineStart = HFFPToUL(floorl(displayedLineRange.location));
    unsigned long long lineEnd = HFFPToUL(ceill(displayedLineRange.location + displayedLineRange.length));
    HFASSERT(lineEnd >= lineStart);
    HFRange byteRange = HFRangeMake(HFProductULL(bytesPerLine, lineStart), HFProductULL(lineEnd - lineStart, bytesPerLine));
    HFASSERT(byteRange.location <= contentsLength);
    byteRange.length = MIN(byteRange.length, contentsLength - byteRange.location);
    HFASSERT(HFRangeIsSubrangeOfRange(byteRange, HFRangeMake(0, [controller contentsLength])));
    return byteRange;
}

- (void)updateText {
    HFController *controller = [self controller];
    HFRepresenterTextView *view = [self view];
    [view setData:[controller dataForRange:[self entireDisplayedRange]]];
    HFFPRange lineRange = [controller displayedLineRange];
    long double offsetLongDouble = lineRange.location - floorl(lineRange.location);
    CGFloat offset = ld2f(offsetLongDouble);
    [view setVerticalOffset:offset];
    [view setStartingLineBackgroundColorIndex:ll2l(HFFPToUL(floorl(lineRange.location)) % NSUIntegerMax)];
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

- (double)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
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
    HFRange displayedRange = [self entireDisplayedRange];

    HFASSERT(displayedRange.length <= NSUIntegerMax);
    NEW_ARRAY(NSValue *, clippedSelectedRanges, [selectedRanges count]);
    NSUInteger clippedRangeIndex = 0;
    FOREACH(HFRangeWrapper *, wrapper, selectedRanges) {
        HFRange selectedRange = [wrapper HFRange];
        BOOL clippedRangeIsVisible;
        NSRange clippedSelectedRange;
        /* Necessary because zero length ranges do not intersect anything */
        if (selectedRange.length == 0) {
            /* Remember that {6, 0} is not considered a subrange of {3, 3} */
            clippedRangeIsVisible = HFRangeIsSubrangeOfRange(selectedRange, displayedRange) || selectedRange.location == HFSum(displayedRange.length, displayedRange.location);
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

- (unsigned long long)byteIndexForCharacterIndex:(NSUInteger)characterIndex {
    HFController *controller = [self controller];
    HFFPRange lineRange = [controller displayedLineRange];
    unsigned long long scrollAmount = HFFPToUL(floorl(lineRange.location));
    unsigned long long byteIndex = HFProductULL(scrollAmount, [controller bytesPerLine]) + characterIndex;
    return byteIndex;
}

- (void)beginSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] beginSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}

- (void)continueSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] continueSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}

- (void)endSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] endSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}

- (void)insertText:(NSString *)text {
    USE(text);
    UNIMPLEMENTED_VOID();
}

@end
