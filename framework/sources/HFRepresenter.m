//
//  HFRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "HFRepresenter.h"

@implementation HFRepresenter

- (id)view {
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
    [self setLayoutPosition:[[self class] defaultLayoutPosition]];
    return self;
}

- (void)dealloc {
    [view release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [coder encodeObject:controller forKey:@"HFController"];
    [coder encodePoint:layoutPosition forKey:@"HFLayoutPosition"];
    [coder encodeObject:view forKey:@"HFRepresenterView"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super init];
    layoutPosition = [coder decodePointForKey:@"HFLayoutPosition"];   
    controller = [coder decodeObjectForKey:@"HFController"]; // not retained
    view = [[coder decodeObjectForKey:@"HFRepresenterView"] retain];
    return self;
}

- (NSView *)createView {
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

- (void)setLayoutPosition:(NSPoint)position {
    layoutPosition = position;
}

- (NSPoint)layoutPosition {
    return layoutPosition;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, 0);
}

@end
