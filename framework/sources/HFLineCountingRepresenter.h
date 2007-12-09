//
//  HFLineCountingRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>


@interface HFLineCountingRepresenter : HFRepresenter {
    CGFloat lineHeight;
    NSFont *font;
    NSUInteger digitsToRepresentContentsLength;
    NSUInteger minimumDigitCount;
}

/* Set the minimum amount of space for digits that will always be visible. */
- (void)setMinimumDigitCount:(NSUInteger)count;
- (NSUInteger)minimumDigitCount;

- (CGFloat)preferredWidth;

@end

extern NSString *const HFLineCountingRepresenterMinimumViewWidthChanged;
