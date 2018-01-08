//
//  HFTemplateController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFTemplateController.h"

@interface HFTemplateController ()

@property HFController *controller;
@property unsigned long long position;
@property HFEndian endian;
@property HFTemplateNode *root;
@property (weak) HFTemplateNode *currentNode;

@end

@implementation HFTemplateController

- (HFTemplateNode *)evaluateScript:(NSString *)path forController:(HFController *)controller error:(NSString **)error {
    self.controller = controller;
    self.position = 0;
    self.root = [[HFTemplateNode alloc] init];
    self.root.isGroup = YES;
    self.currentNode = self.root;
    if (error) {
        *error = nil;
    }
    [self evaluateScript:path error:error];
    return self.root;
}

- (void)evaluateScript:(NSString * __unused)path error:(NSString ** __unused)error {
    HFASSERT(0); // should be overridden in subclasses
}

- (BOOL)readBytes:(void *)buffer size:(size_t)size {
    const HFRange range = HFRangeMake(self.controller.minimumSelectionLocation + self.position, size);
    if (!HFRangeIsSubrangeOfRange(range, HFRangeMake(0, self.controller.contentsLength))) {
        return NO;
    }
    [self.controller copyBytes:buffer range:range];
    self.position += size;
    return YES;
}

- (NSData *)readDataForSize:(size_t)size {
    NSMutableData *data = [NSMutableData dataWithLength:size];
    if (![self readBytes:data.mutableBytes size:data.length]) {
        return nil;
    }
    return data;
}

- (BOOL)readFloat:(float *)value forLabel:(NSString *)label {
    HFASSERT(value != NULL);
    union {
        uint32_t u;
        float f;
    } val;
    if (![self readBytes:&val.u size:sizeof(val.u)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val.u = NSSwapBigIntToHost(val.u);
    }
    *value = val.f;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%f", val.f]];
    return YES;
}

- (BOOL)readDouble:(double *)value forLabel:(NSString *)label {
    HFASSERT(value != NULL);
    union {
        uint64_t u;
        double f;
    } val;
    if (![self readBytes:&val.u size:sizeof(val.u)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val.u = NSSwapBigLongLongToHost(val.u);
    }
    *value = val.f;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%f", val.f]];
    return YES;
}

- (void)addNodeWithLabel:(NSString *)label value:(NSString *)value {
    HFTemplateNode *node = [[HFTemplateNode alloc] initWithLabel:label value:value];
    [self.currentNode.children addObject:node];
}

- (BOOL)isEOF {
    return (self.controller.minimumSelectionLocation + self.position) >= self.controller.contentsLength;
}

@end
