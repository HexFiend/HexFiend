//
//  TextDividerRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 6/22/11.
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

static CGFloat interpolateShadow(CGFloat val) {
    //A value of 1 means we are at the rightmost, and should return our max value.  By adjusting the scale, we control how quickly the shadow drops off.
    CGFloat scale = 1.4;
    return (CGFloat)(expm1(val * scale) / expm1(scale));
}

static void drawShadow(CGContextRef ctx, NSRect startRect, CGFloat xOffset, CGFloat shadowWidth, CGFloat maxAlpha) {
    NSRect shadowLine = startRect;
    for (CGFloat i=0; i < shadowWidth; i++) {
        CGFloat gray = 0.;
        CGFloat alpha = maxAlpha * interpolateShadow((shadowWidth - i) / shadowWidth);
        CGContextSetGrayFillColor(ctx, gray, alpha);
        CGContextFillRect(ctx, shadowLine);
        shadowLine.origin.x += xOffset;
    }
}

@implementation TextDividerRepresenterView : NSView

- (void)drawRect:(NSRect)clip {
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    NSWindow *window = [self window];
    BOOL drawActive = (window == nil || [window isKeyWindow] || [window isMainWindow]);
    CGFloat maxAlpha = (drawActive ? SHADOW_ALPHA : .10);

#if 0
    
    [[NSColor whiteColor] set];
    NSRectFill(clip);
    
    [[NSColor colorWithCalibratedWhite:(CGFloat).87 alpha:1] set];
    NSRect bounds = [self bounds];
    NSRect grooveLines[2];
    grooveLines[0] = bounds;
    grooveLines[0].size.width = 1;
    
    grooveLines[1] = bounds;
    grooveLines[1].size.width = 1;
    grooveLines[1].origin.x = NSMaxX(bounds) - grooveLines[1].size.width;
    
    CGContextFillRects(ctx, grooveLines, 2);
    

#else
    const CGFloat shadowWidth = SHADOW_WIDTH;
    
    [[NSColor colorWithCalibratedWhite:(CGFloat).87 alpha:1] set];
    NSRectFill(clip);
    NSRect bounds = [self bounds];
    
    // Manually drawn shadow
    
    // Draw left shadow
    NSRect shadowLine = bounds;
    shadowLine.size.width = 1;
    drawShadow(ctx, shadowLine, 1, shadowWidth, maxAlpha);
    
    // Draw right shadow
    shadowLine.origin.x = NSMaxX(bounds) - shadowLine.size.width;
    drawShadow(ctx, shadowLine, -1, shadowWidth, maxAlpha);
    
    // Draw dividers
    [[NSColor darkGrayColor] set];
    NSRect divider = bounds;
    divider.size.width = 1;
    NSRectFill(divider);
    divider.origin.x = NSMaxX(bounds) - 1;
    NSRectFill(divider);
#endif
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

