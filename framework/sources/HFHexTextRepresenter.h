//
//  HFHexTextRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFTextRepresenter.h>


@interface HFHexTextRepresenter : HFTextRepresenter {
    unsigned long long omittedNybbleLocation;
    unsigned char unpartneredLastNybble;
}

@end
