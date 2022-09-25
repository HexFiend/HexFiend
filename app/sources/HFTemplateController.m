//
//  HFTemplateController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/7/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFTemplateController.h"
#import "LEB128Type.h"

static const unsigned long long kMaxCacheSize = 1024 * 1024;

@interface HFTemplateController ()

@property HFController *controller;
@property unsigned long long position;
@property HFEndian endian;
@property HFTemplateNode *root;
@property (weak) HFTemplateNode *currentNode;
@property BOOL requireFailed;
@property NSMutableData *bytesCache;
@property NSMutableData *cstrCache;
@property HFRange bytesCacheRange;

@end

@implementation HFTemplateController

- (instancetype)init {
    self = [super init];
    _bytesCache = [NSMutableData dataWithLength:kMaxCacheSize];
    _cstrCache = [NSMutableData dataWithLength:kMaxCacheSize];
    return self;
}

- (HFTemplateNode *)evaluateScript:(NSString *)path forController:(HFController *)controller error:(NSString **)error {
    self.controller = controller;
    self.position = 0;
    self.root = [[HFTemplateNode alloc] initGroupWithLabel:nil parent:nil];
    self.currentNode = self.root;
    self.initiallyCollapsed = [[NSMutableArray alloc] init];
    if (error) {
        *error = nil;
    }
    NSString *localError = [self evaluateScript:path];
    if (localError) {
        if (self.requireFailed) {
            localError = NSLocalizedString(@"Template not applicable", nil);
        }
        if (error) {
            *error = localError;
        }
    }
    return self.root;
}

- (NSString *)evaluateScript:(NSString * __unused)path {
    HFASSERT(0); // should be overridden in subclasses
    return nil;
}

- (BOOL)readBytes:(void *)buffer size:(size_t)size {
    const HFRange range = HFRangeMake(self.anchor + self.position, size);
    if (!HFRangeIsSubrangeOfRange(range, HFRangeMake(0, self.length))) {
        return NO;
    }
    HFASSERT(range.length <= NSUIntegerMax); // it doesn't make sense to ask for a buffer larger than can be stored in memory

    if (range.length > kMaxCacheSize) {
        // Don't try to cache if the requested range wouldn't fit
        [self.controller copyBytes:buffer range:range];
    } else {
        if ((range.location < _bytesCacheRange.location) || (range.location + range.length > _bytesCacheRange.location + _bytesCacheRange.length)) {
            // Requested range is not cached, so recache
            _bytesCacheRange.location = range.location;
            _bytesCacheRange.length = kMaxCacheSize;
            // If the new cache length goes behind the file end, clip the length
            if (_bytesCacheRange.location + _bytesCacheRange.length > self.length) {
                _bytesCacheRange.length = self.length - _bytesCacheRange.location;
            }
            [self.controller copyBytes:_bytesCache.mutableBytes range:_bytesCacheRange];
        }
        memcpy(buffer, _bytesCache.bytes + range.location - _bytesCacheRange.location, size);
    }

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

- (NSData *)readBytesForSize:(size_t)size forLabel:(NSString *)label {
    NSData *data = [self readDataForSize:size];
    if (!data) {
        return nil;
    }
    if (label) {
        [self addNodeWithLabel:label value:@"" size:size];
    }
    return data;
}

- (NSString *)readHexDataForSize:(size_t)size forLabel:(NSString *)label {
    NSData *data = [self readDataForSize:size];
    if (!data) {
        return nil;
    }
    NSString *str = HFHexStringFromData(data, YES);
    if (label) {
        [self addNodeWithLabel:label value:str size:size];
    }
    return str;
}

- (NSString *)readStringDataForSize:(size_t)size encoding:(HFStringEncoding *)encoding forLabel:(NSString *)label {
    NSData *data = [self readDataForSize:size];
    if (!data) {
        return nil;
    }
    NSString *str = [encoding stringFromBytes:data.bytes length:data.length];
    if (label) {
        [self addNodeWithLabel:label value:str size:size];
    }
    return str;
}

- (NSString *)readCStringForEncoding:(HFStringEncoding *)encoding forLabel:(NSString *)label {
    unsigned char* buf = _cstrCache.mutableBytes;
    BOOL foundNul = 0;
    size_t offset = 0;
    for (; offset < kMaxCacheSize; offset++) {
        if (![self readBytes:buf + offset size:1]) {
            return nil;
        }
        if (buf[offset] == 0) {
            foundNul = YES;
            break;
        }
    }
    if (!foundNul) {
        return nil;
    }
    const size_t numBytesRead = offset + 1;
    NSString *str = [encoding stringFromBytes:buf length:numBytesRead - 1];
    if (label) {
        [self addNodeWithLabel:label value:str size:numBytesRead];
    }
    return str;
}

- (BOOL)readUInt64:(uint64_t *)result forLabel:(NSString *)label asHex:(BOOL)asHex {
    uint64_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigLongLongToHost(val);
    }
    *result = val;
    if (label) {
        NSString *value;
        if (asHex) {
            value = [NSString stringWithFormat:@"0x%" PRIX64, val];
        } else {
            value = [NSString stringWithFormat:@"%" PRIu64, val];
        }
        [self addNodeWithLabel:label value:value size:sizeof(val)];
    }
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
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%lld", val] size:sizeof(val)];
    }
    return YES;
}

