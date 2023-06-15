//
//  TemplateAutodetection.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/13/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import "TemplateAutodetection.h"

@implementation TemplateAutodetection

- (HFTemplateFile *)defaultTemplateForFileAtURL:(NSURL *)url allTemplates:(NSArray<HFTemplateFile *> *)allTemplates {
    NSString *type;
    NSError *error;
    BOOL success = [url getResourceValue:&type forKey:NSURLTypeIdentifierKey error:&error];
    if (!success) {
        return nil;
    }
    
    NSString *extension = url.pathExtension;
    
    // Check for exact UTI/extension match first.
    for (HFTemplateFile *template in allTemplates) {
        for (NSString *supportedType in template.supportedTypes) {
            if (UTTypeEqual((__bridge CFStringRef)type, (__bridge CFStringRef)supportedType) || [supportedType caseInsensitiveCompare:extension] == NSOrderedSame)
                return template;
        }
    }

    for (HFTemplateFile *template in allTemplates) {
        for (NSString *supportedType in template.supportedTypes) {
            if (UTTypeConformsTo((__bridge CFStringRef)type, (__bridge CFStringRef)supportedType))
                return template;
        }
    }

    return nil;
}

@end
