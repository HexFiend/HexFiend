//
//  HFRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
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

- (void)initializeView {
    
}

- (void)dealloc {
    [view release];
    [super dealloc];
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
    return [[self controller] bytesPerLine];
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    USE(viewWidth);
    return ULONG_MAX;
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    USE(bytesPerLine);
    return 0;
}

- (NSUInteger)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
    USE(viewHeight);
    return ULONG_MAX;
}

- (NSUInteger)maximumNumberOfBytesForViewSize:(NSSize)viewSize {
    NSUInteger bytesPerLine = [self maximumBytesPerLineForViewWidth:viewSize.width];
    NSUInteger availableLines = [self maximumAvailableLinesForViewHeight:viewSize.height];
    if (bytesPerLine == ULONG_MAX || availableLines == ULONG_MAX) return ULONG_MAX;
    else return bytesPerLine * availableLines;
}

- (void)viewChangedProperties:(HFControllerPropertyBits)properties {
    [[self controller] representer:self changedProperties:properties];
}

@end
