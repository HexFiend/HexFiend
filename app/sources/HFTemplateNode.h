//
//  HFTemplateNode.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HexFiend.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFTemplateNode : NSObject

- (instancetype)initWithLabel:(NSString *)label value:(NSString *)value;
- (instancetype)initGroupWithLabel:(NSString *_Nullable)label parent:(HFTemplateNode *_Nullable)parent;

@property (readonly) NSString *label;
@property (copy) NSString *value;
@property (readonly) BOOL isGroup;
@property (readonly, weak) HFTemplateNode *parent;

@property NSMutableArray *children;

@property HFRange range;

@end

NS_ASSUME_NONNULL_END
