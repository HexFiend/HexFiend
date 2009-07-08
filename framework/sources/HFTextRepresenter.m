//
//  HFTextRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextRepresenter_Internal.h>
#import <HexFiend/HFRepresenterTextView.h>
#import <HexFiend/HFPasteboardOwner.h>
#import <HexFiend/HFByteArray.h>

@implementation HFTextRepresenter

- (Class)_textViewClass {
    UNIMPLEMENTED();
}

- (id)init {
    [super init];
    rowBackgroundColors = [[NSColor controlAlternatingRowBackgroundColors] copy];
    return self;
}

- (void)dealloc {
    [rowBackgroundColors release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeBool:behavesAsTextField forKey:@"HFBehavesAsTextField"];
    [coder encodeObject:rowBackgroundColors forKey:@"HFRowBackgroundColors"];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    behavesAsTextField = [coder decodeBoolForKey:@"HFBehavesAsTextField"];
    rowBackgroundColors = [[coder decodeObjectForKey:@"HFRowBackgroundColors"] retain];
    return self;
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
    if (byteRange.length == 0) {
	/* This can happen if we are too small to even show one line */
	return HFRangeMake(0, 0);
    }
    else {
	HFASSERT(byteRange.location <= contentsLength);
	byteRange.length = MIN(byteRange.length, contentsLength - byteRange.location);
	HFASSERT(HFRangeIsSubrangeOfRange(byteRange, HFRangeMake(0, [controller contentsLength])));
	return byteRange;
    }
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
    HFRepresenterTextView *view = [self view];
    HFController *controller = [self controller];
    if (controller) {
        [view setFont:[controller font]];
        [view setEditable:[controller editable]];
        [self updateText];
    }
    else {
        [view setFont:[NSFont fontWithName:@"Monaco" size:(CGFloat)10.]];
    }
}

- (void)scrollWheel:(NSEvent *)event {
    [[self controller] scrollWithScrollEvent:event];
}

- (void)selectAll:(id)sender {
    [[self controller] selectAll:sender];
}

- (double)selectionPulseAmount {
    return [[self controller] selectionPulseAmount];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerFont | HFControllerLineHeight)) {
        [[self view] setFont:[[self controller] font]];
    }
    if (bits & (HFControllerContentValue | HFControllerDisplayedLineRange)) {
        [self updateText];
    }
    if (bits & (HFControllerSelectedRanges | HFControllerDisplayedLineRange)) {
        [[self view] updateSelectedRanges];
    }
    if (bits & (HFControllerSelectionPulseAmount)) {
        [[self view] updateSelectionPulse];
    }
    if (bits & (HFControllerEditable)) {
        [[self view] setEditable:[[self controller] editable]];
    }
    if (bits & (HFControllerAntialias)) {
        [[self view] setShouldAntialias:[[self controller] shouldAntialias]];
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
            /* Remember that {6, 0} is considered a subrange of {3, 3} */
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

- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb {
    USE(pb);
    UNIMPLEMENTED_VOID();
}

- (void)cutSelectedBytesToPasteboard:(NSPasteboard *)pb {
    [self copySelectedBytesToPasteboard:pb];
    [[self controller] deleteSelection];
}

- (NSData *)dataFromPasteboardString:(NSString *)string {
    USE(string);
    UNIMPLEMENTED();
}

- (BOOL)canPasteFromPasteboard:(NSPasteboard *)pb {
    REQUIRE_NOT_NULL(pb);
    if ([[self controller] editable]) {
        // we can paste if the pboard contains text or contains an HFByteArray
        return [HFPasteboardOwner unpackByteArrayFromPasteboard:pb] || [pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
    }
    return NO;
}

- (BOOL)canCut {
    /* We can cut if we are editable, we have at least one byte selected, and we are not in overwrite mode */
    HFController *controller = [self controller];
    if ([controller inOverwriteMode]) return NO;
    if (! [controller editable]) return NO;

    FOREACH(HFRangeWrapper *, rangeWrapper, [controller selectedContentsRanges]) {
        if ([rangeWrapper HFRange].length > 0) return YES; //we have something selected
    }
    return NO; // we did not find anything selected
}

- (BOOL)pasteBytesFromPasteboard:(NSPasteboard *)pb {
    REQUIRE_NOT_NULL(pb);
    BOOL result = NO;
    HFByteArray *byteArray = [HFPasteboardOwner unpackByteArrayFromPasteboard:pb];
    if (byteArray) {
        [[self controller] insertByteArray:byteArray replacingPreviousBytes:0 allowUndoCoalescing:NO];
        result = YES;
    }
    else {
        NSString *stringType = [pb availableTypeFromArray:[NSArray arrayWithObject:NSStringPboardType]];
        if (stringType) {
            NSString *stringValue = [pb stringForType:stringType];
            if (stringValue) {
                NSData *data = [self dataFromPasteboardString:stringValue];
                if (data) {
                    [[self controller] insertData:data replacingPreviousBytes:0 allowUndoCoalescing:NO];
                }
            }
        }
    }
    return result;
}

- (NSArray *)rowBackgroundColors {
    return rowBackgroundColors;
}

- (void)setRowBackgroundColors:(NSArray *)colors {
    if (colors != rowBackgroundColors) {
        [rowBackgroundColors release];
        rowBackgroundColors = [colors copy];
    }
}

- (void)setBehavesAsTextField:(BOOL)val {
    behavesAsTextField = val;
}

- (BOOL)behavesAsTextField {
    return behavesAsTextField;
}

@end
