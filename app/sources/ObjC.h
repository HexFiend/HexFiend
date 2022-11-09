//
//  ObjC.h
//  HexFiend_2
//
//  Created by Reed Harston on 11/8/22.
//  Copyright © 2022 ridiculous_fish. All rights reserved.
//  https://stackoverflow.com/a/36454808/4013587
//

#import <Foundation/Foundation.h>

@interface ObjC : NSObject

+ (BOOL)catchException:(__attribute__((noescape)) void(^)(void))tryBlock error:(__autoreleasing NSError **)error;

@end
