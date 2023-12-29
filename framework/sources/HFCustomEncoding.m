//
//  HFCustomEncoding.m
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/16/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFCustomEncoding.h"
#import <HexFiend/HFAssert.h>

@interface HFCustomEncoding ()

@property uint8_t bytesPerCharacter;
@property NSString *path;
@property NSString *nameValue;
@property NSString *identifierValue;
@property NSDictionary<NSNumber *, NSString *> *charToStringMap;
@property NSDictionary<NSString *, NSNumber *> *stringToCharMap;

@end

@implementation HFCustomEncoding

- (BOOL)commonInitWithPath:(NSString *)path {
    NSInputStream *stream = [NSInputStream inputStreamWithFileAtPath:path];
    [stream open];
    NSError *err = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithStream:stream options:0 error:&err];
    if (![dict isKindOfClass:[NSDictionary class]]) {
        NSLog(@"Error with file %@: %@", path, err);
        return NO;
    }
    NSString *name = dict[@"name"];
    if (!name) {
        NSLog(@"Missing \"name\" field");
        return NO;
    }
    if (![name isKindOfClass:[NSString class]]) {
        NSLog(@"name is not a string");
        return NO;
    }
    NSString *identifier = dict[@"identifier"];
    if (!identifier) {
        identifier = name;
    } else if (![identifier isKindOfClass:[NSString class]]) {
        NSLog(@"identifier is not a string");
        return NO;
    }
    NSNumber *bytesPerCharacter = dict[@"bytesPerCharacter"];
    if (!bytesPerCharacter) {
        bytesPerCharacter = @(1);
    } else if (![bytesPerCharacter isKindOfClass:[NSNumber class]]) {
        NSLog(@"bytesPerCharacter is not a number");
        return NO;
    }
    _bytesPerCharacter = [bytesPerCharacter unsignedCharValue];
    if (_bytesPerCharacter < 1 || _bytesPerCharacter > 2) {
        NSLog(@"Invalid bytes per character %@", bytesPerCharacter);
        return NO;
    }
    NSDictionary *map = dict[@"map"];
    if (![map isKindOfClass:[NSDictionary class]]) {
        NSLog(@"map is not a dictionary");
        return NO;
    }
    NSMutableDictionary<NSNumber *, NSString *> *nsMap = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSNumber *> *nsMapInverted = [NSMutableDictionary dictionary];
    for (NSString *key in map) {
        NSScanner *scanner = [NSScanner scannerWithString:key];
        unsigned int intKey = 0;
        if (![scanner scanHexInt:&intKey]) {
            NSLog(@"Invalid key %@", key);
            return NO;
        }
        if (intKey > 0xFF && _bytesPerCharacter == 1) {
            NSLog(@"Only 8 bit keys are supported: %@", key);
            return NO;
        }
        if (intKey > 0xFFFF) {
            NSLog(@"Only 16 bit keys are supported: %@", key);
            return NO;
        }
        NSString *value = map[key];
        if (value.length != 1) {
            NSLog(@"Values must be 1 character: %@", key);
            return NO;
        }
        nsMap[@(intKey)] = value;
        nsMapInverted[value] = @(intKey);
    }
    _path = path;
    _nameValue = name;
    _identifierValue = identifier;
    _charToStringMap = nsMap;
    _stringToCharMap = nsMapInverted;
    return YES;
}

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (![self commonInitWithPath:path]) {
        return nil;
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    NSString *path = [coder decodeObjectForKey:@"path"];
    return [self initWithPath:path];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.path forKey:@"path"];
}

- (uint8_t)fixedBytesPerCharacter {
    return _bytesPerCharacter;
}

- (NSString *)stringFromBytes:(const unsigned char *)bytes length:(NSUInteger)length {
    NSMutableString *str = [NSMutableString string];
    NSUInteger end = length - _bytesPerCharacter + 1;
    for (NSUInteger i = 0; i < end; i += _bytesPerCharacter) {
        NSUInteger codepoint = bytes[i];
        if (_bytesPerCharacter == 2) {
            codepoint <<= 8;
            codepoint |= bytes[i + 1];
        }
        NSString *value = self.charToStringMap[@(codepoint)];
        if (!value) {
            value = @".";
        }
        [str appendString:value];
    }
    return str;
}

- (NSData *)dataFromString:(NSString *)string {
    NSMutableData *bytes = [NSMutableData dataWithCapacity:string.length * _bytesPerCharacter];
    for (NSUInteger i = 0; i < string.length; ++i) {
        NSString *str = [NSString stringWithFormat:@"%C", [string characterAtIndex:i]];
        NSNumber *codepointNumber = self.stringToCharMap[str];
        if (_bytesPerCharacter == 1) {
            const uint8_t byte = codepointNumber.unsignedCharValue;
            if (byte) {
                [bytes appendBytes:&byte length:sizeof(byte)];
            }
        } else if (_bytesPerCharacter == 2) {
            const uint16_t byte = codepointNumber.unsignedShortValue;
            if (byte) {
                // XXX: we're assuming host endian
                [bytes appendBytes:&byte length:sizeof(byte)];
            }
        } else {
            HFASSERT(0);
        }
    }
    return bytes.length > 0 ? bytes : nil;
}

- (NSString *)name {
    return self.nameValue;
}

- (NSString *)identifier {
    return self.identifierValue;
}

- (BOOL)isEqual:(id)object {
    if ([object class] != [HFCustomEncoding class]) {
        return NO;
    }
    HFCustomEncoding *obj = object;
    return [obj.path isEqual:self.path];
}

@end
