//
//  HFBinaryTemplateController.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFController;

NS_ASSUME_NONNULL_BEGIN

@interface HFBinaryTemplateController : NSViewController

@property (readonly) BOOL hasTemplate;

- (void)rerunTemplateWithController:(HFController *)controller;

- (void)anchorTo:(NSUInteger)position;

- (void)showInTemplateAt:(NSUInteger)position;

@end

NS_ASSUME_NONNULL_END
