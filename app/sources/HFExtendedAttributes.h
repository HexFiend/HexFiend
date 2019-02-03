//
//  HFExtendedAttributes.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 2/2/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HFExtendedAttributes : NSObject

+ (NSArray<NSString *> *)attributesNamesAtPath:(NSString *)path error:(NSError **)error;
+ (NSData *)attributeNamed:(NSString *)name atPath:(NSString *)path error:(NSError **)error;

@end