- (BOOL)readUInt32:(uint32_t *)result forLabel:(NSString *)label asHex:(BOOL)asHex {
    uint32_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigIntToHost(val);
    }
    *result = val;
    if (label) {
        NSString *value;
        if (asHex) {
            value = [NSString stringWithFormat:@"0x%" PRIX32, val];
        } else {
            value = [NSString stringWithFormat:@"%" PRIu32, val];
        }
        [self addNodeWithLabel:label value:value size:sizeof(val)];
    }
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
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%d", val] size:sizeof(val)];
    }
    return YES;
}

- (BOOL)readUInt24:(uint32_t *)value forLabel:(NSString *)label {
    uint8_t bytes[3];
    if (![self readBytes:bytes size:sizeof(bytes)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        uint8_t byte0 = bytes[0];
        bytes[0] = bytes[2];
        bytes[2] = byte0;
    }
    uint32_t val = (bytes[2] << 16) | (bytes[1] << 8) | bytes[0];
    *value = val;
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%u", val] size:sizeof(bytes)];
    }
    return YES;
}

- (BOOL)readUInt16:(uint16_t *)result forLabel:(NSString *)label asHex:(BOOL)asHex {
    uint16_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigShortToHost(val);
    }
    *result = val;
    if (label) {
        NSString *value;
        if (asHex) {
            value = [NSString stringWithFormat:@"0x%" PRIX16, val];
        } else {
            value = [NSString stringWithFormat:@"%" PRIu16, val];
        }
        [self addNodeWithLabel:label value:value size:sizeof(val)];
    }
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
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%d", val] size:sizeof(val)];
    }
    return YES;
}

- (BOOL)readUInt8:(uint8_t *)result forLabel:(NSString *)label asHex:(BOOL)asHex {
    uint8_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    *result = val;
    if (label) {
        NSString *value;
        if (asHex) {
            value = [NSString stringWithFormat:@"0x%" PRIX8, val];
        } else {
            value = [NSString stringWithFormat:@"%" PRIu8, val];
        }
        [self addNodeWithLabel:label value:value size:sizeof(val)];
    }
    return YES;
}

- (BOOL)readInt8:(int8_t *)value forLabel:(NSString *)label {
    int8_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    *value = val;
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%d", val] size:sizeof(val)];
    }
    return YES;
}

- (BOOL)readFloat:(float *)value forLabel:(NSString *)label {
    HFASSERT(value != NULL);
    union {
        uint32_t u;
        float f;
    } val;
    memset(&val, 0, sizeof(val));
    if (![self readBytes:&val.u size:sizeof(val.u)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val.u = NSSwapBigIntToHost(val.u);
    }
    *value = val.f;
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%.*g", FLT_DECIMAL_DIG, val.f] size:sizeof(val)];
    }
    return YES;
}

- (BOOL)readDouble:(double *)value forLabel:(NSString *)label {
    HFASSERT(value != NULL);
    union {
        uint64_t u;
        double f;
    } val;
    memset(&val, 0, sizeof(val));
    if (![self readBytes:&val.u size:sizeof(val.u)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val.u = NSSwapBigLongLongToHost(val.u);
    }
    *value = val.f;
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%.*g", DBL_DECIMAL_DIG, val.f] size:sizeof(val)];
    }
    return YES;
}

