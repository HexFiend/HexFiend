//
//  HFColumnRepresenter.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/1/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "HFColumnRepresenter.h"

static const CGFloat kShadowWidth = 6;

@interface HFColumnView : NSView

@property BOOL registeredForAppNotifications;
@property CGFloat lineCountingWidth;

@end

@implementation HFColumnView

- (void)dealloc {
    HFUnregisterViewForWindowAppearanceChanges(self, self.registeredForAppNotifications);
}

- (void)windowDidChangeKeyStatus:(NSNotification *)note {
    USE(note);
    [self setNeedsDisplay:YES];
}

- (void)viewDidMoveToWindow {
    HFRegisterViewForWindowAppearanceChanges(self, @selector(windowDidChangeKeyStatus:), !self.registeredForAppNotifications);
    self.registeredForAppNotifications = YES;
    [super viewDidMoveToWindow];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    HFUnregisterViewForWindowAppearanceChanges(self, NO);
    [super viewWillMoveToWindow:newWindow];
}

- (NSColor *)borderColor {
    if (HFDarkModeEnabled()) {
        if (@available(macOS 10.14, *)) {
            return [NSColor separatorColor];
        }
    }
    return [NSColor darkGrayColor];
}

- (NSColor *)backgroundColor {
    if (HFDarkModeEnabled()) {
        return [NSColor colorWithCalibratedWhite:0.13 alpha:1];
    }
    return [NSColor colorWithCalibratedWhite:0.87 alpha:1];
}

- (void)drawBackground {
    NSRect bounds = self.bounds;
    
    [self.backgroundColor set];
    NSRectFillUsingOperation(bounds, NSCompositeSourceOver);

    bounds.origin.x += self.lineCountingWidth;
    bounds.size.width -= self.lineCountingWidth;
    
    NSWindow *window = self.window;
    BOOL drawActive = window.isKeyWindow || window.isMainWindow;
    HFDrawShadow(HFGraphicsGetCurrentContext(), bounds, kShadowWidth, NSMinYEdge, drawActive, bounds);
    
#if 0
    [self.borderColor set];
    NSRect lineRect = self.bounds;
    lineRect.size.height = 1;
    lineRect.origin.y = 0;
    if (NSIntersectsRect(lineRect, clipRect)) {
        NSRectFillUsingOperation(lineRect, NSCompositeSourceOver);
    }
#endif
}

- (void)drawRect:(NSRect __unused)dirtyRect {
    [self drawBackground];
}

@end

@implementation HFColumnRepresenter

- (NSView *)createView {
    NSRect frame = NSMakeRect(0, 0, 10, 16/*HFLineHeightForFont(self.controller.font)*/);
    HFColumnView *result = [[HFColumnView alloc] initWithFrame:frame];
    result.autoresizingMask = NSViewWidthSizable;
    return result;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, 1);
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    [super controllerDidChange:bits];
}

- (void)setLineCountingWidth:(CGFloat)width {
    HFColumnView *view = self.view;
    if (view.lineCountingWidth != width) {
        view.lineCountingWidth = width;
        [view setNeedsDisplay:YES];
    }
}

@end
