//
//  HFColumnRepresenter.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/1/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFColumnRepresenter : HFRepresenter

- (void)setLineCountingWidth:(CGFloat)width;

@property (readonly) CGFloat preferredHeight;

@end

extern NSString *const HFColumnRepresenterViewHeightChanged;

NS_ASSUME_NONNULL_END