- (BOOL)readULEB128:(uint64_t *)value forLabel:(NSString *_Nullable)label {
    HFASSERT(value != NULL);
    LEB128Type *leb128 = [[LEB128Type alloc] init];
    size_t maxBytesAvailable = self.length - (self.anchor + self.position);
    size_t bytesToRead = maxBytesAvailable < leb128.maxBytesAllowed ? maxBytesAvailable : leb128.maxBytesAllowed;
    NSData *data = [self readDataForSize:bytesToRead];
    if (!data) {
        return NO;
    }
    InspectionError err;
    LEB128Result *result = [LEB128Type valueForBytes:data.bytes length:data.length isUnsigned:YES error:&err];
    if (!result) {
        return NO;
    }
    *value = result.value.u;
    // Reset file pointer based on how many bytes were actually used
    [self moveTo:-(bytesToRead - result.numBytes)];
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%" PRIu64, *value] size:result.numBytes];
    }
    return YES;
}

- (BOOL)readSLEB128:(int64_t *)value forLabel:(NSString *_Nullable)label {
    HFASSERT(value != NULL);
    LEB128Type *leb128 = [[LEB128Type alloc] init];
    size_t maxBytesAvailable = self.length - (self.anchor + self.position);
    size_t bytesToRead = maxBytesAvailable < leb128.maxBytesAllowed ? maxBytesAvailable : leb128.maxBytesAllowed;
    NSData *data = [self readDataForSize:bytesToRead];
    if (!data) {
        return NO;
    }
    InspectionError err;
    LEB128Result *result = [LEB128Type valueForBytes:data.bytes length:data.length isUnsigned:NO error:&err];
    if (!result) {
        return NO;
    }
    *value = result.value.i;
    // Reset file pointer based on how many bytes were actually used
    [self moveTo:-(bytesToRead - result.numBytes)];
    if (label) {
        [self addNodeWithLabel:label value:[NSString stringWithFormat:@"%lld", *value] size:result.numBytes];
    }
    return YES;
}

- (NSString *)dateToString:(NSDate *)date {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.doesRelativeDateFormatting = YES;
    formatter.dateStyle = NSDateFormatterShortStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [formatter stringFromDate:date];
}

- (BOOL)readMacDate:(NSDate **)value forLabel:(NSString *)label {
    uint32_t val;
    if (![self readBytes:&val size:sizeof(val)]) {
        return NO;
    }
    if (self.endian == HFEndianBig) {
        val = NSSwapBigIntToHost(val);
    }
    
    CFAbsoluteTime cftime = 0;
    const OSStatus status = UCConvertSecondsToCFAbsoluteTime(val, &cftime);
    if (status != 0) {
        return NO;
    }
    *value = [NSDate dateWithTimeIntervalSinceReferenceDate:cftime];
    if (label) {
        [self addNodeWithLabel:label value:[self dateToString:*value] size:sizeof(val)];
    }
    return YES;
}

- (NSString *)readFatDateWithLabel:(NSString *)label error:(NSString **)error {
    int16_t val;
    if (![self readInt16:&val forLabel:nil]) {
        if (error) {
            *error = @"Failed to read int16 bytes";
        }
        return nil;
    }

    int day = val & 0x1F;
    int month = (val >> 5) & 0xF;
    int year = 1980 + ((val >> 9) & 0x7F);
    NSString *date = [NSString stringWithFormat:@"%d-%02d-%02d", year, month, day];

    if (label) {
        [self addNodeWithLabel:label value:date size:sizeof(val)];
    }
    return date;
}

- (NSString *)readFatTimeWithLabel:(NSString *)label error:(NSString **)error {
    int16_t val;
    if (![self readInt16:&val forLabel:nil]) {
        if (error) {
            *error = @"Failed to read int16 bytes";
        }
        return nil;
    }

    int sec = (val & 0x1F) * 2;
    int min = (val >> 5) & 0x3F;
    int hour = (val >> 11) & 0x1F;
    NSString *time = [NSString stringWithFormat:@"%02d:%02d:%02d", hour, min, sec];

    if (label) {
        [self addNodeWithLabel:label value:time size:sizeof(val)];
    }
    return time;
}

- (NSDate *)readUnixTime:(unsigned)numBytes forLabel:(NSString *)label error:(NSString **)error {
    time_t t;
    if (numBytes == 4) {
        int32_t t32;
        if (![self readInt32:&t32 forLabel:nil]) {
            if (error) {
                *error = @"Failed to read int32 bytes";
            }
            return nil;
        }
        t = t32;
    } else if (numBytes == 8) {
        int64_t t64;
        if (![self readInt64:&t64 forLabel:nil]) {
            if (error) {
                *error = @"Failed to read int64 bytes";
            }
            return nil;
        }
        t = t64;
    } else {
        if (error) {
            *error = [NSString stringWithFormat:@"Unsupported number of bytes: %u", numBytes];
        }
        return nil;
    }
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:t];
    if (label) {
        [self addNodeWithLabel:label value:[self dateToString:date] size:numBytes];
    }
    return date;
}

