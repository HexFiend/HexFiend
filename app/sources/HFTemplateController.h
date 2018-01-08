//
//  HFTemplateController.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HFTemplateNode.h"

@interface HFTemplateController : NSObject

- (HFTemplateNode *)evaluateScript:(NSString *)path forController:(HFController *)controller error:(NSString **)error;

@end

@interface HFTemplateController (OverrideBySubclasses)

- (void)evaluateScript:(NSString *)path error:(NSString **)error;

@end

typedef NS_ENUM(NSUInteger, HFEndian) {
    HFEndianLittle,
    HFEndianBig,
};

@interface HFTemplateController (Private)

@property (readonly) HFController *controller;
@property unsigned long long position;
@property HFEndian endian;
@property (readonly) HFTemplateNode *currentNode;
@property (readonly) BOOL isEOF;

- (BOOL)readBytes:(void *)buffer size:(size_t)size;
- (NSData *)readDataForSize:(size_t)size;

- (BOOL)requireDataAtOffset:(unsigned long long)offset toMatchHexValues:(NSString *)hexValues;

- (BOOL)readUInt64:(uint64_t *)value forLabel:(NSString *)label;
- (BOOL)readInt64:(int64_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt32:(uint32_t *)value forLabel:(NSString *)label;
- (BOOL)readInt32:(int32_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt16:(uint16_t *)value forLabel:(NSString *)label;
- (BOOL)readInt16:(int16_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt8:(uint8_t *)value forLabel:(NSString *)label;
- (BOOL)readInt8:(int8_t *)value forLabel:(NSString *)label;
- (BOOL)readFloat:(float *)value forLabel:(NSString *)label;
- (BOOL)readDouble:(double *)value forLabel:(NSString *)label;

@end
