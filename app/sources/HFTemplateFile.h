//
//  HFTemplateFile.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/13/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFTemplateFile : NSObject

@property (copy) NSString *path;
@property (copy) NSString *name;
@property (copy) NSArray<NSString *> *supportedTypes;

@end

NS_ASSUME_NONNULL_END
