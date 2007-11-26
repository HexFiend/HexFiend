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
    unsigned long long length = [controller contentsLength];
    NSUInteger bytesPerLine = [controller bytesPerLine];
    HFRange displayedRange = [controller displayedContentsRange];
    HFASSERT(displayedRange.length <= length);
    displayedRange.location = MIN(location, length - displayedRange.length);
    displayedRange.location -= displayedRange.location % bytesPerLine;
    HFASSERT(HFRangeIsSubrangeOfRange(displayedRange, HFRangeMake(0, length)));
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
        if (unsignedBytes >= displayedRange.location) newLocation = 0;
        else newLocation = displayedRange.location - unsignedBytes;
    }
    else {
        unsigned long long unsignedBytes = (unsigned long long)bytes;
        HFASSERT(HFSumDoesNotOverflow(displayedRange.location, unsignedBytes));
        newLocation = displayedRange.location + unsignedBytes;
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
    if (controller == nil) {
        value = 0;
        proportion = 0;
    }
    else {
        unsigned long long length = [controller contentsLength];
        HFRange displayedRange = [controller displayedContentsRange];
        if (length == 0) {
            value = 0;
            proportion = 1;
        }
        else {
            NSUInteger bytesPerLine = [controller bytesPerLine];
            unsigned long long availableLines = HFDivideULLRoundingUp(length, bytesPerLine);
            unsigned long long consumedLines = MAX(1ULL, HFDivideULLRoundingUp(displayedRange.length, bytesPerLine));
            proportion = (CGFloat)((double)consumedLines / (double)availableLines);
            
            unsigned long long currentScroll = displayedRange.location / bytesPerLine;
            unsigned long long maxScroll = availableLines - consumedLines;
            HFASSERT(maxScroll >= currentScroll);
            value = (CGFloat)((double)currentScroll / (double)maxScroll);
        }
    }
    [[self view] setFloatValue:value knobProportion:proportion];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerContentLength | HFControllerDisplayedRange)) [self updateScrollerValue];
}

@end
