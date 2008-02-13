//
//  HFTextField.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/2/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFTextField.h>
#import <HexFiend/HFTavlTreeByteArray.h>
#import <HexFiend/HFController.h>
#import <HexFiend/HFLayoutRepresenter.h>
#import <HexFiend/HFHexTextRepresenter.h>

@implementation HFTextField

- (void)positionLayoutView {
    NSRect viewFrame = [self bounds];
    viewFrame.size.height -= 3;
    viewFrame.origin.y += 1;
    viewFrame.origin.x += 1;
    viewFrame.size.width -= 2;
    [[layoutRepresenter view] setFrame:viewFrame];
}

- (id)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        dataController = [[HFController alloc] init];
    
        layoutRepresenter = [[HFLayoutRepresenter alloc] init];
        activeRepresenter = [[HFHexTextRepresenter alloc] init];
        [[activeRepresenter view] setShowsFocusRing:YES];
        [[activeRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [dataController addRepresenter:activeRepresenter];
        [layoutRepresenter addRepresenter:activeRepresenter];
        [dataController addRepresenter:layoutRepresenter];
        NSView *layoutView = [layoutRepresenter view];
        [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [self positionLayoutView];
        [self addSubview:layoutView];
    }
    return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [self positionLayoutView];
}

- (void)drawRect:(NSRect)rect {
    NSRect bounds = [self bounds];
    NSRect horizontalLine = NSMakeRect(NSMinX(bounds), NSMaxY(bounds) - 1, NSWidth(bounds), 1);
    NSRect verticalLine = NSMakeRect(NSMinX(bounds), 1, 1, NSHeight(bounds) - 2);
    NSRect lines[5];
    NSColor *colors[5] = {
        [NSColor colorWithCalibratedWhite:(CGFloat)(114./255.) alpha:1],
        [NSColor colorWithCalibratedWhite:(CGFloat)(203./255.) alpha:1],
        [NSColor colorWithCalibratedWhite:(CGFloat)(218./255.) alpha:1],
        [NSColor colorWithCalibratedWhite:(CGFloat)(180./255.) alpha:1],
        [NSColor colorWithCalibratedWhite:(CGFloat)(180./255.) alpha:1]
    };
    lines[0] = horizontalLine;
    horizontalLine.origin.y -= 1;
    lines[1] = horizontalLine;
    horizontalLine.origin.y = NSMinY(bounds);
    lines[2] = horizontalLine;
    lines[3] = verticalLine;
    verticalLine.origin.x = NSMaxX(bounds) - verticalLine.size.width;
    lines[4] = verticalLine;
        
    [[NSColor purpleColor] set];
    NSRectFill([self bounds]);
    NSRectFillListWithColors(lines, colors, 5);
}

- (BOOL)becomeFirstResponder {
    return [[self window] makeFirstResponder:[activeRepresenter view]];
}

- (void)insertNewline:sender {
    [self sendAction:[self action] to:[self target]];
}

- (id)target {
    return target;
}

- (SEL)action {
    return action;
}

- (void)setTarget:(id)val {
    target = val;
}

- (void)setAction:(SEL)val {
    action = val;
}

- (id)objectValue {
    return [dataController byteArray];
}

- (void)setObjectValue:(id)value {
    EXPECT_CLASS(value, HFByteArray);
    [dataController setByteArray:value];
}

@end
