//
//  HFRepresenterVerticalScroller.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/12/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFVerticalScrollerRepresenter.h>


@implementation HFVerticalScrollerRepresenter

- (NSView *)createView {
    NSScroller *scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, 0, [NSScroller scrollerWidthForControlSize:NSRegularControlSize], 64)];
    [scroller setTarget:self];
    [scroller setContinuous:YES];
    [scroller setEnabled:YES];
    [scroller setTarget:self];
    [scroller setAction:@selector(scrollerDidChangeValue:)];
    [scroller setFloatValue:.3 knobProportion:.4];
    return scroller;
}

- (void)scrollerDidChangeValue:sender {
    NSLog(@"%s", _cmd);
}

- (void)updateScrollerValue {
    HFController *controller = [self controller];
    CGFloat value, proportion;
    if (controller == nil) {
        value = 0;
        proportion = 0;
    }
    else {
        unsigned long long length = [controller contentsLength];
        HFRange displayedRange = [controller displayedContentsRange];
        if (length == 0) value = 0;
        else value = (double)displayedRange.location / (double)length;
        
        if (length == 0) proportion = 0;
        else proportion = (double)displayedRange.length / (double)length;
    }
    [[self view] setFloatValue:value knobProportion:proportion];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerContentLength | HFControllerDisplayedRange)) [self updateScrollerValue];
}

@end
