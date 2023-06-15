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

+ (NSArray<NSString *> *)readSupportedTypesAtPath:(NSString *)path {
    NSDictionary *metadata = [self readFileMetadata:path];
    if (!metadata) {
        return nil;
    }
    
    NSArray *types = [metadata objectForKey:@"types"];
    if (![types isKindOfClass:[NSArray class]]) {
        NSLog(@"Invalid types array: %@ (type=%@) for %@", types, NSStringFromClass([types class]), path);
        return nil;
    }
    
    return types;
}

@end
