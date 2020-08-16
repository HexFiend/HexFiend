//
//  HFStringEncoding.h
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/16/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFStringEncoding : NSObject <NSCoding>

@property (readonly) NSString *name;
@property (readonly) NSString *identifier;
@property (readonly) uint8_t fixedBytesPerCharacter;
@property (readonly) BOOL isASCII;

- (NSString *)stringFromBytes:(const unsigned char *)bytes length:(NSUInteger)length;
- (nullable NSData *)dataFromString:(NSString *)string;

- (NSComparisonResult)compare:(HFStringEncoding *)other;

@end

NS_ASSUME_NONNULL_END
