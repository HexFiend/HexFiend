//
//  MinimumVersionRequired.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/14/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MinimumVersionRequired : NSObject

+ (BOOL)isMinimumVersionSatisfied:(NSString *)versionString error:(NSString *_Nonnull*_Nonnull)error;

@end

NS_ASSUME_NONNULL_END
