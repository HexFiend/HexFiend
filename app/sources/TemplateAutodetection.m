//
//  TemplateAutodetection.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/13/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import "TemplateAutodetection.h"

@implementation TemplateAutodetection

- (NSArray<NSString *> *)readSupportedTypesAtPath:(NSString *)path {
    static const unsigned long long maxBytes = 512;
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    NSData *data = [handle readDataOfLength:maxBytes];
    NSString *firstBytes = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [handle closeFile];

    static NSRegularExpression *lineRegex;
    static dispatch_once_t lineOnceToken;
    dispatch_once(&lineOnceToken, ^{
        NSString *regexString = @"^\\h*#\\h*+types:\\h*([\\w.-]+(?:[\\h,]+[\\w.-]+)*)\\h*$";
        NSError *error;
        lineRegex = [NSRegularExpression regularExpressionWithPattern:regexString options:NSRegularExpressionAnchorsMatchLines | NSRegularExpressionCaseInsensitive error:&error];
        if (!lineRegex)
            NSLog(@"%@", error);
    });

    static NSRegularExpression *typeRegex;
    static dispatch_once_t typeOnceToken;
    dispatch_once(&typeOnceToken, ^{
        NSError *error;
        typeRegex = [NSRegularExpression regularExpressionWithPattern:@"[\\w.-]+" options:0 error:&error];
        if (!typeRegex)
            NSLog(@"%@", error);
    });

    NSTextCheckingResult *result = [lineRegex firstMatchInString:firstBytes options:0 range:(NSRange){0, firstBytes.length}];

    if (result && result.numberOfRanges == 2) {
        NSRange typesRange = [result rangeAtIndex:1];
        NSString *typesString = [firstBytes substringWithRange:typesRange];
        NSMutableArray *types = [NSMutableArray array];

        [typeRegex enumerateMatchesInString:typesString options:0 range:(NSRange){0, typesString.length} usingBlock:^(NSTextCheckingResult * _Nullable match, __unused NSMatchingFlags flags, __unused BOOL * _Nonnull stop) {
            NSString *type = [typesString substringWithRange:match.range];
            [types addObject:type];
        }];

        return [types copy];
    }

    return nil;
}

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
