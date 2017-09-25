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
        for (NSUInteger i = 1; i < args.count; ++i) {
            NSString *arg = [args objectAtIndex:i];
            if ([arg hasPrefix:@"-"]) {
                fprintf(stderr, "Unknown argument \"%s\".\n", arg.UTF8String);
                return EXIT_FAILURE;
            }
            [filesToOpen addObject:arg];
        }
        NSString *appIdentifier = @"com.ridiculousfish.HexFiend";
        NSRunningApplication* app = [[NSRunningApplication runningApplicationsWithBundleIdentifier:appIdentifier] firstObject];
        if (app) {
            NSDictionary *userInfo = @{@"files": filesToOpen};
            [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"HFOpenFileNotification" object:nil userInfo:userInfo deliverImmediately:YES];
        } else {
            //
            NSURL *url = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:appIdentifier];
            NSMutableArray *launchArgs = [NSMutableArray array];
            for (NSString *fileToOpen in filesToOpen) {
                [launchArgs addObject:@"-HFOpenFile"];
                [launchArgs addObject:fileToOpen];
            }
            NSDictionary *config = @{NSWorkspaceLaunchConfigurationArguments: launchArgs};
            NSError *err = nil;
            if (![[NSWorkspace sharedWorkspace] launchApplicationAtURL:url options:NSWorkspaceLaunchDefault configuration:config error:&err]) {
                fprintf(stderr, "Launch app failed: %s\n", err.localizedDescription.UTF8String);
                return EXIT_FAILURE;
            }
        }
    }
    return EXIT_SUCCESS;
}
