//
//  HFTextRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>
#import <HexFiend/HFByteArray_ToString.h>

/* A representer that draws into a text view (e.g. the hex or ASCII view) */

@interface HFTextRepresenter : HFRepresenter {
    
}

- (HFByteArrayDataStringType)byteArrayDataStringType;

@end
