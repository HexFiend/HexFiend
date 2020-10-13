//
//  HFRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "HFRepresenter.h"
#import <HexFiend/HFAssert.h>

@implementation HFRepresenter

- (HFView *)view {
    if (! view) {
        view = [self createView];
        [self initializeView];
    }
    return view;
}

- (BOOL)isViewLoaded {
    return !! view;
}

- (void)initializeView {
    
}

- (instancetype)init {
    self = [super init];
#if !TARGET_OS_IPHONE
    [self setLayoutPosition:[[self class] defaultLayoutPosition]];
#endif
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [coder encodeObject:controller forKey:@"HFController"];
#if !TARGET_OS_IPHONE
    [coder encodePoint:layoutPosition forKey:@"HFLayoutPosition"];
#endif
    [coder encodeObject:view forKey:@"HFRepresenterView"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super init];
#if !TARGET_OS_IPHONE
    layoutPosition = [coder decodePointForKey:@"HFLayoutPosition"];   
#endif
    controller = [coder decodeObjectForKey:@"HFController"]; // not retained
    view = [coder decodeObjectForKey:@"HFRepresenterView"];
    return self;
}

- (HFView *)createView
{
    UNIMPLEMENTED();
}

- (HFController *)controller {
    return controller;
}

- (void)_setController:(HFController *)val {
    controller = val;
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    USE(bits);
}

- (NSUInteger)bytesPerLine {
    HFASSERT([self controller] != nil);
    return [[self controller] bytesPerLine];
}

- (NSUInteger)bytesPerColumn {
    HFASSERT([self controller] != nil);
    return [[self controller] bytesPerColumn];
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    USE(viewWidth);
    return NSUIntegerMax;
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    USE(bytesPerLine);
    return 0;
}

- (NSUInteger)byteGranularity {
    return 1;
}

- (double)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
    USE(viewHeight);
    return DBL_MAX;
}

- (void)selectAll:sender {
    [[self controller] selectAll:sender];
}

- (void)representerChangedProperties:(HFControllerPropertyBits)properties {
    [[self controller] representer:self changedProperties:properties];
}

#if !TARGET_OS_IPHONE
- (void)setLayoutPosition:(NSPoint)position {
    layoutPosition = position;
}

- (NSPoint)layoutPosition {
    return layoutPosition;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, 0);
}
#endif

@end
