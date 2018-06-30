//
//  HFStatusBarRepresenter.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

/*! @enum HFStatusBarMode
    The HFStatusBarMode enum is used to describe the format of the byte counts displayed by the status bar.
*/
typedef NS_ENUM(NSUInteger, HFStatusBarMode) {
    HFStatusModeDecimal, ///< The status bar should display byte counts in decimal
    HFStatusModeHexadecimal, ///< The status bar should display byte counts in hexadecimal
    HFStatusModeApproximate, ///< The text should display byte counts approximately (e.g. "56.3 KB")
    HFSTATUSMODECOUNT ///< The number of modes, to allow easy cycling
};

/*! @class HFStatusBarRepresenter
    @brief The HFRepresenter for the status bar.
    
    HFStatusBarRepresenter is a subclass of HFRepresenter responsible for showing the status bar, which displays information like the total length of the document, or the number of selected bytes.
*/
@interface HFStatusBarRepresenter : HFRepresenter

@property (nonatomic) HFStatusBarMode statusMode;

@end
