//
//  CLIController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 2013/3/19.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

#import "CLIController.h"

@implementation CLIController

- (void)runAlert:(NSString *)messageText {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = messageText;
    [alert runModal];
}

- (IBAction)installCommandLineTools:(id __unused)sender
{
    NSString *srcFile = [[NSBundle mainBundle] pathForResource:@"hexf" ofType:nil];
    NSString *destDir = @"/usr/local/bin";
    NSString *destFile = [destDir stringByAppendingPathComponent:[srcFile lastPathComponent]];
    NSString *cmd = [NSString stringWithFormat:@"mkdir -p \\\"%@\\\" && ln -fs \\\"%@\\\" \\\"%@\\\" && chmod 755 \\\"%@\\\"",
        destDir, srcFile, destFile, destFile];
    NSString *script = [NSString stringWithFormat:@"do shell script \"%@\" with administrator privileges", cmd];
    NSAppleScript *appleScript = [[NSAppleScript alloc] initWithSource:script];
    NSDictionary *errInfo = nil;
    // NOTE: running this in Debug mode in Xcode often hangs and fails
    if (![appleScript executeAndReturnError:&errInfo]) {
        if ([errInfo[NSAppleScriptErrorNumber] intValue] == -128) {
            // User cancelled
            return;
        }
        [self runAlert:errInfo[NSAppleScriptErrorMessage]];
        return;
    }
    if (/* DISABLES CODE */ (0)) {
    // if NSAppleScript above turns out problematic, try the osascript variant instead
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/osascript";
    task.arguments = @[@"-e", script];
    NSPipe *standardErrorPipe = [NSPipe pipe];
    task.standardError = standardErrorPipe;
    @try {
        [task launch];
    } @catch (NSException *ex) {
        [self runAlert:[NSString stringWithFormat:NSLocalizedString(@"Failed to run command: %@", nil), ex]];
        return;
    }
    [task waitUntilExit];
    NSFileHandle *standardErrorFile = [standardErrorPipe fileHandleForReading];
    NSData *standardErrorData = [standardErrorFile readDataToEndOfFile];
    if (task.terminationStatus != 0) {
        NSString *standardErrorStr = [[NSString alloc] initWithData:standardErrorData encoding:NSUTF8StringEncoding];
        if ([standardErrorStr rangeOfString:@"User canceled" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return;
        }
        [self runAlert:[NSString stringWithFormat:NSLocalizedString(@"The %@ tool failed to install (%@).", ""), [srcFile lastPathComponent], standardErrorStr]];
        return;
    }
    }
    [self runAlert:[NSString stringWithFormat:NSLocalizedString(@"%@ has been successfully installed.", ""), [srcFile lastPathComponent]]];
}

#if MacAppStore
// We cannot install hexf in MAS builds.
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if ([item action] == @selector(installCommandLineTools:)) {
        [item setHidden:YES];
        return NO;
    }
    return YES;
}
#endif

@end
