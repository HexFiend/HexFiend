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

- (instancetype)initWithLabel:(NSString *_Nullable)label value:(NSString *_Nullable)value;
- (instancetype)initGroupWithLabel:(NSString *_Nullable)label parent:(HFTemplateNode *_Nullable)parent;

@property (copy, nullable) NSString *label;
@property (copy, nullable) NSString *value;
@property (readonly) BOOL isGroup;
@property (readonly, weak, nullable) HFTemplateNode *parent;
@property (readonly) BOOL isSection;

@property NSMutableArray *children;

@property HFRange range;

@end

NS_ASSUME_NONNULL_END
