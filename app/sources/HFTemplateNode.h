//
//  HFTemplateNode.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HFTemplateNode : NSObject

- (instancetype)initWithLabel:(NSString *)label value:(NSString *)value;

@property NSString *label;
@property NSString *value;

@property BOOL isGroup;
@property NSMutableArray *children;

@end

