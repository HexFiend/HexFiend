//
//  HFStatusBarRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 12/16/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFStatusBarRepresenter.h"

@interface HFStatusBarView : NSView {
    NSCell *cell;
    HFStatusBarRepresenter *representer;
}

- (void)setRepresenter:(HFStatusBarRepresenter *)rep;
- (void)setString:(NSString *)string;

@end

@implementation HFStatusBarView

- (void)dealloc {
    [cell release];
    [super dealloc];
}

- initWithFrame:(NSRect)frame {
    [super initWithFrame:frame];
    cell = [[NSCell alloc] initTextCell:@""];
    return self;
}

- (void)setRepresenter:(HFStatusBarRepresenter *)rep {
    representer = rep;
}

- (void)setString:(NSString *)string {
    [cell setStringValue:string];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
    NSImage *image = HFImageNamed(@"HFMetalGradientVertical");
    [image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
    [cell drawWithFrame:[self bounds] inView:self];
}

@end

@implementation HFStatusBarRepresenter

- (NSView *)createView {
    HFStatusBarView *view = [[HFStatusBarView alloc] initWithFrame:NSMakeRect(0, 0, 100, 18)];
    [view setRepresenter:self];
    [view setAutoresizingMask:NSViewWidthSizable];
    return view;
}

- (void)updateString {
    NSString *string = nil;
    HFController *controller = [self controller];
    if (controller) {
        unsigned long long length = [controller contentsLength];
        string = [NSString stringWithFormat:@"llu byte%@", length, (length == 1 ? @"" : @"s")];
    }
    [[self view] setString:string];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerContentLength & HFControllerSelectedRanges)) {
        [self updateString];
    }
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, -1);
}

@end
