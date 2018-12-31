//
//  HFNSStringEncoding.m
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/16/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFNSStringEncoding.h"
#import <HexFiend/HFFunctions.h>

@implementation HFNSStringEncoding
{
    NSString *_name;
    NSString *_identifier;
}

- (instancetype)initWithEncoding:(NSStringEncoding)encoding name:(NSString *)name identifier:(NSString *)identifier {
    self = [super init];
    _encoding = encoding;
    _name = name;
    _identifier = identifier;
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    _encoding = [coder decodeIntegerForKey:@"encoding"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.encoding forKey:@"encoding"];
}

- (uint8_t)fixedBytesPerCharacter {
    return HFStringEncodingCharacterLength(self.encoding);
}

- (BOOL)isASCII {
    return self.encoding == NSASCIIStringEncoding;
}

- (NSString *)stringFromBytes:(const unsigned char *)bytes length:(NSUInteger)length {
    return [[NSString alloc] initWithBytes:bytes length:length encoding:self.encoding];
}

- (NSData *)dataFromString:(NSString *)string {
    return [string dataUsingEncoding:self.encoding allowLossyConversion:NO];
}

- (NSString *)name {
    return _name;
}

- (NSString *)identifier {
    return _identifier;
}

- (BOOL)isEqual:(id)object {
    if ([object class] != [HFNSStringEncoding class]) {
        return NO;
    }
    HFNSStringEncoding *obj = object;
    return obj.encoding == self.encoding;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p - %@>", NSStringFromClass(self.class), self, self.name];
}

@end
