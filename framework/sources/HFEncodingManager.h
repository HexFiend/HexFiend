//
//  HFEncodingManager.h
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 12/30/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <HexFiend/HFNSStringEncoding.h>
#import <HexFiend/HFCustomEncoding.h>

@interface HFEncodingManager : NSObject

+ (instancetype)shared;

@property (readonly) NSArray<HFNSStringEncoding *> *systemEncodings;
- (HFNSStringEncoding *)systemEncoding:(NSStringEncoding)systenEncoding;

- (NSArray<HFCustomEncoding *> *)loadCustomEncodingsFromDirectory:(NSString *)directory;
@property (readonly) NSArray<HFCustomEncoding *> *customEncodings;

- (HFStringEncoding *)encodingByIdentifier:(NSString *)identifier;

@property (readonly) HFNSStringEncoding *ascii;

@end
