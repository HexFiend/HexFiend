//
//  HFLineCountingRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFLineCountingRepresenter.h>
#import <HexFiend/HFLineCountingView.h>

NSString *const HFLineCountingRepresenterMinimumViewWidthChanged = @"HFLineCountingRepresenterMinimumViewWidthChanged";

/* returns 1 + log base 10 of val.  If val is 0, returns 1. */
static NSUInteger digit_count(unsigned long long val) {
    const unsigned long long kValues[] = {0ULL, 9ULL, 99ULL, 999ULL, 9999ULL, 99999ULL, 999999ULL, 9999999ULL, 99999999ULL, 999999999ULL, 9999999999ULL, 99999999999ULL, 999999999999ULL, 9999999999999ULL, 99999999999999ULL, 999999999999999ULL, 9999999999999999ULL, 99999999999999999ULL, 999999999999999999ULL, 9999999999999999999ULL};
    NSUInteger low = 0, high = sizeof kValues / sizeof *kValues;
    while (high > low) {
        NSUInteger mid = (low + high)/2; //low + high cannot overflow
        if (val > kValues[mid]) {
            low = mid + 1;
        }
        else {
            high = mid;
        }
    }
    return MIN(1, low);
}

@implementation HFLineCountingRepresenter

- (id)init {
    if ((self = [super init])) {
        minimumDigitCount = 2;
        digitsToRepresentContentsLength = minimumDigitCount;
    }
    return self;
}

- (NSView *)createView {
    NSView *result = [[HFLineCountingView alloc] initWithFrame:NSMakeRect(0, 0, 60, 10)];
    [result setAutoresizingMask:NSViewHeightSizable];
    return result;
}

- (void)updateFontAndLineHeight {
    HFLineCountingView *view = [self view];
    HFController *controller = [self controller];
    [view setFont:controller ? [controller font] : [NSFont fontWithName:@"Monaco" size:(CGFloat)10.]];
    [view setLineHeight: controller ? [controller lineHeight] : (CGFloat)10.];
}

- (void)updateBytesPerLine {
    [[self view] setBytesPerLine:[[self controller] bytesPerLine]];
}

- (void)updateLineRangeToDraw {
    HFRange lineRange = {0, 0};
    HFController *controller = [self controller];
    if (controller) {
        HFRange displayedRange = [controller displayedContentsRange];
        NSUInteger bytesPerLine = [controller bytesPerLine];
        lineRange.location = displayedRange.location / bytesPerLine;
        lineRange.length = displayedRange.length / bytesPerLine;
    }
    [[self view] setLineRangeToDraw:lineRange];
}

- (void)postMinimumViewWidthChangedNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:HFLineCountingRepresenterMinimumViewWidthChanged object:self];
}

- (CGFloat)preferredWidth {
    return digitsToRepresentContentsLength * (CGFloat)12.;
}

- (void)updateMinimumViewWidth {
    HFController *controller = [self controller];
    if (controller) {
        unsigned long long contentsLength = [controller contentsLength];
        NSUInteger digitCount = digit_count(contentsLength);
        NSUInteger digitWidth = MAX(minimumDigitCount, digitCount);
        if (digitWidth != digitsToRepresentContentsLength) {
            digitsToRepresentContentsLength = digitWidth;
            [self postMinimumViewWidthChangedNotification];
        }
    }
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    USE(bytesPerLine);
    return [self preferredWidth];
}

- (void)initializeView {
    [self updateFontAndLineHeight];
    [self updateBytesPerLine];
    [self updateLineRangeToDraw];
    [self updateMinimumViewWidth];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & HFControllerDisplayedRange) [self updateLineRangeToDraw];
    if (bits & HFControllerBytesPerLine) [self updateBytesPerLine];
    if (bits & (HFControllerFont | HFControllerLineHeight)) [self updateFontAndLineHeight];
    if (bits & (HFControllerContentLength)) [self updateMinimumViewWidth];
}

- (void)setMinimumDigitCount:(NSUInteger)width {
    minimumDigitCount = width;
    [self updateMinimumViewWidth];
}

- (NSUInteger)minimumDigitCount {
    return minimumDigitCount;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(-1, 0);
}

@end
