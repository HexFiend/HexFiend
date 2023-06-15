//
//  TemplateMetadata.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/14/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import "TemplateMetadata.h"

@implementation TemplateMetadata

+ (NSDictionary *)readFileMetadata:(NSString *)path {
    // Metadata are comments in "old-style" ASCII property list format but with a dot/period prefix.
    // See "Old-Style ASCII Property Lists":
    // https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/PropertyLists/OldStylePlists/OldStylePLists.html
    //
    // The lines construct a dictionary.
    // Only the first lines at the beginning of the file are parsed.
    //
    // For example:
    //
    //     # png.tcl
    //     #
    //     # .min_version_required = 2.15;
    //     # .types = ( public.jpeg, jpeg );
    //
    // This will generate a dictionary:
    //
    // {
    //     min_version_required = 2.15;
    //     types = ( public.png, png );
    // }
    
    char lineBuffer[1024];
    FILE *filePtr = fopen(path.UTF8String, "r");
    if (!filePtr) {
        NSLog(@"Cannot open %@: %s", path, strerror(errno));
        return nil;
    }
    NSMutableString *plistStr = [NSMutableString string];
    BOOL readingMetadata = NO;
    NSString *commentPrefix = @"#";
    NSString *metadataPrefix = @"# .";
    while (fgets(lineBuffer, sizeof(lineBuffer) - 1, filePtr)) {
        NSString *line = [[NSString alloc] initWithUTF8String:lineBuffer];
        if (![line hasPrefix:commentPrefix]) {
            // Header comment block ended, stop processing.
            break;
        }
        
        if ([line hasPrefix:metadataPrefix]) {
            readingMetadata = YES;
            if (line.length > metadataPrefix.length) {
                [plistStr appendFormat:@"%@\n", [line substringFromIndex:metadataPrefix.length]];
            }
        } else if (readingMetadata) {
            break;
        }
    }
    fclose(filePtr);
    if (plistStr.length == 0) {
        // No metadata lines found
        return nil;
    }
    NSString *dictPlistStr = [NSString stringWithFormat:@"{\n%@\n}", plistStr];
    NSData *dictData = [dictPlistStr dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSPropertyListFormat format;
    NSDictionary *dict = [NSPropertyListSerialization propertyListWithData:dictData options:NSPropertyListImmutable format:&format error:&error];
    if (!dict) {
        NSLog(@"Metadata error for %@: %@", path, error);
        return nil;
    }
    if (format != NSPropertyListOpenStepFormat) {  // Sanity check the format
        NSLog(@"Invalid dictionary format %lu for %@", (unsigned long)format, path);
    }
    return dict;
}

- (nullable instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    
    NSDictionary *metadata = [self.class readFileMetadata:path];
    if (!metadata) {
        return nil;
    }
    
    NSArray *types = metadata[@"types"];
    if (types) {
        if (![types isKindOfClass:[NSArray class]]) {
            NSLog(@"Invalid types class %@ (type=%@) for %@", types, NSStringFromClass(types.class), path);
            return nil;
        }
        for (NSString *type in types) {
            if (![type isKindOfClass:[NSString class]]) {
                NSLog(@"Invalid type class %@ (type=%@) for %@", type, NSStringFromClass(type.class), path);
                return nil;
            }
        }
        _types = types;
    }
    
    NSString *hidden = metadata[@"hidden"];
    if (hidden) {
        if (![hidden isKindOfClass:[NSString class]]) {
            NSLog(@"Invalid hidden class %@ (type=%@) for %@", hidden, NSStringFromClass(hidden.class), path);
            return nil;
        }
        if (![hidden isEqualToString:@"true"]) {
            NSLog(@"Invalid hidden value %@ for %@", hidden, path);
            return nil;
        }
        _isHidden = YES;
    }
    
    NSString *minVersionRequired = metadata[@"min_version_required"];
    if (minVersionRequired) {
        if (![minVersionRequired isKindOfClass:[NSString class]]) {
            NSLog(@"Invalid min_version_required class %@ (type=%@) for %@", minVersionRequired, NSStringFromClass(minVersionRequired.class), minVersionRequired);
            return nil;
        }
        _minimumVersionRequired = minVersionRequired;
    }

    return self;
}

@end
