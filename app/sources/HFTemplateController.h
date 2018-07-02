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

@property NSUInteger anchor;

@end

@interface HFTemplateController (ProtectedForSubclasses)

- (NSString *)evaluateScript:(NSString *)path;

@property BOOL requireFailed;

@end

typedef NS_ENUM(NSUInteger, HFEndian) {
    HFEndianLittle,
    HFEndianBig,
};

@interface HFTemplateController (Private)

@property (readonly) unsigned long long position;
@property (readonly) unsigned long long length;
@property HFEndian endian;
@property (readonly) BOOL isEOF;

- (NSData *)readBytesForSize:(size_t)size forLabel:(NSString *)label;
- (NSString *)readHexDataForSize:(size_t)size forLabel:(NSString *)label;
- (NSString *)readStringDataForSize:(size_t)size encoding:(NSStringEncoding)encoding forLabel:(NSString *)label;

- (BOOL)requireDataAtOffset:(unsigned long long)offset toMatchHexValues:(NSString *)hexValues;

- (BOOL)readUInt64:(uint64_t *)value forLabel:(NSString *)label;
- (BOOL)readInt64:(int64_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt32:(uint32_t *)value forLabel:(NSString *)label;
- (BOOL)readInt32:(int32_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt24:(uint32_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt16:(uint16_t *)value forLabel:(NSString *)label;
- (BOOL)readInt16:(int16_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt8:(uint8_t *)value forLabel:(NSString *)label;
- (BOOL)readInt8:(int8_t *)value forLabel:(NSString *)label;
- (BOOL)readFloat:(float *)value forLabel:(NSString *)label;
- (BOOL)readDouble:(double *)value forLabel:(NSString *)label;
- (BOOL)readMacDate:(NSDate **)value forLabel:(NSString *)label;

- (BOOL)readUUID:(NSUUID **)uuid forLabel:(NSString *)label;

- (void)moveTo:(long long)offset;
- (void)goTo:(unsigned long long)offset;

- (void)beginSectionWithLabel:(NSString *)label;
- (void)endSection;

@end
