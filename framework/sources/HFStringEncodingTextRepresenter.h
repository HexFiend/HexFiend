//
//  HFASCIITextRepresenter.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextRepresenter.h>

/*! @class HFStringEncodingTextRepresenter

    @brief An HFRepresenter responsible for showing data interpreted via an NSStringEncoding.

    HFHexTextRepresenter is an HFRepresenter responsible for showing and editing data interpreted via an NSStringEncoding.  Currently only supersets of ASCII are supported.
*/
@interface HFStringEncodingTextRepresenter : HFTextRepresenter {
    NSStringEncoding stringEncoding;
    
}

/*! Get the string encoding for this representer.  The default encoding is <tt>[NSString defaultCStringEncoding]</tt>. */
@property (nonatomic) NSStringEncoding encoding;

/*! Set the string encoding for this representer. */

@end
