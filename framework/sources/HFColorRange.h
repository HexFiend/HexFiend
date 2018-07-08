//
//  HFColorRange.h
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 1/14/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

@class HFRangeWrapper;

@interface HFColorRange : NSObject

#if TARGET_OS_IPHONE
@property (readwrite) UIColor *color;
#else
@property (readwrite) NSColor *color;
#endif
@property (readwrite) HFRangeWrapper *range;

@end
