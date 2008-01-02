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
    return MAX(1, low);
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

- (void)postMinimumViewWidthChangedNotification {
    [[NSNotificationCenter defaultCenter] postNotificationName:HFLineCountingRepresenterMinimumViewWidthChanged object:self];
}

- (void)updateDigitAdvanceWithFont:(NSFont *)font {
    REQUIRE_NOT_NULL(font);
    font = [font screenFont];
    CGFloat maxDigitAdvance = 0;
    NSDictionary *attributesDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, nil];
    NSTextStorage *storage = [[NSTextStorage alloc] init];
    NSLayoutManager *manager = [[NSLayoutManager alloc] init];
    [storage setFont:font];
    [storage addLayoutManager:manager];
    
    NSSize advancements[16] = {};
    NSGlyph glyphs[16];
    
    for (NSUInteger i=0; i < 16; i++) {
        char c = "0123456789ABCDEF"[i];
        NSString *string = [[NSString alloc] initWithBytes:&c length:1 encoding:NSASCIIStringEncoding];
        [storage replaceCharactersInRange:NSMakeRange(0, (i ? 1 : 0)) withString:string];
        [string release];
        glyphs[i] = [manager glyphAtIndex:0 isValidIndex:NULL];
        HFASSERT(glyphs[i] != NSNullGlyph);
    }
    
    [font getAdvancements:advancements forGlyphs:glyphs count:sizeof glyphs / sizeof *glyphs];
    
    [manager release];
    [attributesDictionary release];
    [storage release];
    
    for (NSUInteger i=0; i < sizeof glyphs / sizeof *glyphs; i++) {
        maxDigitAdvance = HFMax(maxDigitAdvance, advancements[i].width);
    }
    
    if (digitAdvance != maxDigitAdvance) {
        digitAdvance = maxDigitAdvance;
        [self postMinimumViewWidthChangedNotification];
    }
}

- (void)updateFontAndLineHeight {
    HFLineCountingView *view = [self view];
    HFController *controller = [self controller];
    NSFont *font = controller ? [controller font] : [NSFont fontWithName:@"Monaco" size:(CGFloat)10.];
    [view setFont:font];
    [view setLineHeight: controller ? [controller lineHeight] : (CGFloat)10.];
    [self updateDigitAdvanceWithFont:font];
}

- (void)updateBytesPerLine {
    [[self view] setBytesPerLine:[[self controller] bytesPerLine]];
}

- (void)updateLineRangeToDraw {
    HFFPRange lineRange = {0, 0};
    HFController *controller = [self controller];
    if (controller) {
        lineRange = [controller displayedLineRange];
    }
    [[self view] setLineRangeToDraw:lineRange];
}

- (CGFloat)preferredWidth {
    return (CGFloat)10. + digitsToRepresentContentsLength * digitAdvance;
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
