//
//  HFColorRange.h
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 1/14/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

@class HFRangeWrapper;

@interface HFColorRange : NSObject

@property (readwrite) HFColor *color;
@property (readwrite) HFRangeWrapper *range;

@end
