//
//  TextDividerRepresenter.m
//  HexFiend_2
//
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import "TextDividerRepresenter.h"
#import <HexFiend/HFFunctions.h>

#define DIVIDER_WIDTH 8
#define SHADOW_WIDTH 4
#define SHADOW_ALPHA .25

@interface TextDividerRepresenterView : NSView {
    BOOL registeredForAppNotifications;
}
@end

@implementation TextDividerRepresenterView : NSView

- (void)drawRect:(NSRect)clip {
    NSWindow *window = [self window];
    BOOL drawActive = (window == nil || [window isKeyWindow] || [window isMainWindow]);
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    const CGFloat shadowWidth = SHADOW_WIDTH;
    
    [[NSColor colorWithCalibratedWhite:(CGFloat).87 alpha:1] set];
    NSRectFill(clip);
    NSRect bounds = [self bounds];
    
    // Draw left and right shadow
    HFDrawShadow(ctx, bounds, shadowWidth, NSMinXEdge, drawActive, clip);
    HFDrawShadow(ctx, bounds, shadowWidth, NSMaxXEdge, drawActive, clip);
    
    // Draw dividers
    [[NSColor darkGrayColor] set];
    NSRect divider = bounds;
    divider.size.width = 1;
    NSRectFill(divider);
    divider.origin.x = NSMaxX(bounds) - 1;
    NSRectFill(divider);
}

- (void)windowDidChangeKeyStatus:(NSNotification *)note {
    USE(note);
    [self setNeedsDisplay:YES];
}

- (void)viewDidMoveToWindow {
    HFRegisterViewForWindowAppearanceChanges(self, @selector(windowDidChangeKeyStatus:), !registeredForAppNotifications);
    registeredForAppNotifications = YES;
    [super viewDidMoveToWindow];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    HFUnregisterViewForWindowAppearanceChanges(self, NO);
    [super viewWillMoveToWindow:newWindow];
}

- (void)dealloc {
    HFUnregisterViewForWindowAppearanceChanges(self, registeredForAppNotifications);
    [super dealloc];
}

@end


@implementation TextDividerRepresenter

- (NSView *)createView {
    TextDividerRepresenterView *result = [[TextDividerRepresenterView alloc] initWithFrame:NSMakeRect(0, 0, 10, 10)];
    [result setAutoresizingMask:NSViewHeightSizable];
    return result;
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    USE(bytesPerLine);
    return DIVIDER_WIDTH;
}

@end

