//
//  HFTemplateNode.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFTemplateNode.h"

@interface HFTemplateNode ()

@property (weak) HFTemplateNode *parent;

@end

@implementation HFTemplateNode

- (instancetype)initWithLabel:(NSString *)label value:(NSString *)value {
    if ((self = [super init]) != nil) {
        _label = label;
        _value = value;
    }
    return self;
}

- (instancetype)initGroupWithLabel:(NSString *)label parent:(HFTemplateNode *)parent {
    if ((self = [super init]) != nil) {
        _label = label;
        _isGroup = YES;
        _parent = parent;
        _children = [NSMutableArray array];
    }
    return self;
}

- (BOOL)isSection {
    return self.isGroup && self.label != nil;
}

@end
