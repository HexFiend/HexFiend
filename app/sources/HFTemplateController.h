//
//  HFTemplateController.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HFTemplateNode.h"
#import <HexFiend/HFStringEncoding.h>

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
- (NSString *)readStringDataForSize:(size_t)size encoding:(HFStringEncoding *)encoding forLabel:(NSString *)label;

- (BOOL)requireDataAtOffset:(unsigned long long)offset toMatchHexValues:(NSString *)hexValues;

- (BOOL)readUInt64:(uint64_t *)result forLabel:(NSString *)label asHex:(BOOL)asHex;
- (BOOL)readInt64:(int64_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt32:(uint32_t *)result forLabel:(NSString *)label asHex:(BOOL)asHex;
- (BOOL)readInt32:(int32_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt24:(uint32_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt16:(uint16_t *)result forLabel:(NSString *)label asHex:(BOOL)asHex;
- (BOOL)readInt16:(int16_t *)value forLabel:(NSString *)label;
- (BOOL)readUInt8:(uint8_t *)result forLabel:(NSString *)label asHex:(BOOL)asHex;
- (BOOL)readInt8:(int8_t *)value forLabel:(NSString *)label;
- (BOOL)readFloat:(float *)value forLabel:(NSString *)label;
- (BOOL)readDouble:(double *)value forLabel:(NSString *)label;
- (BOOL)readMacDate:(NSDate **)value forLabel:(NSString *)label;

- (BOOL)readUUID:(NSUUID **)uuid forLabel:(NSString *)label;

- (void)moveTo:(long long)offset;
- (void)goTo:(unsigned long long)offset;

- (void)beginSectionWithLabel:(NSString *)label;
- (void)endSection;

@property (readonly) HFTemplateNode *currentSection;

- (void)addEntryWithLabel:(NSString *)label value:(NSString *)value length:(unsigned long long *)length offset:(unsigned long long *)offset;

- (BOOL)readBits:(NSString *)bits byteCount:(unsigned)numberOfBytes forLabel:(NSString *)label result:(uint64 *)result error:(NSString **)error;

@end
