//
//  main.m
//  hexf
//
//  Created by Kevin Wojniak on 9/24/17.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static NSString *kAppIdentifier = @"com.ridiculousfish.HexFiend";

@interface Controller : NSObject

@end

@implementation Controller

- (int)printUsage {
    fprintf(stderr, "usage: hexf: file [file ...]\n");
    return EXIT_FAILURE;
}

- (BOOL)appRunning {
    NSRunningApplication* app = [[NSRunningApplication runningApplicationsWithBundleIdentifier:kAppIdentifier] firstObject];
    return app != nil;
}

- (BOOL)launchAppWithArgs:(NSArray *)args {
    NSDictionary *config = args ? @{NSWorkspaceLaunchConfigurationArguments: args} : nil;
    NSError *err = nil;
    NSURL *url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:kAppIdentifier];
    if (![[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:NSWorkspaceLaunchDefault configuration:config error:&err]) {
        fprintf(stderr, "Launch app failed: %s\n", err.localizedDescription.UTF8String);
        return NO;
    }
    return YES;
}

- (BOOL)processStandardInput {
    NSFileHandle *inFile = [NSFileHandle fileHandleWithStandardInput];
    NSData *data = [inFile readDataToEndOfFile];
    if (data.length == 0) {
        return NO;
    }
    if (self.appRunning) {
        // App is already running so post distributed notification
        NSDictionary *userInfo = @{@"data" : data};
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"HFOpenDataNotification" object:nil userInfo:userInfo deliverImmediately:YES];
        return YES;
    }
    // App isn't running so launch it with custom args
    NSString *base64Str = nil;
    if (@available(macOS 10.9, *)) {
        base64Str = [data base64EncodedStringWithOptions:0];
    } else {
        NSLog(@"Feature not available on 10.8");
        return NO;
    }
    NSArray *launchArgs = @[
        @"-HFOpenData",
        base64Str,
    ];
    return [self launchAppWithArgs:launchArgs];
}

- (int)processArguments:(NSArray<NSString *> *)args {
    NSMutableArray<NSString *> *filesToOpen = [NSMutableArray array];
    const NSUInteger argsCount = args.count;
    NSString *diffFile = nil;
    for (NSUInteger i = 1; i < argsCount; ++i) {
        NSString *arg = [args objectAtIndex:i];
        if ([arg hasPrefix:@"-"]) {
            if ([arg isEqualToString:@"-d"] || [arg isEqualToString:@"--diff"]) {
                if (i == (argsCount - 1)) {
                    fprintf(stderr, "Missing argument for \"%s\"\n", arg.UTF8String);
                    return EXIT_FAILURE;
                }
                if (diffFile) {
                    fprintf(stderr, "Argument \"%s\" can only be specified once.\n", arg.UTF8String);
                    return EXIT_FAILURE;
                }
                diffFile = [args objectAtIndex:i + 1];
                i++;
                continue;
            } else {
                fprintf(stderr, "Unknown argument \"%s\".\n", arg.UTF8String);
                return EXIT_FAILURE;
            }
        }
        if (diffFile && filesToOpen.count == 1) {
            fprintf(stderr, "Only one file can be specified when diff argument is used.\n");
            return EXIT_FAILURE;
        }
        NSURL *url = [NSURL fileURLWithPath:arg];
        NSString *path = url.path; // get absolute path
        [filesToOpen addObject:path];
    }
    if (self.appRunning) {
        // App is already running so post distributed notification
        NSString *name = nil;
        NSDictionary *userInfo = nil;
        if (diffFile) {
            name = @"HFDiffFilesNotification";
            userInfo = @{@"files": @[diffFile, [filesToOpen firstObject]]};
        } else {
            name = @"HFOpenFileNotification";
            userInfo = @{@"files": filesToOpen};
        }
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:name object:nil userInfo:userInfo deliverImmediately:YES];
    } else {
        // App isn't running so launch it with custom args
        NSMutableArray *launchArgs = [NSMutableArray array];
        if (diffFile) {
            [launchArgs addObject:@"-HFDiffLeftFile"];
            [launchArgs addObject:diffFile];
            [launchArgs addObject:@"-HFDiffRightFile"];
            [launchArgs addObject:[filesToOpen firstObject]];
        } else {
            for (NSString *fileToOpen in filesToOpen) {
                [launchArgs addObject:@"-HFOpenFile"];
                [launchArgs addObject:fileToOpen];
            }
        }
        if (![self launchAppWithArgs:launchArgs]) {
            return EXIT_FAILURE;
        }
    }
    return EXIT_SUCCESS;
}

@end

int main(int argc __unused, const char * argv[] __unused) {
    @autoreleasepool {
        Controller *controller = [[Controller alloc] init];
        NSArray<NSString *> *args = [[NSProcessInfo processInfo] arguments];
        if (args.count <= 1) {
            if ([controller processStandardInput]) {
                return EXIT_SUCCESS;
            } else {
                return [controller printUsage];
            }
        }
        return [controller processArguments:args];
    }
    return EXIT_SUCCESS;
}
