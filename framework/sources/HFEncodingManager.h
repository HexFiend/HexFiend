//
//  HFEncodingManager.h
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 12/30/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <HexFiend/HFNSStringEncoding.h>

@class HFCustomEncoding;

NS_ASSUME_NONNULL_BEGIN

@interface HFEncodingManager : NSObject

+ (instancetype)shared;

@property (readonly) NSArray<HFNSStringEncoding *> *systemEncodings;
- (nullable HFNSStringEncoding *)systemEncoding:(NSStringEncoding)systenEncoding;

- (NSArray<HFCustomEncoding *> *)loadCustomEncodingsFromDirectory:(NSString *)directory;
@property (nullable, readonly) NSArray<HFCustomEncoding *> *customEncodings;

- (nullable HFStringEncoding *)encodingByIdentifier:(NSString *)identifier;

@property (readonly) HFNSStringEncoding *ascii;

@end

NS_ASSUME_NONNULL_END
