//
//  MinimumVersionRequired.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/14/23.
//  Copyright © 2023 ridiculous_fish. All rights reserved.
//

#import "MinimumVersionRequired.h"
#import <HexFiend/HFAssert.h>
#import "version.h"

#define HF_XSTR(s) HF_STR(s)
#define HF_STR(s) #s
static const char* kVersionString = HF_XSTR(HEXFIEND_VERSION);
#undef HF_STR
#undef HF_XSTR

@implementation MinimumVersionRequired

+ (BOOL)parseVersionString:(NSString*)s major:(int*)major minor:(int*)minor patch:(int*)patch {
    if (!s || !major || !minor || !patch) return false;

    *major = *minor = *patch = 0;

    NSArray<NSString *> *components = [s componentsSeparatedByString:@"."];
    NSUInteger count = components.count;

    if (count == 0 || count > 3) {
        return NO;
    }

    if (count > 0) {
        *major = [components[0] intValue];
    }

    if (count > 1) {
        *minor = [components[1] intValue];
    }

    if (count > 2) {
        *patch = [components[2] intValue];
    }

    return YES;
}

+ (long)versionIntegerWithMajor:(long)major minor:(long)minor patch:(long)patch {
    HFASSERT(major > 0);
    HFASSERT(minor >= 0 && minor <= 999);
    HFASSERT(patch >= 0 && patch <= 99);

    return major * 100000 + minor * 100 + patch;
}

+ (long)haveVersion {
    static long haveVersion = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        int haveMajor;
        int haveMinor;
        int havePatch;

        if (![self parseVersionString:[NSString stringWithUTF8String:kVersionString] major:&haveMajor minor:&haveMinor patch:&havePatch]) {
            return; // need better error handling here?
        }

        haveVersion = [self versionIntegerWithMajor:haveMajor minor:haveMinor patch:havePatch];
    });

    return haveVersion;
}

+ (BOOL)isMinimumVersionSatisfied:(NSString *)versionString error:(NSString *_Nonnull*_Nonnull)error {
    int major;
    int minor;
    int patch;
    if (![MinimumVersionRequired parseVersionString:versionString major:&major minor:&minor patch:&patch]) {
        *error = @"Could not parse minimum version information";
        return NO;
    }
    const long needVersion = [self versionIntegerWithMajor:major minor:minor patch:patch];
    if (self.haveVersion < needVersion) {
        *error = [NSString stringWithFormat:@"This build of Hex Fiend (v%s) does not meet this template's minimum requirement (v%d.%d.%d)", kVersionString, major, minor, patch];
        return NO;
    }
    return YES;
}

@end
