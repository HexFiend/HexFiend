//
//  CLIController.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 2013/3/19.
//  Copyright © 2017 ridiculous_fish. All rights reserved.
//

#import "CLIController.h"

@implementation CLIController

- (IBAction)installCommandLineTools:(id __unused)sender
{
    NSString *srcFile = [[NSBundle mainBundle] pathForResource:@"hexf" ofType:nil];
    NSString *destDir = @"/usr/local/bin";
    NSString *destFile = [destDir stringByAppendingPathComponent:[srcFile lastPathComponent]];
    NSError *err = nil;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:destFile]) {
        [fm removeItemAtPath:destFile error:&err];
        if (err != nil) {
            [[NSDocumentController sharedDocumentController] presentError:err];
            return;
        }
    }
    [fm copyItemAtPath:srcFile toPath:destFile error:&err];
    if (err != nil) {
        [[NSDocumentController sharedDocumentController] presentError:err];
        return;
    }
    NSDictionary *attrs = @{
        NSFilePosixPermissions : @(0755),
    };
    [fm setAttributes:attrs ofItemAtPath:destFile error:&err];
    if (err != nil) {
        [[NSDocumentController sharedDocumentController] presentError:err];
        return;
    }
    NSAlert *successAlert = [[NSAlert alloc] init];
    successAlert.messageText = [NSString stringWithFormat:NSLocalizedString(@"The %@ tool has been successfully installed.", ""), [srcFile lastPathComponent]];
    [successAlert runModal];
}

@end