- (BOOL)readUUID:(NSUUID **)uuid forLabel:(NSString *)label {
    union {
        struct {
            uint32_t data1;
            uint16_t data2;
            uint16_t data3;
            uint8_t data4[8];
        } swap;
        uuid_t uuid;
    } bytes;
    if (![self readBytes:&bytes size:sizeof(bytes)]) {
        return NO;
    }
    // NSUUID always reads as big endian, even on little endian platforms
    if (self.endian == HFEndianLittle) {
        bytes.swap.data1 = NSSwapInt(bytes.swap.data1);
        bytes.swap.data2 = NSSwapShort(bytes.swap.data2);
        bytes.swap.data3 = NSSwapShort(bytes.swap.data3);
    }
    *uuid = [[NSUUID alloc] initWithUUIDBytes:bytes.uuid];
    if (label) {
        [self addNodeWithLabel:label value:[*uuid UUIDString] size:sizeof(bytes)];
    }
    return YES;
}

- (void)addNodeWithLabel:(NSString *)label value:(NSString *)value size:(unsigned long long)size {
    HFTemplateNode *node = [[HFTemplateNode alloc] initWithLabel:label value:value];
    node.range = HFRangeMake((self.anchor + self.position) - size, size);
    [self.currentNode.children addObject:node];
    HFRange range = self.currentNode.range;
    range.length = ((node.range.location + node.range.length) - range.location);
    self.currentNode.range = range;
}

- (BOOL)isEOF {
    return (self.anchor + self.position) >= self.length;
}

- (BOOL)requireDataAtOffset:(unsigned long long)offset toMatchHexValues:(NSString *)hexValues {
    BOOL isMissingLastNybble = NO;
    NSData *hexdata = HFDataFromHexString(hexValues, &isMissingLastNybble);
    if (isMissingLastNybble) {
        self.requireFailed = YES;
        return NO;
    }
    const unsigned long long currentPosition = self.position;
    self.position = offset;
    NSData *data = [self readDataForSize:hexdata.length];
    self.position = currentPosition;
    if (!data) {
        self.requireFailed = YES;
        return NO;
    }
    if (![data isEqualToData:hexdata]) {
        self.requireFailed = YES;
        return NO;
    }
    return YES;
}

- (void)moveTo:(long long)offset {
    self.position += offset;
}

- (void)goTo:(unsigned long long)offset {
    self.position = offset;
}

- (unsigned long long)length {
    return self.controller.contentsLength;
}

- (void)beginSectionWithLabel:(NSString *)label collapsed:(BOOL)collapsed {
    HFTemplateNode *node = [[HFTemplateNode alloc] initGroupWithLabel:label parent:self.currentNode];
    node.range = HFRangeMake(self.anchor + self.position, 0);
    [self.currentNode.children addObject:node];
    self.currentNode = node;
    if (collapsed) {
        [self.initiallyCollapsed addObject:node];
    }
}

#define REQUIRE_SECTION() \
    if (!self.currentNode.isSection) { \
        if (error) { \
            *error = @"No active section."; \
        } \
        return NO; \
    }

- (BOOL)endSection:(NSString *_Nonnull*_Nonnull)error {
    REQUIRE_SECTION();
    HFTemplateNode *node = self.currentNode;
    self.currentNode = self.currentNode.parent;
    
    HFRange range = self.currentNode.range;
    range.length = ((node.range.location + node.range.length) - range.location);
    self.currentNode.range = range;
    return YES;
}

- (BOOL)setSectionName:(NSString *)name error:(NSString *_Nonnull*_Nonnull)error {
    REQUIRE_SECTION();
    self.currentSection.label = name;
    return YES;
}

- (BOOL)setSectionValue:(NSString *)name error:(NSString *_Nonnull*_Nonnull)error {
    REQUIRE_SECTION();
    self.currentSection.value = name;
    return YES;
}

- (BOOL)sectionCollapse:(NSString *_Nonnull*_Nonnull)error {
    REQUIRE_SECTION();
    [self.initiallyCollapsed addObject:self.currentSection];
    return YES;
}

