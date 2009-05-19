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
    cellAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor colorWithCalibratedWhite:(CGFloat).22 alpha:1], NSForegroundColorAttributeName, [NSFont labelFontOfSize:10], NSFontAttributeName, style, NSParagraphStyleAttributeName, nil];
    cell = [[NSCell alloc] initTextCell:@""];
    [cell setAlignment:NSCenterTextAlignment];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)setRepresenter:(HFStatusBarRepresenter *)rep {
    representer = rep;
}

- (void)setString:(NSString *)string {
    [cell setAttributedStringValue:[[[NSAttributedString alloc] initWithString:string attributes:cellAttributes] autorelease]];
    cellSize = [cell cellSize];
    [self setNeedsDisplay:YES];
}

- (void)drawDividerWithClip:(NSRect)clipRect {
    [[NSColor lightGrayColor] set];
    NSRect bounds = [self bounds];
    NSRect lineRect = bounds;
    lineRect.size.height = 1;
    NSRectFill(NSIntersectionRect(lineRect, clipRect));
}


- (void)drawRect:(NSRect)clip {
    USE(clip);
#if 0
    NSImage *image = HFImageNamed(@"HFMetalGradientVertical");
    [image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
#else
    [[NSColor colorWithCalibratedWhite:(CGFloat).91 alpha:1] set];
    NSRectFill(clip);
    [self drawDividerWithClip:clip];
#endif
    NSRect bounds = [self bounds];
    NSRect cellRect = NSMakeRect(NSMinX(bounds), HFCeil(NSMidY(bounds) - cellSize.height / 2), NSWidth(bounds), cellSize.height);
    [cell drawWithFrame:cellRect inView:self];
}

- (void)mouseDown:(NSEvent *)event {
    USE(event);
    [representer setStatusMode:([representer statusMode] + 1) % HFSTATUSMODECOUNT];
}

@end

@implementation HFStatusBarRepresenter

static inline const char *plural(unsigned long long s) {
    return (s == 1 ? "" : "s");
}

- (NSView *)createView {
    HFStatusBarView *view = [[HFStatusBarView alloc] initWithFrame:NSMakeRect(0, 0, 100, 18)];
    [view setRepresenter:self];
    [view setAutoresizingMask:NSViewWidthSizable];
    return view;
}

- (NSString *)describeLength:(unsigned long long)length {
    switch (statusMode) {
        case HFStatusModeDecimal: return [NSString stringWithFormat:@"%llu byte%s", length, length == 1 ? "" : "s"];
        case HFStatusModeHexadecimal: return [NSString stringWithFormat:@"0x%llX byte%s", length, length == 1 ? "" : "s"];
        case HFStatusModeApproximate: return [NSString stringWithFormat:@"%@", HFDescribeByteCount(length)];
        default: [NSException raise:NSInternalInconsistencyException format:@"Unknown status mode %lu", (unsigned long)statusMode]; return @"";
    }
}

- (NSString *)stringForEmptySelectionAtOffset:(unsigned long long)offset length:(unsigned long long)length {
    return [NSString stringWithFormat:@"%llu out of %@", offset, [self describeLength:length]];
}

- (NSString *)stringForSingleByteSelectionAtOffset:(unsigned long long)offset length:(unsigned long long)length {
    return [NSString stringWithFormat:@"Byte %llu selected out of %@", offset, [self describeLength:length]];
}

- (NSString *)stringForSingleRangeSelection:(HFRange)range length:(unsigned long long)length {
    return [NSString stringWithFormat:@"%llu byte%s selected at offset %llu out of %@", range.length, plural(range.length), range.location, [self describeLength:length]];
}

- (NSString *)stringForMultipleSelectionsWithLength:(unsigned long long)multipleSelectionLength length:(unsigned long long)length {
    return [NSString stringWithFormat:@"%llu byte%s selected at multiple offsets out of %@", multipleSelectionLength, plural(multipleSelectionLength), [self describeLength:length]];
}


- (void)updateString {
    NSString *string = nil;
    HFController *controller = [self controller];
    if (controller) {
        unsigned long long length = [controller contentsLength];
        NSArray *ranges = [controller selectedContentsRanges];
        NSUInteger rangeCount = [ranges count];
        if (rangeCount == 1) {
            HFRange range = [[ranges objectAtIndex:0] HFRange];
            if (range.length == 0) {
                string = [self stringForEmptySelectionAtOffset:range.location length:length];
            }
            else if (range.length == 1) {
                string = [self stringForSingleByteSelectionAtOffset:range.location length:length];
            }
            else {
                string = [self stringForSingleRangeSelection:range length:length];
            }
        }
        else {
            unsigned long long totalSelectionLength = 0;
            FOREACH(HFRangeWrapper *, wrapper, ranges) {
                HFRange range = [wrapper HFRange];
                totalSelectionLength = HFSum(totalSelectionLength, range.length);
            }
            string = [self stringForMultipleSelectionsWithLength:totalSelectionLength length:length];
        }
    }
    if (! string) string = @"";
    [[self view] setString:string];
}

- (NSUInteger)statusMode {
    return statusMode;
}

- (void)setStatusMode:(NSUInteger)mode {
    statusMode = mode;
    [self updateString];
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
