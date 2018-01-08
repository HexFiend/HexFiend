//
//  HFTemplateController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFTemplateController.h"
#import "HFFunctions_Private.h"

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

- (NSString *)readHexDataForSize:(size_t)size forLabel:(NSString *)label {
    NSData *data = [self readDataForSize:size];
    if (!data) {
        return nil;
    }
    NSString *str = HFHexStringFromData(data);
    [self addNodeWithLabel:label value:str];
    return str;
}

- (NSString *)readStringDataForSize:(size_t)size encoding:(NSStringEncoding)encoding forLabel:(NSString *)label {
    NSData *data = [self readDataForSize:size];
    if (!data) {
        return nil;
    }
    NSString *str = [[NSString alloc] initWithData:data encoding:encoding];
    [self addNodeWithLabel:label value:str];
    return str;
}

- (BOOL)readUInt64:(uint64_t *)value forLabel:(NSString *)label {
    uint64_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigLongLongToHost(val);
    }
    *value = val;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%llu", val]];
    return YES;
}

- (BOOL)readInt64:(int64_t *)value forLabel:(NSString *)label {
    int64_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigLongLongToHost(val);
    }
    *value = val;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%lld", val]];
    return YES;
}

- (BOOL)readUInt32:(uint32_t *)value forLabel:(NSString *)label {
    uint32_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigIntToHost(val);
    }
    *value = val;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%u", val]];
    return YES;
}

- (BOOL)readInt32:(int32_t *)value forLabel:(NSString *)label {
    int32_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigIntToHost(val);
    }
    *value = val;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%d", val]];
    return YES;
}

- (BOOL)readUInt16:(uint16_t *)value forLabel:(NSString *)label {
    uint16_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigShortToHost(val);
    }
    *value = val;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%d", val]];
    return YES;
}

- (BOOL)readInt16:(int16_t *)value forLabel:(NSString *)label {
    int16_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigShortToHost(val);
    }
    *value = val;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%d", val]];
    return YES;
}

- (BOOL)readUInt8:(uint8_t *)value forLabel:(NSString *)label {
    uint8_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    *value = val;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%d", val]];
    return YES;
}

- (BOOL)readInt8:(int8_t *)value forLabel:(NSString *)label {
    int8_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    *value = val;
    [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%d", val]];
    return YES;
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

- (BOOL)requireDataAtOffset:(unsigned long long)offset toMatchHexValues:(NSString *)hexValues {
    BOOL isMissingLastNybble = NO;
    NSData *hexdata = HFDataFromHexString(hexValues, &isMissingLastNybble);
    if (isMissingLastNybble) {
        return NO;
    }
    const unsigned long long currentPosition = self.position;
    self.position = offset;
    NSData *data = [self readDataForSize:hexdata.length];
    self.position = currentPosition;
    if (!data) {
        return NO;
    }
    if (![data isEqualToData:hexdata]) {
        return NO;
    }
    return YES;
}

- (void)moveTo:(long long)offset {
    self.position += offset;
}

@end
