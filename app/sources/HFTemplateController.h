//
//  HFTemplateController.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HFTemplateNode.h"

@interface HFTemplateController : NSObject

- (HFTemplateNode *)evaluateScript:(NSString *)path forController:(HFController *)controller error:(NSString **)error;

@end

@interface HFTemplateController (OverrideBySubclasses)

- (HFTemplateNode *)evaluateScript:(NSString *)path error:(NSString **)error;

@end

@interface HFTemplateController (Private)

@property (readonly) HFController *controller;
@property unsigned long long position;

- (BOOL)readBytes:(void *)buffer size:(size_t)size;
- (NSData *)readDataForSize:(size_t)size;

@end
