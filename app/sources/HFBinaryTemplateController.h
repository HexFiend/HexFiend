//
//  HFBinaryTemplateController.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFTemplateNode;

@interface HFBinaryTemplateController : NSViewController

- (void)setRootNode:(HFTemplateNode *)node error:(NSString *)error;

@end
