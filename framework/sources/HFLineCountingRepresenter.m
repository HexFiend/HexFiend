//
//  HFLineCountingRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFLineCountingRepresenter.h>
#import <HexFiend/HFLineCountingView.h>

NSString *const HFLineCountingRepresenterMinimumViewWidthChanged = @"HFLineCountingRepresenterMinimumViewWidthChanged";

@implementation HFLineCountingRepresenter

- (id)init {
    if ((self = [super init])) {
        minimumDigitCount = 2;
        digitsToRepresentContentsLength = minimumDigitCount;
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeDouble:lineHeight forKey:@"HFLineHeight"];
    [coder encodeInt64:minimumDigitCount forKey:@"HFMinimumDigitCount"];
    [coder encodeInt64:lineNumberFormat forKey:@"HFLineNumberFormat"];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    lineHeight = (CGFloat)[coder decodeDoubleForKey:@"HFLineHeight"];
    minimumDigitCount = (NSUInteger)[coder decodeInt64ForKey:@"HFMinimumDigitCount"];
    lineNumberFormat = (HFLineNumberFormat)[coder decodeInt64ForKey:@"HFLineNumberFormat"];
    return self;
}

- (NSView *)createView {
    HFLineCountingView *result = [[HFLineCountingView alloc] initWithFrame:NSMakeRect(0, 0, 60, 10)];
    [result setRepresenter:self];
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

- (void)updateLineNumberFormat {
    [[self view] setLineNumberFormat:lineNumberFormat];
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
        NSUInteger bytesPerLine = [controller bytesPerLine];
        /* We want to know how many lines are displayed.  That's equal to the contentsLength divided by bytesPerLine rounded down, except in the case that we're at the end of a line, in which case we need to show one more.  Hence adding 1 and dividing gets us the right result. */
        unsigned long long lineCount = contentsLength / bytesPerLine;
        unsigned long long contentsLengthRoundedToLine = HFProductULL(lineCount, bytesPerLine);
        NSUInteger digitCount = [HFLineCountingView digitsRequiredToDisplayLineNumber:contentsLengthRoundedToLine inFormat:lineNumberFormat];
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

- (HFLineNumberFormat)lineNumberFormat {
    return lineNumberFormat;
}

- (void)setLineNumberFormat:(HFLineNumberFormat)format {
    HFASSERT(format < HFLineNumberFormatMAXIMUM);
    lineNumberFormat = format;
    [self updateLineNumberFormat];
    [self updateMinimumViewWidth];
}


- (void)cycleLineNumberFormat {
    lineNumberFormat = (lineNumberFormat + 1) % HFLineNumberFormatMAXIMUM;
    [self updateLineNumberFormat];
    [self updateMinimumViewWidth];
}

- (void)initializeView {
    [self updateFontAndLineHeight];
    [self updateLineNumberFormat];
    [self updateBytesPerLine];
    [self updateLineRangeToDraw];
    [self updateMinimumViewWidth];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & HFControllerDisplayedLineRange) [self updateLineRangeToDraw];
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

- (NSUInteger)digitCount {
    return digitsToRepresentContentsLength;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(-1, 0);
}

@end
