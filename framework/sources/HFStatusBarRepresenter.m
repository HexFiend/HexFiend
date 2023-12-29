//
//  HFStatusBarRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFStatusBarRepresenter.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

#define kHFStatusBarDefaultModeUserDefaultsKey @"HFStatusBarDefaultMode"

@interface HFStatusBarView : NSTextField

@property (weak) HFStatusBarRepresenter *rep;

@end

@implementation HFStatusBarView

- (void)mouseDown:(NSEvent *)event {
    USE(event);
    HFStatusBarMode newMode = ([self.rep statusMode] + 1) % HFSTATUSMODECOUNT;
    [self.rep setStatusMode:newMode];
    [[NSUserDefaults standardUserDefaults] setInteger:newMode forKey:kHFStatusBarDefaultModeUserDefaultsKey];
}

@end

@implementation HFStatusBarRepresenter {
    HFStatusBarMode statusMode;
    HFStatusBarView *_statusView;
}

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
    _statusView = [[HFStatusBarView alloc] initWithFrame:NSZeroRect];
    _statusView.drawsBackground = NO;
    _statusView.editable = NO;
    _statusView.selectable = NO;
    _statusView.bordered = NO;
    _statusView.bezeled = NO;
    _statusView.alignment = NSTextAlignmentCenter;
    _statusView.textColor = NSColor.secondaryLabelColor;
    _statusView.font = [NSFont labelFontOfSize:10];
    _statusView.rep = self;
    _statusView.autoresizingMask = NSViewWidthSizable;
    if ([self controller] == nil) {
        // controllerDidChange already called updateString so avoid clobbering it
        _statusView.stringValue = [NSString stringWithUTF8String:__FUNCTION__]; // dummy
    }
    [_statusView sizeToFit];
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, _statusView.bounds.size.width, _statusView.bounds.size.height + 4)];
    NSRect statusFrame = _statusView.frame;
    NSRect bounds = view.bounds;
    statusFrame.origin.y = bounds.origin.y + floor((bounds.size.height - statusFrame.size.height) / 2);
    _statusView.frame = statusFrame;
    [view setAutoresizingMask:NSViewWidthSizable];
    [view addSubview:_statusView];
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
            for(HFRangeWrapper * wrapper in ranges) {
                HFRange range = [wrapper HFRange];
                totalSelectionLength = HFSum(totalSelectionLength, range.length);
            }
            string = [self stringForMultipleSelectionsWithLength:totalSelectionLength length:length];
        }
    }
    if (! string) string = @"";
    _statusView.stringValue = string;
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
