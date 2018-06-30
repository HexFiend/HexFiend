//
//  HFLineCountingRepresenter.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

NS_ASSUME_NONNULL_BEGIN

/*! @enum HFLineNumberFormat
    HFLineNumberFormat is a simple enum used to determine whether line numbers are in decimal or hexadecimal format.
*/
typedef NS_ENUM(NSUInteger, HFLineNumberFormat) {
    HFLineNumberFormatDecimal, //!< Decimal line numbers
    HFLineNumberFormatHexadecimal, //!< Hexadecimal line numbers
    HFLineNumberFormatMAXIMUM //!< One more than the maximum valid line number format, so that line number formats can be cycled through easily
};

/*! @class HFLineCountingRepresenter
    @brief The HFRepresenter used to show the "line number gutter."
    
    HFLineCountingRepresenter is the HFRepresenter used to show the "line number gutter."  HFLineCountingRepresenter makes space for a certain number of digits.
*/
@interface HFLineCountingRepresenter : HFRepresenter {
    CGFloat lineHeight;
    NSUInteger digitsToRepresentContentsLength;
    NSUInteger minimumDigitCount;
    HFLineNumberFormat lineNumberFormat;
    NSInteger interiorShadowEdge;
    CGFloat preferredWidth;
    CGFloat digitAdvance;
}

/// The minimum digit count.  The receiver will always ensure it is big enough to display at least the minimum digit count.  The default is 2.
@property (nonatomic) NSUInteger minimumDigitCount;

/// The number of digits we are making space for.
@property (readonly) NSUInteger digitCount;

/// The current width that the HFRepresenter prefers to be laid out with.
@property (readonly) CGFloat preferredWidth;

/// The line number format.
@property (nonatomic) HFLineNumberFormat lineNumberFormat;

/// Switches to the next line number format.  This is called from the view.
- (void)cycleLineNumberFormat;

/// The edge (as an NSRectEdge) on which the view draws an interior shadow. -1 means no edge.
@property (nonatomic) NSInteger interiorShadowEdge;

/*! The edges on which borders are drawn. The edge returned by interiorShadowEdge always has a border drawn. The edges are specified by a bitwise or of 1 left shifted by the NSRectEdge values. For example, to draw a border on the min x and max y edges use: (1 << NSMinXEdge) | (1 << NSMaxYEdge). 0 (or -1) specfies no edges. */
@property (nonatomic) NSInteger borderedEdges;

@end

/*! Notification posted when the HFLineCountingRepresenter's width has changed because the number of digits it wants to show has increased or decreased.  The object is the HFLineCountingRepresenter; there is no user info.
*/
extern NSString *const HFLineCountingRepresenterMinimumViewWidthChanged;

/*! Notification posted when the HFLineCountingRepresenter has cycled through the line number format.  The object is the HFLineCountingRepresenter; there is no user info.
 */
extern NSString *const HFLineCountingRepresenterCycledLineNumberFormat;

NS_ASSUME_NONNULL_END
