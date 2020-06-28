//
//  HFNSStringEncoding.h
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 6/16/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFStringEncoding.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFNSStringEncoding : HFStringEncoding <NSCoding>

- (instancetype)initWithEncoding:(NSStringEncoding)encoding name:(NSString *)name identifier:(NSString *)identifier;

@property NSStringEncoding encoding;

@end

NS_ASSUME_NONNULL_END
