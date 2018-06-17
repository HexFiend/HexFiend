//
//  HFCustomEncoding.m
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/16/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFCustomEncoding.h"

@interface HFCustomEncoding ()

@property NSString *path;
@property NSString *nameValue;
@property NSDictionary<NSNumber *, NSString *> *charToStringMap;

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
        return NO;
    }
    NSDictionary *map = dict[@"map"];
    if (![map isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    NSMutableDictionary *nsMap = [NSMutableDictionary dictionary];
    for (NSString *key in map) {
        NSScanner *scanner = [NSScanner scannerWithString:key];
        unsigned int intKey = 0;
        if (![scanner scanHexInt:&intKey]) {
            NSLog(@"Invalid key %@", key);
            return NO;
        }
        if (intKey > 0xFF) {
            NSLog(@"Only 8 bit keys are supported: %@", key);
            return NO;
        }
        NSString *value = map[key];
        if (value.length != 1) {
            NSLog(@"Values must be 1 character: %@", key);
            return NO;
        }
        nsMap[@(intKey)] = value;
    }
    _path = path;
    _nameValue = name;
    _charToStringMap = nsMap;
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
    return 1;
}

- (NSString *)stringFromBytes:(const unsigned char *)bytes length:(NSUInteger)length {
    NSMutableString *str = [NSMutableString string];
    for (NSUInteger i = 0; i < length; ++i) {
        NSString *value = self.charToStringMap[@(bytes[i])];
        if (!value) {
            value = @".";
        }
        [str appendString:value];
    }
    return str;
}

- (NSData *)dataFromString:(NSString *)string {
    NSLog(@"UNIMPLEMENTED: %@", string);
    return nil;
}

- (NSString *)name {
    return self.nameValue;
}

- (BOOL)isEqual:(id)object {
    if ([object class] != [HFCustomEncoding class]) {
        return NO;
    }
    HFCustomEncoding *obj = object;
    return [obj.path isEqual:self.path];
}

@end
