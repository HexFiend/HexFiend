//
//  HFTemplateNode.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFTemplateNode.h"

@implementation HFTemplateNode

- (instancetype)init {
    if ((self = [super init]) == nil) {
        return nil;
    }

    _children = [NSMutableArray array];

    return self;
}

- (instancetype)initWithLabel:(NSString *)label value:(NSString *)value {
    if ((self = [self init]) == nil) {
        return nil;
    }

    _label = label;
    _value = value;

    return self;
}

@end
