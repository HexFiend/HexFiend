//
//  HFRepresenterVerticalScroller.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/12/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

/* Note that on Tiger, NSScroller did not support double in any meaningful way; [scroller doubleValue] always returns 0, and setDoubleValue: doesn't look like it works either. */

#import <HexFiend/HFVerticalScrollerRepresenter.h>


@implementation HFVerticalScrollerRepresenter

/* No special NSCoding support needed */

- (NSView *)createView {
    NSScroller *scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, [NSScroller scrollerWidthForControlSize:NSRegularControlSize], 64)];
    [scroller setTarget:self];
    [scroller setContinuous:YES];
    [scroller setEnabled:YES];
    [scroller setTarget:self];
    [scroller setAction:@selector(scrollerDidChangeValue:)];
    [scroller setFloatValue:.3f knobProportion:.4f];
    [scroller setAutoresizingMask:NSViewHeightSizable];
    return scroller;
}

- (NSUInteger)visibleLines {
    HFController *controller = [self controller];
    HFASSERT(controller != NULL);
    return ll2l(HFFPToUL(ceill([controller displayedLineRange].length)));
}

- (void)scrollByKnobToValue:(double)newValue {
    HFASSERT(newValue >= 0. && newValue <= 1.);
    HFController *controller = [self controller];
    unsigned long long contentsLength = [controller contentsLength];
    NSUInteger bytesPerLine = [controller bytesPerLine];
    HFASSERT(bytesPerLine > 0);
    unsigned long long totalLineCountTimesBytesPerLine = HFRoundUpToNextMultiple(contentsLength, bytesPerLine);
    HFASSERT(totalLineCountTimesBytesPerLine % bytesPerLine == 0);
    unsigned long long totalLineCount = totalLineCountTimesBytesPerLine / bytesPerLine;
    HFFPRange currentLineRange = [controller displayedLineRange];
    HFASSERT(currentLineRange.length < HFULToFP(totalLineCount));
    long double maxScroll = totalLineCount - currentLineRange.length;
    long double newScroll = maxScroll * (long double)newValue;
    [controller setDisplayedLineRange:(HFFPRange){newScroll, currentLineRange.length}];
}


- (void)scrollByLines:(long long)linesInt {
    if (linesInt == 0) return;
    
    long double lines = HFULToFP(linesInt);
    
    HFController *controller = [self controller];
    HFASSERT(controller != NULL);
    HFFPRange displayedRange = [[self controller] displayedLineRange];
    if (lines < 0) {
        displayedRange.location -= MIN(lines, displayedRange.location);
    }
    else {
        long double availableLines = HFULToFP([controller totalLineCount]);
        displayedRange.location = MIN(availableLines - displayedRange.length, displayedRange.location + lines);
    }
    [controller setDisplayedLineRange:displayedRange];
}

- (void)scrollerDidChangeValue:(NSScroller *)scroller {
    assert(scroller == [self view]);
    switch ([scroller hitPart]) {
	case NSScrollerDecrementPage: [self scrollByLines: -(long long)[self visibleLines]]; break;
	case NSScrollerIncrementPage: [self scrollByLines: (long long)[self visibleLines]]; break;
	case NSScrollerDecrementLine: [self scrollByLines: -1LL]; break;
	case NSScrollerIncrementLine: [self scrollByLines: 1LL]; break;
	case NSScrollerKnob: [self scrollByKnobToValue:(HFIsRunningOnLeopardOrLater() ? [scroller doubleValue] : [scroller floatValue])]; break;
	default: break;
    }
}

- (void)updateScrollerValue {
    HFController *controller = [self controller];
    CGFloat value, proportion;
    NSScroller *scroller = [self view];
    BOOL enable = YES;
    if (controller == nil) {
        value = 0;
        proportion = 0;
    }
    else {
        unsigned long long length = [controller contentsLength];
        HFFPRange lineRange = [controller displayedLineRange];
        HFASSERT(lineRange.location >= 0 && lineRange.length >= 0);
        if (length == 0) {
            value = 0;
            proportion = 1;
            enable = NO;
        }
        else {
            long double availableLines = HFULToFP([controller totalLineCount]);
            long double consumedLines = MAX(1., lineRange.length);
            proportion = ld2f(lineRange.length / HFULToFP(availableLines));
            
            long double maxScroll = availableLines - consumedLines;
            HFASSERT(maxScroll >= lineRange.location);
            if (maxScroll == 0.) {
                enable = NO;
                value = 0;
            }
            else {
                value = ld2f(lineRange.location / maxScroll);
            }
        }
    }
#if __LP64__
    // must be >= 10_5
    [scroller setDoubleValue:value];
    [scroller setKnobProportion:proportion];
#else
    [scroller setFloatValue:value knobProportion:proportion];
#endif
    [scroller setEnabled:enable];
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    USE(bytesPerLine);
    return [NSScroller scrollerWidthForControlSize:[[self view] controlSize]];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerContentLength | HFControllerDisplayedLineRange)) [self updateScrollerValue];
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(2, 0);
}

@end
