//
//  HFBinaryTemplateController.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFController;

@interface HFBinaryTemplateController : NSViewController

- (void)rerunTemplateWithController:(HFController *)controller;

- (void)anchorTo:(NSUInteger)position;

@end
