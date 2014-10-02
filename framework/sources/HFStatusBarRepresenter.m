//
//  HFStatusBarRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFStatusBarRepresenter.h>
#import <HexFiend/HFFunctions.h>

#define kHFStatusBarDefaultModeUserDefaultsKey @"HFStatusBarDefaultMode"

@interface HFStatusBarView : NSView {
    NSCell *cell;
    NSSize cellSize;
    HFStatusBarRepresenter *representer;
    NSDictionary *cellAttributes;
    BOOL registeredForAppNotifications;
}

- (void)setRepresenter:(HFStatusBarRepresenter *)rep;
- (void)setString:(NSString *)string;

@end


@implementation HFStatusBarView

- (void)_sharedInitStatusBarView {
    NSMutableParagraphStyle *style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
    [style setAlignment:NSCenterTextAlignment];
    cellAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSColor colorWithCalibratedWhite:(CGFloat).15 alpha:1], NSForegroundColorAttributeName, [NSFont labelFontOfSize:10], NSFontAttributeName, style, NSParagraphStyleAttributeName, nil];
    cell = [[NSCell alloc] initTextCell:@""];
    [cell setAlignment:NSCenterTextAlignment];
    [cell setBackgroundStyle:NSBackgroundStyleRaised];
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    [self _sharedInitStatusBarView];
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    [self _sharedInitStatusBarView];
    return self;
}

// nothing to do in encodeWithCoder

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


- (NSGradient *)getGradient:(BOOL)active {
    static NSGradient *sActiveGradient;
    static NSGradient *sInactiveGradient;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sActiveGradient = [[NSGradient alloc] initWithColorsAndLocations:
                           [NSColor colorWithCalibratedWhite:.89 alpha:1.], 0.00, 
                           [NSColor colorWithCalibratedWhite:.77 alpha:1.], 0.9,
                           [NSColor colorWithCalibratedWhite:.82 alpha:1.], 1.0,
                           nil];
        
        sInactiveGradient = [[NSGradient alloc] initWithColorsAndLocations:
                             [NSColor colorWithCalibratedWhite:.93 alpha:1.], 0.00, 
                             [NSColor colorWithCalibratedWhite:.87 alpha:1.], 0.9,
                             [NSColor colorWithCalibratedWhite:.90 alpha:1.], 1.0,
                             nil];
    });
    return active ? sActiveGradient : sInactiveGradient;
}


- (void)drawRect:(NSRect)clip {
    USE(clip);
    NSRect bounds = [self bounds];
    //    [[NSColor colorWithCalibratedWhite:(CGFloat).91 alpha:1] set];
    //    NSRectFill(clip);
    
    NSWindow *window = [self window];
    BOOL drawActive = (window == nil || [window isMainWindow] || [window isKeyWindow]);
    [[self getGradient:drawActive] drawInRect:bounds angle:90.];
    
    [self drawDividerWithClip:clip];
    NSRect cellRect = NSMakeRect(NSMinX(bounds), HFCeil(NSMidY(bounds) - cellSize.height / 2), NSWidth(bounds), cellSize.height);
    [cell drawWithFrame:cellRect inView:self];
}

- (void)mouseDown:(NSEvent *)event {
    USE(event);
    HFStatusBarMode newMode = ([representer statusMode] + 1) % HFSTATUSMODECOUNT;
    [representer setStatusMode:newMode];
    [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kHFStatusBarDefaultModeUserDefaultsKey];
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
    [cell release];
    [cellAttributes release];
    [super dealloc];
}

@end

@implementation HFStatusBarRepresenter

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeInt64:statusMode forKey:@"HFStatusMode"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    statusMode = (NSUInteger)[coder decodeInt64ForKey:@"HFStatusMode"];
    return self;
}

- (instancetype)init {
    self = [super init];
    statusMode = [[NSUserDefaults standardUserDefaults] integerForKey:kHFStatusBarDefaultModeUserDefaultsKey];
    return self;
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

- (NSString *)describeOffset:(unsigned long long)offset {
    switch (statusMode) {
        case HFStatusModeDecimal: return [NSString stringWithFormat:@"%llu", offset];
        case HFStatusModeHexadecimal: return [NSString stringWithFormat:@"0x%llX", offset];
        case HFStatusModeApproximate: return [NSString stringWithFormat:@"%@", HFDescribeByteCount(offset)];
        default: [NSException raise:NSInternalInconsistencyException format:@"Unknown status mode %lu", (unsigned long)statusMode]; return @"";	
    }
}

/* same as describeOffset, except we treat Approximate like Hexadecimal */
- (NSString *)describeOffsetExcludingApproximate:(unsigned long long)offset {
    switch (statusMode) {
        case HFStatusModeDecimal: return [NSString stringWithFormat:@"%llu", offset];
        case HFStatusModeHexadecimal: 
        case HFStatusModeApproximate: return [NSString stringWithFormat:@"0x%llX", offset];
        default: [NSException raise:NSInternalInconsistencyException format:@"Unknown status mode %lu", (unsigned long)statusMode]; return @"";	
    }    
}

- (NSString *)stringForEmptySelectionAtOffset:(unsigned long long)offset length:(unsigned long long)length {
    return [NSString stringWithFormat:@"%@ out of %@", [self describeOffset:offset], [self describeLength:length]];
}

- (NSString *)stringForSingleByteSelectionAtOffset:(unsigned long long)offset length:(unsigned long long)length {
    return [NSString stringWithFormat:@"Byte %@ selected out of %@", [self describeOffset:offset], [self describeLength:length]];
}

- (NSString *)stringForSingleRangeSelection:(HFRange)range length:(unsigned long long)length {
    return [NSString stringWithFormat:@"%@ selected at offset %@ out of %@", [self describeLength:range.length], [self describeOffsetExcludingApproximate:range.location], [self describeLength:length]];
}

- (NSString *)stringForMultipleSelectionsWithLength:(unsigned long long)multipleSelectionLength length:(unsigned long long)length {
    return [NSString stringWithFormat:@"%@ selected at multiple offsets out of %@", [self describeLength:multipleSelectionLength], [self describeLength:length]];
}


- (void)updateString {
    NSString *string = nil;
    HFController *controller = [self controller];
    if (controller) {
        unsigned long long length = [controller contentsLength];
        NSArray *ranges = [controller selectedContentsRanges];
        NSUInteger rangeCount = [ranges count];
        if (rangeCount == 1) {
            HFRange range = [ranges[0] HFRange];
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

- (HFStatusBarMode)statusMode {
    return statusMode;
}

- (void)setStatusMode:(HFStatusBarMode)mode {
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
