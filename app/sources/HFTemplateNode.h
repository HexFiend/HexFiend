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
- (instancetype)initGroupWithLabel:(NSString *)label parent:(HFTemplateNode *)parent;

@property (readonly) NSString *label;
@property (readonly) NSString *value;
@property (readonly) BOOL isGroup;
@property (readonly, weak) HFTemplateNode *parent;

@property NSMutableArray *children;

@property HFRange range;

@end

