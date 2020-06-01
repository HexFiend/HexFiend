//
//  HFExtendedAttributes.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 2/2/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "HFExtendedAttributes.h"
#import <sys/xattr.h>

@implementation HFExtendedAttributes

+ (NSArray<NSString *> *)attributesNamesAtPath:(NSString *)path error:(NSError **)error {
    const int options = XATTR_SHOWCOMPRESSION;
    const char *filerep = path.fileSystemRepresentation;
    const ssize_t bufSize1 = listxattr(filerep, NULL, 0, options);
    if (bufSize1 > 0) {
        // success
        char buf[bufSize1];
        memset(buf, 0, sizeof(buf));
        const ssize_t bufSize2 = listxattr(filerep, buf, bufSize1, options);
        if (bufSize2 != bufSize1) {
            // file just changed?
            return nil;
        }
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        const char *name = buf;
        const char *end = buf + bufSize1;
        while (name < end) {
            [names addObject:[NSString stringWithUTF8String:name]];
            name += strlen(name) + 1;
        }
        return names;
    } else if (bufSize1 == 0) {
        // no extended attrs
        return nil;
    } else {
        // assume error
        const int code = errno;
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
        }
        return nil;
    }
}

+ (NSData *)attributeNamed:(NSString *)name atPath:(NSString *)path error:(NSError **)error {
    const int options = XATTR_SHOWCOMPRESSION;
    const char *filerep = path.fileSystemRepresentation;
    const char *namebuf = name.UTF8String;
    const ssize_t bufSize1 = getxattr(filerep, namebuf, NULL, 0, 0, options);
    if (bufSize1 <= -1) {
        // assume error
        const int code = errno;
        if (error) {
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:code userInfo:nil];
        }
        return nil;
    } else if (bufSize1 == 0) {
        // nothing
        return [NSData data];
    } else {
        // success
        NSMutableData *data = [NSMutableData dataWithLength:bufSize1];
        const ssize_t bufSize2 = getxattr(filerep, namebuf, data.mutableBytes, bufSize1, 0, options);
        if (bufSize2 != bufSize1) {
            // file just changed?
            return nil;
        }
        return data;
    }
}

@end
