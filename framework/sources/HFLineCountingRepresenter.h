//
//  HFLineCountingRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

enum HFLineNumberFormat_t {
    HFLineNumberFormatDecimal,
    HFLineNumberFormatHexadecimal,
    HFLineNumberFormatMAXIMUM
};

@interface HFLineCountingRepresenter : HFRepresenter {
    CGFloat lineHeight;
    NSUInteger digitsToRepresentContentsLength;
    NSUInteger minimumDigitCount;
    enum HFLineNumberFormat_t lineNumberFormat;
    CGFloat preferredWidth;
    CGFloat digitAdvance;
}

/* Set the minimum amount of space for digits that will always be visible. */
- (void)setMinimumDigitCount:(NSUInteger)count;
- (NSUInteger)minimumDigitCount;

/* Returns the number of digits we are making space for */
- (NSUInteger)digitCount;

- (CGFloat)preferredWidth;

- (enum HFLineNumberFormat_t)lineNumberFormat;
- (void)cycleLineNumberFormat;

@end

extern NSString *const HFLineCountingRepresenterMinimumViewWidthChanged;
