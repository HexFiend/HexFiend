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

- (void)showInstructionsFromEditScript:(HFByteArrayEditScript *)script {
    NSUInteger i, insnCount = [script numberOfInstructions];
    for (i=0; i < insnCount; i++) {
        struct HFEditInstruction_t insn = [script instructionAtIndex:i];
        if (insn.isInsertion) {
            [[[rightTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeDiffInsertion range:HFRangeMake(insn.offsetInDestinationForInsertion, insn.range.length)];
        }
        else {
            [[[leftTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeDiffInsertion range:insn.range];        
        }
    }
    [[rightTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
    [[leftTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
}

- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right {
    if ((self = [super init])) {
        leftBytes = [left retain];
        rightBytes = [right retain];
        [controller setByteArray:leftBytes];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronizeControllers:) name:HFControllerDidChangePropertiesNotification object:controller];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFControllerDidChangePropertiesNotification object:controller];
    [leftBytes release];
    [rightBytes release];
    [super dealloc];
}

- (void)synchronizeControllers:(NSNotification *)note {
    NSNumber *propertyNumber = [[note userInfo] objectForKey:HFControllerChangedPropertiesKey];
#if __LP64__
    HFControllerPropertyBits propertyMask = [propertyNumber unsignedIntegerValue];
#else
    HFControllerPropertyBits propertyMask = [propertyNumber unsignedIntValue];
#endif
    if (propertyMask & HFControllerDisplayedLineRange) {
        HFFPRange lineRange = [controller displayedLineRange];
        
    }
}

- (void)fixupTextView:(HFTextView *)textView {
    [textView setBordered:YES];
    FOREACH(HFRepresenter *, rep, [[textView controller] representers]) {
        if ([rep isKindOfClass:[HFVerticalScrollerRepresenter class]] || [rep isKindOfClass:[HFStringEncodingTextRepresenter class]]) {
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
    NSRect scrollerRect = [scroller frame];
    NSView *contentView = [[self window] contentView];
    NSRect contentBounds = [contentView bounds];
    [scroller setFrame:NSMakeRect(NSMaxX(contentBounds) - NSWidth(scrollerRect), NSMinY(contentBounds), NSWidth(scrollerRect), NSHeight(contentBounds))];
    [scroller setAutoresizingMask:NSViewHeightSizable | NSViewMinXMargin];
    [contentView addSubview:scroller];
    
    HFByteArrayEditScript *script = [[HFByteArrayEditScript alloc] initWithDifferenceFromSource:leftBytes toDestination:rightBytes];
    [self showInstructionsFromEditScript:script];
    [script release];
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
