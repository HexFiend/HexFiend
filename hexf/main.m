//
//  main.m
//  hexf
//
//  Created by Kevin Wojniak on 9/24/17.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

static int usage() {
    fprintf(stderr, "usage: hexf: file [file ...]\n");
    return EXIT_FAILURE;
}

int main(int argc __unused, const char * argv[] __unused) {
    @autoreleasepool {
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        if (args.count <= 1) {
            return usage();
        }
        NSMutableArray *filesToOpen = [NSMutableArray array];
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
            [filesToOpen addObject:arg];
        }
        NSString *appIdentifier = @"com.ridiculousfish.HexFiend";
        NSRunningApplication* app = [[NSRunningApplication runningApplicationsWithBundleIdentifier:appIdentifier] firstObject];
        if (app) {
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
            NSDictionary *config = @{NSWorkspaceLaunchConfigurationArguments: launchArgs};
            NSError *err = nil;
            NSURL *url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:appIdentifier];
            if (![[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:NSWorkspaceLaunchDefault configuration:config error:&err]) {
                fprintf(stderr, "Launch app failed: %s\n", err.localizedDescription.UTF8String);
                return EXIT_FAILURE;
            }
        }
    }
    return EXIT_SUCCESS;
}
