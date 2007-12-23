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
    NSSize cellSize;
    HFStatusBarRepresenter *representer;
    NSDictionary *cellAttributes;
}

- (void)setRepresenter:(HFStatusBarRepresenter *)rep;
- (void)setString:(NSString *)string;

@end

@implementation HFStatusBarView

- (void)dealloc {
    [cell release];
    [cellAttributes release];
    [super dealloc];
}

- initWithFrame:(NSRect)frame {
    [super initWithFrame:frame];
    NSMutableParagraphStyle *style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [style setAlignment:NSCenterTextAlignment];
    cellAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor darkGrayColor], NSForegroundColorAttributeName, [NSFont labelFontOfSize:10], NSFontAttributeName, style, NSParagraphStyleAttributeName, nil];
    cell = [[NSCell alloc] initTextCell:@""];
    [cell setAlignment:NSCenterTextAlignment];
    return self;
}

- (void)setRepresenter:(HFStatusBarRepresenter *)rep {
    representer = rep;
}

- (void)setString:(NSString *)string {
    [cell setAttributedStringValue:[[[NSAttributedString alloc] initWithString:string attributes:cellAttributes] autorelease]];
    cellSize = [cell cellSize];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect {
    USE(rect);
    NSImage *image = HFImageNamed(@"HFMetalGradientVertical");
    [image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
    NSRect bounds = [self bounds];
    NSRect cellRect = NSMakeRect(NSMinX(bounds), HFFloor(NSMidY(bounds) - cellSize.height / 2), NSWidth(bounds), cellSize.height);
    [cell drawWithFrame:cellRect inView:self];
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
        string = [NSString stringWithFormat:@"%llu byte%@", length, (length == 1 ? @"" : @"s")];
    }
    [[self view] setString:string];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerContentLength | HFControllerSelectedRanges)) {
        [self updateString];
    }
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, -1);
}

@end
