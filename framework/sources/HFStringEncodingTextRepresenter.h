//
//  HFASCIITextRepresenter.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextRepresenter.h>
#import <HexFiend/HFStringEncoding.h>

/*! @class HFStringEncodingTextRepresenter

    @brief An HFRepresenter responsible for showing data interpreted via an HFStringEncoding.

    HFHexTextRepresenter is an HFRepresenter responsible for showing and editing data interpreted via an HFStringEncoding.  Currently only supersets of ASCII are supported.
*/
@interface HFStringEncodingTextRepresenter : HFTextRepresenter

/*! Get the string encoding for this representer. */ 
@property (nonatomic) HFStringEncoding *encoding;

/*! Set the string encoding for this representer. */

@end