- (HFTemplateNode *)currentSection {
    return self.currentNode;
}

- (void)addEntryWithLabel:(NSString *)label value:(NSString *)value length:(unsigned long long *)length offset:(unsigned long long *)offset {
    HFTemplateNode *currentNode = self.currentNode;
    HFTemplateNode *newNode = [[HFTemplateNode alloc] initWithLabel:label value:value];
    if (length) {
        if (offset) {
            newNode.range = HFRangeMake(self.anchor + *offset, *length);
        } else {
            newNode.range = HFRangeMake(self.anchor + self.position, *length);
        }
        unsigned long long newloc = MIN(currentNode.range.location, newNode.range.location);
        unsigned long long newlen = MAX(currentNode.range.location + currentNode.range.length, newNode.range.location + newNode.range.length) - newloc;
        currentNode.range = HFRangeMake(newloc, newlen);
    } else if (offset) {
        HFASSERT(0); // invalid state
    }
    [currentNode.children addObject:newNode];
}

- (BOOL)readBits:(NSString *)bits byteCount:(unsigned)numberOfBytes forLabel:(NSString *)label result:(uint64 *)result error:(NSString **)error {
    uint64_t rawValue;
    switch (numberOfBytes) {
        case sizeof(uint8_t): {
            uint8_t u8Value;
            if (![self readUInt8:&u8Value forLabel:nil asHex:NO]) {
                if (error) {
                    *error = @"Failed to read uint8 bytes";
                }
                return NO;
            }
            rawValue = u8Value;
            break;
        }
        case sizeof(uint16_t): {
            uint16_t u16Value;
            if (![self readUInt16:&u16Value forLabel:nil asHex:NO]) {
                if (error) {
                    *error = @"Failed to read uint16 bytes";
                }
                return NO;
            }
            rawValue = u16Value;
            break;
        }
        case sizeof(uint32_t): {
            uint32_t u32Value;
            if (![self readUInt32:&u32Value forLabel:nil asHex:NO]) {
                if (error) {
                    *error = @"Failed to read uint32 bytes";
                }
                return NO;
            }
            rawValue = u32Value;
            break;
        }
        case sizeof(uint64_t): {
            if (![self readUInt64:&rawValue forLabel:nil asHex:NO]) {
                if (error) {
                    *error = @"Failed to read uint64 bytes";
                }
                return NO;
            }
            break;
        }
        default:
            if (error) {
                *error = [NSString stringWithFormat:@"%u bytes is invalid.", numberOfBytes];
            }
            return NO;
    }
    NSCharacterSet *numberSet = NSCharacterSet.decimalDigitCharacterSet;
    NSCharacterSet *spaceSet = [NSCharacterSet characterSetWithCharactersInString:@" "];
    NSArray<NSString *> *bitNumbers = [bits componentsSeparatedByString:@","];
    uint64_t val = 0;
    const unsigned maxBitValue = (numberOfBytes * 8) - 1;
    NSMutableIndexSet *usedBits = [NSMutableIndexSet indexSet];
    unsigned index = 0;
    for (NSString *bitStr in bitNumbers) {
        NSString *localBitStr = [bitStr stringByTrimmingCharactersInSet:spaceSet];
        if (localBitStr.length == 0) {
            if (error) {
                *error = [NSString stringWithFormat:@"Invalid empty bit at index %u.", index];
            }
            return NO;
        }
        NSString *trimmedString = [localBitStr stringByTrimmingCharactersInSet:numberSet];
        if (trimmedString.length > 0) {
            if (error) {
                *error = [NSString stringWithFormat:@"Bit is not a valid number: %@", localBitStr];
            }
            return NO;
        }
        const unsigned bitValue = (unsigned)localBitStr.integerValue;
        if (bitValue > maxBitValue) {
            if (error) {
                *error = [NSString stringWithFormat:@"Bit is out of range: %u", bitValue];
            }
            return NO;
        }
        if ([usedBits containsIndex:bitValue]) {
            if (error) {
                *error = [NSString stringWithFormat:@"Bit already used: %u", bitValue];
            }
            return NO;
        }
        val = (val << 1) | ((rawValue >> bitValue) & 1);
        [usedBits addIndex:bitValue];
        index++;
    }
    *result = val;
    if (label) {
        NSString *value = [NSString stringWithFormat:@"%" PRIu64, val];
        [self addNodeWithLabel:label value:value size:numberOfBytes];
    }
    return YES;
}

@end
