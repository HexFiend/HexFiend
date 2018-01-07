//
//  HFTclTemplateController.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/6/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HFTclTemplateController : NSObject

- (instancetype)initWithController:(HFController *)controller;

// Evaluate the Tcl script at the given path, and if successful return nil;
// If an error occurs, return an error message.
- (NSString *)evaluateScript:(NSString *)path;

@end
