//
//  DiffDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 10/5/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "DiffDocument.h"
#import <HexFiend/HexFiend.h>

@implementation DiffDocument

- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right {
    if ((self = [super init])) {
        leftBytes = [left retain];
        rightBytes = [right retain];
        [controller setByteArray:leftBytes];
    }
    return self;
}

- (void)dealloc {
    [leftBytes release];
    [rightBytes release];
    [super dealloc];
}

- (void)fixupTextView:(HFTextView *)textView {
    [textView setBordered:YES];
    FOREACH(HFRepresenter *, rep, [[textView controller] representers]) {
        if ([rep isKindOfClass:[HFVerticalScrollerRepresenter class]]) {
            [[textView layoutRepresenter] removeRepresenter:rep];
            [[textView controller] removeRepresenter:rep];
        }
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
    [super windowControllerDidLoadNib:windowController];
    [self fixupTextView:leftTextView];
    [self fixupTextView:rightTextView];
    [[leftTextView controller] setByteArray:leftBytes];
    [[rightTextView controller] setByteArray:rightBytes];
    [layoutRepresenter removeRepresenter:scrollRepresenter];
    
    NSScroller *scroller = [scrollRepresenter view];
    NSView *contentView = [[self window] contentView];
    NSRect contentBounds = [contentView bounds];
    NSRect scrollerRect = [contentView bounds];
    [scroller setFrame:NSMakeRect(NSMaxX(contentBounds) - NSWidth(scrollerRect), NSMinY(contentBounds), NSWidth(scrollerRect), NSHeight(contentBounds))];
    [scroller setAutoresizingMask:NSViewHeightSizable | NSViewMinXMargin];
    [contentView addSubview:scroller];
}

- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"DiffDocument";
}

- (void)setFont:(NSFont *)font {
    [[self window] disableFlushWindow];
    [super setFont:font];
    [[leftTextView controller] setFont:font];
    [[rightTextView controller] setFont:font];
    [[self window] enableFlushWindow];
}

@end
