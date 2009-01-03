//
//  HFLineCountingRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

enum {
    HFLineNumberFormatDecimal,
    HFLineNumberFormatHexadecimal,
    HFLineNumberFormatMAXIMUM
};

@interface HFLineCountingRepresenter : HFRepresenter {
    CGFloat lineHeight;
    NSUInteger digitsToRepresentContentsLength;
    NSUInteger minimumDigitCount;
    NSUInteger lineNumberFormat;
    CGFloat preferredWidth;
    CGFloat digitAdvance;
}

/* Set the minimum amount of space for digits that will always be visible. */
- (void)setMinimumDigitCount:(NSUInteger)count;
- (NSUInteger)minimumDigitCount;

- (CGFloat)preferredWidth;

- (void)cycleLineNumberFormat;

@end

extern NSString *const HFLineCountingRepresenterMinimumViewWidthChanged;
