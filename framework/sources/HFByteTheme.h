//
//  HFByteTheme.h
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/26/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

struct HFByteThemeColor {
    CGFloat r, g, b;
    BOOL set;
};

@interface HFByteTheme : NSObject

// Should be 256 size
@property struct HFByteThemeColor *darkColorTable;
@property struct HFByteThemeColor *lightColorTable;

@end

NS_ASSUME_NONNULL_END
