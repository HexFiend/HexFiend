//
//  Controller.h
//  hexf
//
//  Created by Reed Harston on 10/31/22.
//  Copyright © 2022 ridiculous_fish. All rights reserved.
//

#ifndef Controller_h
#define Controller_h

#import <Cocoa/Cocoa.h>

@interface Controller : NSObject
- (int)printUsage;
- (BOOL)processStandardInput;
- (int)processArguments:(NSArray<NSString *> *)args;
@end

#endif /* Controller_h */
