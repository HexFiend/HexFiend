//
//  ObjC.m
//  HexFiend_2
//
//  Created by Reed Harston on 11/8/22.
//  Copyright © 2022 ridiculous_fish. All rights reserved.
//  https://stackoverflow.com/a/36454808/4013587
//

#import "ObjC.h"

@implementation ObjC

// Used to catch Obj-C exceptions in a way that interacts nicely with Swift do-catch blocks
+ (BOOL)catchException:(__attribute__((noescape)) void(^)(void))tryBlock error:(__autoreleasing NSError **)error {
    @try {
        tryBlock();
        return YES;
    }
    @catch (NSException *exception) {
        *error = [[NSError alloc] initWithDomain:exception.name code:0 userInfo:exception.userInfo];
        return NO;
    }
}

@end
