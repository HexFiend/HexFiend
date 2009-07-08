//
//  HFLineCountingRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

/*! @enum HFLineNumberFormat
    HFLineNumberFormat is a simple enum used to determine whether line numbers are in decimal or hexadecimal format.
*/
enum
{
    HFLineNumberFormatDecimal, //!< Decimal line numbers
    HFLineNumberFormatHexadecimal, //!< Hexadecimal line numbers
    HFLineNumberFormatMAXIMUM //!< One more than the maximum valid line number format, so that line number formats can be cycled through easily
};
typedef NSUInteger HFLineNumberFormat;

/*! @class HFLineCountingRepresenter
    @brief The HFRepresenter used to show the "line number gutter."
    
    HFLineCountingRepresenter is the HFRepresenter used to show the "line number gutter."  HFLineCountingRepresenter makes space for a certain number of digits.
*/
@interface HFLineCountingRepresenter : HFRepresenter {
    CGFloat lineHeight;
    NSUInteger digitsToRepresentContentsLength;
    NSUInteger minimumDigitCount;
    HFLineNumberFormat lineNumberFormat;
    CGFloat preferredWidth;
    CGFloat digitAdvance;
}

/*! Sets the minimum digit count.  The receiver will always ensure it is big enough to display at least the minimum digit count.  The default is 2. */
- (void)setMinimumDigitCount:(NSUInteger)count;

/*! Gets the minimum digit count. */
- (NSUInteger)minimumDigitCount;

/*! Returns the number of digits we are making space for. */
- (NSUInteger)digitCount;

/*! Returns the current width that the HFRepresenter prefers to be laid out with. */
- (CGFloat)preferredWidth;

/*! Returns the current line number format. */
- (HFLineNumberFormat)lineNumberFormat;

/*! Sets the current line number format to a new format. */
- (void)setLineNumberFormat:(HFLineNumberFormat)format;

/*! Switches to the next line number format.  This is called from the view. */
- (void)cycleLineNumberFormat;

@end

/*! Notification posted when the HFLineCountingRepresenter's width has changed because the number of digits it wants to show has increased or decreased.  The object is the HFLineCountingRepresenter; there is no user info.
*/
extern NSString *const HFLineCountingRepresenterMinimumViewWidthChanged;
