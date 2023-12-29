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

NS_ASSUME_NONNULL_BEGIN

@interface HFTemplateController : NSObject

- (HFTemplateNode *)evaluateScript:(NSString *)path forController:(HFController *)controller error:(NSString *_Nullable*_Nullable)error;

@property NSUInteger anchor;
@property NSString *templatesFolder;
@property NSString *bundleTemplatesPath;
@property NSMutableArray *initiallyCollapsed;

@end

@interface HFTemplateController (ProtectedForSubclasses)

- (NSString *_Nullable)evaluateScript:(NSString *)path;

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

- (NSData *_Nullable)readBytesForSize:(size_t)size forLabel:(NSString *_Nullable)label;
- (NSString *_Nullable)readHexDataForSize:(size_t)size forLabel:(NSString *_Nullable)label;
- (NSString *_Nullable)readStringDataForSize:(size_t)size encoding:(HFStringEncoding *)encoding forLabel:(NSString *_Nullable)label;
- (NSString *_Nullable)readCStringForEncoding:(HFStringEncoding *)encoding forLabel:(NSString *_Nullable)label;

- (BOOL)requireDataAtOffset:(unsigned long long)offset toMatchHexValues:(NSString *_Nullable)hexValues;

- (BOOL)readUInt64:(uint64_t *)result forLabel:(NSString *_Nullable)label asHex:(BOOL)asHex;
- (BOOL)readInt64:(int64_t *)value forLabel:(NSString *_Nullable)label;
- (BOOL)readUInt32:(uint32_t *)result forLabel:(NSString *_Nullable)label asHex:(BOOL)asHex;
- (BOOL)readInt32:(int32_t *)value forLabel:(NSString *_Nullable)label;
- (BOOL)readUInt24:(uint32_t *)value forLabel:(NSString *_Nullable)label;
- (BOOL)readUInt16:(uint16_t *)result forLabel:(NSString *_Nullable)label asHex:(BOOL)asHex;
- (BOOL)readInt16:(int16_t *)value forLabel:(NSString *_Nullable)label;
- (BOOL)readUInt8:(uint8_t *)result forLabel:(NSString *_Nullable)label asHex:(BOOL)asHex;
- (BOOL)readInt8:(int8_t *)value forLabel:(NSString *_Nullable)label;
- (BOOL)readFloat:(float *)value forLabel:(NSString *_Nullable)label;
- (BOOL)readDouble:(double *)value forLabel:(NSString *_Nullable)label;
- (BOOL)readMacDate:(NSDate *_Nonnull*_Nonnull)value utcOffset:(NSNumber *_Nullable)utcOffset forLabel:(NSString *_Nullable)label;
- (NSString *_Nullable)readFatDateWithLabel:(NSString *_Nullable)label error:(NSString *_Nonnull*_Nonnull)error;
- (NSString *_Nullable)readFatTimeWithLabel:(NSString *_Nullable)label error:(NSString *_Nonnull*_Nonnull)error;
- (NSDate *_Nullable)readUnixTime:(unsigned)numBytes utcOffset:(NSNumber *_Nullable)utcOffset forLabel:(NSString *_Nullable)label error:(NSString *_Nonnull*_Nonnull)error;

- (BOOL)readUUID:(NSUUID *_Nonnull*_Nonnull)uuid forLabel:(NSString *_Nullable)label;

- (BOOL)readULEB128:(uint64_t *)value forLabel:(NSString *_Nullable)label;
- (BOOL)readSLEB128:(int64_t *)value forLabel:(NSString *_Nullable)label;

- (void)moveTo:(long long)offset;
- (void)goTo:(unsigned long long)offset;

- (void)beginSectionWithLabel:(NSString *_Nullable)label collapsed:(BOOL)collapsed;
- (BOOL)endSection:(NSString *_Nonnull*_Nonnull)error;
- (BOOL)setSectionName:(NSString *)name error:(NSString *_Nonnull*_Nonnull)error;
- (BOOL)setSectionValue:(NSString *)value error:(NSString *_Nonnull*_Nonnull)error;
- (BOOL)sectionCollapse:(NSString *_Nonnull*_Nonnull)error;

@property (readonly) HFTemplateNode *currentSection;

- (void)addEntryWithLabel:(NSString *)label value:(NSString *)value length:(unsigned long long *_Nullable)length offset:(unsigned long long *_Nullable)offset;

- (BOOL)readBits:(NSString *)bits byteCount:(unsigned)numberOfBytes forLabel:(NSString *_Nullable)label result:(uint64 *)result error:(NSString *_Nonnull*_Nonnull)error;

@property (readonly, nullable) HFTemplateNode *currentNode;

@end

@interface HFTemplateController (Testing)
+ (NSDate *_Nullable)convertMacDateSeconds:(UInt32)seconds;
@end

NS_ASSUME_NONNULL_END
