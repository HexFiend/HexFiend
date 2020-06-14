//
//  HFClickableTextField.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 6/13/20.
//  Copyright © 2020 ridiculous_fish. All rights reserved.
//

#import "HFClickableTextField.h"

@implementation HFClickableTextField

- (void)awakeFromNib {
    if (@available(macOS 10.10, *)) {
        self.textColor = NSColor.linkColor;
    } else {
        self.textColor = NSColor.blueColor;
    }
}

- (void)viewDidMoveToWindow {
    if (@available(macOS 10.10, *)) {
        NSClickGestureRecognizer *gesture = [[NSClickGestureRecognizer alloc] init];
        gesture.action = @selector(handleGesture);
        gesture.target = self;
        [self addGestureRecognizer:gesture];
    }
}

- (void)handleGesture {
    NSURL *url = [NSURL URLWithString:self.stringValue];
    if (![NSWorkspace.sharedWorkspace openURL:url]) {
        NSLog(@"Failed to open %@", url);
    }
}

- (void)resetCursorRects
{
    [self addCursorRect:self.bounds cursor:NSCursor.pointingHandCursor];
}

@end
