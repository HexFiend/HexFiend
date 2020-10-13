//
//  HFPrompt.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 12/29/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFPrompt.h"
#import <AppKit/AppKit.h>

NSString *HFPromptForValue(NSString *promptText) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = promptText;
    alert.informativeText = @"";
    [alert addButtonWithTitle:NSLocalizedString(@"OK", "")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "")];
    NSTextField *textField = [[NSTextField alloc] init];
    [textField sizeToFit];
    NSRect frame = textField.frame;
    frame.size.width = 200;
    textField.frame = frame;
    alert.accessoryView = textField;
    alert.window.initialFirstResponder = textField;
    if ([alert runModal] != NSAlertFirstButtonReturn) {
        return nil;
    }
    return textField.stringValue;
}
