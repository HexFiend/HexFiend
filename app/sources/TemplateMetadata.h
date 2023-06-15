//
//  TemplateMetadata.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/14/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TemplateMetadata : NSObject

- (nullable instancetype)initWithPath:(NSString *)path;

@property (nullable, readonly) NSArray<NSString *> *types;
@property (readonly) BOOL isHidden;
@property (nullable, readonly) NSString *minimumVersionRequired;

@end

NS_ASSUME_NONNULL_END
