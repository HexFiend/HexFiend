//
//  HFRepresenterVerticalScroller.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/12/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFVerticalScrollerRepresenter.h>


@implementation HFVerticalScrollerRepresenter

- (NSView *)createView {
    NSScroller *scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, [NSScroller scrollerWidthForControlSize:NSRegularControlSize], 64)];
    [scroller setTarget:self];
    [scroller setContinuous:YES];
    [scroller setEnabled:YES];
    [scroller setTarget:self];
    [scroller setAction:@selector(scrollerDidChangeValue:)];
    [scroller setFloatValue:(CGFloat).3 knobProportion:(CGFloat).4];
    [scroller setAutoresizingMask:NSViewHeightSizable];
    return scroller;
}

- (NSUInteger)visibleLines {
    HFController *controller = [self controller];
    NSUInteger bytesPerLine = [controller bytesPerLine];
    HFRange displayedRange = [controller displayedContentsRange];
    return ll2l(HFDivideULLRoundingUp(displayedRange.length, bytesPerLine));
}

- (void)scrollToUnclippedLocation:(unsigned long long)location {
    HFController *controller = [self controller];
    unsigned long long contentsLength = [controller contentsLength];
    NSUInteger bytesPerLine = [controller bytesPerLine];
    HFRange displayedRange = [controller displayedContentsRange];

    displayedRange.location = MIN(location, HFRoundUpToNextMultiple(contentsLength, bytesPerLine) - displayedRange.length);
    displayedRange.location -= displayedRange.location % bytesPerLine;
    [controller setDisplayedContentsRange:displayedRange];
}

- (void)scrollByKnobToValue:(double)newValue {
    HFController *controller = [self controller];
    unsigned long long length = [controller contentsLength];
    HFRange displayedRange = [controller displayedContentsRange];
    HFASSERT(displayedRange.length <= length);
    unsigned long long maxLocation = length - displayedRange.length;
    double newFLocation = round(maxLocation * newValue);
    unsigned long long newLocation = (unsigned long long)newFLocation;
    [self scrollToUnclippedLocation:newLocation];
}

- (void)scrollByBytes:(long long)bytes {
    if (bytes == 0) return;
    
    unsigned long long newLocation;
    HFRange displayedRange = [[self controller] displayedContentsRange];
    if (bytes < 0) {
        unsigned long long unsignedBytes = (unsigned long long)(- bytes);
        newLocation = displayedRange.location - MIN(unsignedBytes, displayedRange.location);
    }
    else {
        unsigned long long unsignedBytes = (unsigned long long)bytes;
        newLocation = HFSum(displayedRange.location, unsignedBytes);
    }
    [self scrollToUnclippedLocation:newLocation];
}

- (void)scrollerDidChangeValue:(NSScroller *)scroller {
    assert(scroller == [self view]);
    NSUInteger bytesPerLine = [[self controller] bytesPerLine];
    switch ([scroller hitPart]) {
	case NSScrollerDecrementPage: [self scrollByBytes: -(long long)(bytesPerLine * [self visibleLines])]; break;
	case NSScrollerIncrementPage: [self scrollByBytes: (long long)(bytesPerLine * [self visibleLines])]; break;
	case NSScrollerDecrementLine: [self scrollByBytes: -(long long)bytesPerLine]; break;
	case NSScrollerIncrementLine: [self scrollByBytes: (long long)bytesPerLine]; break;
	case NSScrollerKnob: [self scrollByKnobToValue:[scroller doubleValue]]; break;
	default: break;
    }
}

- (void)updateScrollerValue {
    HFController *controller = [self controller];
    CGFloat value, proportion;
    NSScroller *scroller = [self view];
    if (controller == nil) {
        value = 0;
        proportion = 0;
    }
    else {
        unsigned long long length = [controller contentsLength];
        HFRange displayedRange = [controller displayedContentsRange];
        HFFPRange lineRange = [controller displayedLineRange];
        HFASSERT(lineRange.location >= 0 && lineRange.length >= 0);
        if (length == 0) {
            value = 0;
            proportion = 1;
        }
        else {
            NSUInteger bytesPerLine = [controller bytesPerLine];
            long double availableLines = (long double)HFDivideULLRoundingUp(HFSum(length, 1), bytesPerLine);
            long double consumedLines = MAX(1., lineRange.length);
            proportion = ld2f(lineRange.length / (long double)availableLines);
            
            unsigned long long maxScroll = availableLines - consumedLines;
            HFASSERT((long double)maxScroll >= lineRange.location);
            value = ld2f(lineRange.location / maxScroll);
        }
    }
#if __LP64__
    // must be >= 10_5
    [scroller setDoubleValue:value];
    [scroller setKnobProportion:proportion];
#else
    [scroller setFloatValue:value knobProportion:proportion];
#endif
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    USE(bytesPerLine);
    return [NSScroller scrollerWidthForControlSize:[[self view] controlSize]];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerContentLength | HFControllerDisplayedRange)) [self updateScrollerValue];
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(2, 0);
}

@end
