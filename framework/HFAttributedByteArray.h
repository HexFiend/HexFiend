//
//  HFAttributedByteArray.h
//  HexFiend_2
//
//  Created by Peter Ammon on 6/25/11.
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFAttributedByteArray.h>

@class HFByteRangeAttributeArray;
@interface HFAttributedByteArray : HFByteArray {
@private
    HFByteArray *impl;
    HFByteRangeAttributeArray *attributes;
    
}

@end
