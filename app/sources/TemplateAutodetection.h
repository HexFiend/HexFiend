//
//  TemplateAutodetection.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/13/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HFTemplateFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface TemplateAutodetection : NSObject

- (nullable HFTemplateFile *)defaultTemplateForFileAtURL:(NSURL *)url allTemplates:(NSArray<HFTemplateFile *> *)allTemplates;

@end

NS_ASSUME_NONNULL_END
