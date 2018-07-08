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

- (instancetype)initWithEncoding:(NSStringEncoding)encoding {
    self = [super init];
    _encoding = encoding;
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
    return [NSString localizedNameOfStringEncoding:self.encoding];
}

+ (instancetype)ascii {
    return [[self alloc] initWithEncoding:NSASCIIStringEncoding];
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
