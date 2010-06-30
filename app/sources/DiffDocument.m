//
//  DiffDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 10/5/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "DiffDocument.h"
#import "DiffOverlayView.h"
#import <HexFiend/HexFiend.h>

@implementation DiffDocument

- (NSString *)displayName {
    return [NSString stringWithFormat:@"%@ vs %@", leftFileName, rightFileName];
}

- (void)showInstructionsFromEditScript {
    NSUInteger i, insnCount = [editScript numberOfInstructions];
    for (i=0; i < insnCount; i++) {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:i];
	if (insn.dst.length > 0) {
	    [[[rightTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeDiffInsertion range:insn.dst];
	}
	if (insn.src.length > 0) {
	    [[[leftTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeDiffInsertion range:insn.src];        	    
	}
    }
    [[rightTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
    [[leftTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
    [diffTable reloadData];
}

- (HFTextRepresenter *)textRepresenterFromTextView:(HFTextView *)textView {
    FOREACH(HFRepresenter *, rep, [[textView controller] representers]) {
        if ([rep isKindOfClass:[HFTextRepresenter class]]) {
            return (HFTextRepresenter *)rep;
        }
    }    
    return nil; 
}

static enum DiffOverlayViewRangeType_t rangeTypeForValue(CGFloat value) {
    if (value == CGFLOAT_MAX) return DiffOverlayViewRangeIsBelow;	
    else if (value == -CGFLOAT_MAX) return DiffOverlayViewRangeIsAbove;
    else return DiffOverlayViewRangeIsVisible;
}

- (void)updateOverlayViewForLeftRange:(HFRange)leftRange rightRange:(HFRange)rightRange {
    HFTextRepresenter *left = [self textRepresenterFromTextView:leftTextView], *right = [self textRepresenterFromTextView:rightTextView];
    if (left && right) {
        NSRect leftRect, rightRect;
        if (leftRange.length == 0) {
            leftRect.origin = [left locationOfCharacterAtByteIndex:leftRange.location];
            leftRect.size = NSMakeSize(0, [[leftTextView controller] lineHeight]);
        }
        else {
            leftRect = [left furthestRectOnEdge:NSMaxXEdge forByteRange:leftRange];
        }
        if (rightRange.length == 0) {
            rightRect.origin = [right locationOfCharacterAtByteIndex:rightRange.location];
            rightRect.size = NSMakeSize(0, [[rightTextView controller] lineHeight]);
        }
        else {
            rightRect = [right furthestRectOnEdge:NSMinXEdge forByteRange:rightRange];
        }
	 //leftRect and rightRect may have origins of CGFLOAT_MAX and -CGFLOAT_MAX.  Converting them is a sketchy thing to do.  But in that case, the range type will be RangeIsAbove or RangeIsBelow, in which case the rect is ignored
	
        [overlayView setLeftRangeType:rangeTypeForValue(leftRect.origin.x) rect:[overlayView convertRect:leftRect fromView:[left view]]];
        [overlayView setRightRangeType:rangeTypeForValue(rightRect.origin.x) rect:[overlayView convertRect:rightRect fromView:[right view]]];
    }
}

- (long long)changeInLengthBeforeByte:(unsigned long long)byte onLeft:(BOOL)isLeft {
    long long diff = 0;
    NSUInteger insnIndex, insnCount = [editScript numberOfInstructions];
    for (insnIndex = 0; insnIndex < insnCount; insnIndex++) {
	struct HFEditInstruction_t insn = [editScript instructionAtIndex:insnIndex];
	
	/* If we've gone past the byte we care about, we're done */
	unsigned long long insnStartByte = (isLeft ? insn.src.location : insn.dst.location);
	if (byte <= insnStartByte) break;
	
	/* Compute how the length changed according to this instruction, by adding the left amount and deleting the right amount (or vice-versa if isLeft is NO) */
	long long lengthChange = (long long)(insn.src.length - insn.dst.length);
	if (isLeft) lengthChange = - lengthChange;
	diff += lengthChange;
    }
    
    return diff;
}

- (void)updateInstructionOverlayView {
    if (focusedInstructionIndex >= [editScript numberOfInstructions]) {
	[overlayView setHidden:YES];
    }
    else {
	struct HFEditInstruction_t instruction = [editScript instructionAtIndex:focusedInstructionIndex];
	[[[leftTextView controller] byteRangeAttributeArray] removeAttribute:kHFAttributeFocused];
	[[[rightTextView controller] byteRangeAttributeArray] removeAttribute:kHFAttributeFocused];
	HFRange leftRange = instruction.src, rightRange = instruction.dst;
	
	if (leftRange.length > 0) {
	    [[[leftTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeFocused range:leftRange];
	}
	if (rightRange.length > 0) {
	    [[[rightTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeFocused range:rightRange];
	}
	[[rightTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
	[[leftTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
	
	// if we are deleting, then the rightRange is empty and has a nonsense location.  Point it at the beginning of the range we're deleting
	if (! rightRange.length) {
	    rightRange.location = leftRange.location + [self changeInLengthBeforeByte:leftRange.location onLeft:YES];
	}
	
	[self updateOverlayViewForLeftRange:leftRange rightRange:rightRange];
	[overlayView setHidden:NO];
    }    
}

- (void)updateTableViewSelection {
    if (focusedInstructionIndex >= [editScript numberOfInstructions]) {
	[diffTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    }
    else {
	[diffTable selectRowIndexes:[NSIndexSet indexSetWithIndex:focusedInstructionIndex] byExtendingSelection:NO];
	[diffTable scrollRowToVisible:focusedInstructionIndex];
    }
}

- (void)scrollToFocusedInstruction {
    if (focusedInstructionIndex < [editScript numberOfInstructions]) {
	struct HFEditInstruction_t instruction = [editScript instructionAtIndex:focusedInstructionIndex];
	
	HFRange leftRange = instruction.src, rightRange = instruction.dst;
	if (! rightRange.length) {
	    rightRange.location = leftRange.location + [self changeInLengthBeforeByte:leftRange.location onLeft:YES];
	}
	
	[controller centerContentsRange:rightRange];
	[[leftTextView controller] centerContentsRange:leftRange];
	[[rightTextView controller] centerContentsRange:rightRange];
    }
}

- (void)setFocusedInstructionIndex:(NSUInteger)idx {
    focusedInstructionIndex = idx;
    [self scrollToFocusedInstruction];
    [self updateInstructionOverlayView];
    [self updateTableViewSelection];
}

- (void)selectInDirection:(NSInteger)direction {
    if (direction < 0 && (NSUInteger)(-direction) > focusedInstructionIndex) {
        /* Underflow */
        NSBeep();
    }
    else if (direction > 0 && direction + focusedInstructionIndex >= [editScript numberOfInstructions]) {
        /* Overflow */
        NSBeep();
    }
    else {
        [self setFocusedInstructionIndex:focusedInstructionIndex + direction];
    }
}

- (BOOL)firstResponderIsInView:(NSView *)view {
    id fr = [[self window] firstResponder];
    if ([fr isKindOfClass:[NSView class]]) {
        while (fr) {
            if (fr == view) break;
            fr = [fr superview];
        }
    }
    return fr && fr == view;
}

- (BOOL)handleEvent:(NSEvent *)event {
    BOOL handled = NO;
    BOOL frInLeftView = [self firstResponderIsInView:leftTextView], frInRightView = [self firstResponderIsInView:rightTextView];
    if (frInLeftView || frInRightView) {
        NSUInteger prohibitedFlags = (NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask | NSCommandKeyMask);
        if ([event type] == NSKeyDown && ! (prohibitedFlags & [event modifierFlags])) {
	    /* Handle arrow keys */
            NSString *chars = [event characters];
            if ([chars length] == 1) {
                unichar c = [chars characterAtIndex:0];
                if (c == NSUpArrowFunctionKey) {
                    [self selectInDirection:-1];
                    handled = YES;
                }
                else if (c == NSDownArrowFunctionKey) {
                    [self selectInDirection:1];
                    handled = YES;
                }
            }
        }
	else if ([event type] == NSScrollWheel) {
	    /* Redirect scroll wheel events to our main view */
	    [controller scrollWithScrollEvent:event];
	    handled = YES;
	}
    }
    return handled;
}

- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right {
    if ((self = [super init])) {
        leftBytes = [left retain];
        rightBytes = [right retain];
        [controller setByteArray:rightBytes];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronizeControllers:) name:HFControllerDidChangePropertiesNotification object:controller];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFControllerDidChangePropertiesNotification object:controller];
    [leftBytes release];
    [rightBytes release];
    [leftFileName release];
    [rightFileName release];
    [super dealloc];
}

- (void)synchronizeController:(HFController *)client properties:(HFControllerPropertyBits)propertyMask {
    if (propertyMask & HFControllerDisplayedLineRange) {
        HFFPRange displayedLineRange = [controller displayedLineRange];
        NSUInteger bytesPerLine = [controller bytesPerLine];
        unsigned long long lineStart = HFFPToUL(floorl(displayedLineRange.location));
        unsigned long long firstByteShown = HFProductULL(bytesPerLine, lineStart);
        unsigned long long leftByteToShow = firstByteShown + [self changeInLengthBeforeByte:firstByteShown onLeft:YES];
	
	if ([client contentsLength] > leftByteToShow) {
	    [client centerContentsRange:HFRangeMake(leftByteToShow, 1)];
	}
        
    }
    if (propertyMask & HFControllerBytesPerColumn) {
        [client setBytesPerColumn:[controller bytesPerColumn]];
    }
    if (propertyMask & HFControllerFont) {
        [client setFont:[controller font]];
    }    
}

- (void)synchronizeControllers:(NSNotification *)note {
    NSNumber *propertyNumber = [[note userInfo] objectForKey:HFControllerChangedPropertiesKey];
#if __LP64__
    HFControllerPropertyBits propertyMask = [propertyNumber unsignedIntegerValue];
#else
    HFControllerPropertyBits propertyMask = [propertyNumber unsignedIntValue];
#endif
    [self synchronizeController:[leftTextView controller] properties:propertyMask];
    [self synchronizeController:[rightTextView controller] properties:propertyMask];
    
    /* Update the overlay view to react to things like the bytes per line changing. */
    [self updateInstructionOverlayView];
}

- (void)fixupTextView:(HFTextView *)textView {
    [textView setBordered:YES];
    HFLineCountingRepresenter *lineCounter = [[HFLineCountingRepresenter alloc] init];
    [[textView controller] addRepresenter:lineCounter];
    [[textView layoutRepresenter] addRepresenter:lineCounter];
    [lineCounter release];
    
    FOREACH(HFRepresenter *, rep, [[textView controller] representers]) {
        if ([rep isKindOfClass:[HFVerticalScrollerRepresenter class]] || [rep isKindOfClass:[HFStringEncodingTextRepresenter class]]) {
            [[textView layoutRepresenter] removeRepresenter:rep];
            [[textView controller] removeRepresenter:rep];
        }
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
    [super windowControllerDidLoadNib:windowController];
    NSWindow *window = [self window];
    [self fixupTextView:leftTextView];
    [self fixupTextView:rightTextView];
    [[leftTextView controller] setByteArray:leftBytes];
    [[rightTextView controller] setByteArray:rightBytes];
    [layoutRepresenter removeRepresenter:scrollRepresenter];
    
    NSScroller *scroller = [scrollRepresenter view];
    NSRect scrollerRect = [scroller frame];
    NSView *contentView = [window contentView];
    NSRect contentBounds = [contentView bounds];
    [scroller setFrame:NSMakeRect(NSMaxX(contentBounds) - NSWidth(scrollerRect), NSMinY(contentBounds), NSWidth(scrollerRect), NSHeight(contentBounds))];
    [scroller setAutoresizingMask:NSViewHeightSizable | NSViewMinXMargin];
    [contentView addSubview:scroller];
    
    editScript = [[HFByteArrayEditScript alloc] initWithDifferenceFromSource:leftBytes toDestination:rightBytes];
    [self showInstructionsFromEditScript];
    
    [self synchronizeController:[leftTextView controller] properties:(HFControllerPropertyBits)-1];
    [self synchronizeController:[rightTextView controller] properties:(HFControllerPropertyBits)-1];
    
    overlayView = [[DiffOverlayView alloc] initWithFrame:[[window contentView] bounds]];
    [overlayView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [overlayView setLeftView:leftTextView];
    [overlayView setRightView:rightTextView];
    [[window contentView] addSubview:overlayView];
    [overlayView release];
    
    [self setFocusedInstructionIndex:0];
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

- (void)setLeftFileName:(NSString *)val {
    if (val != leftFileName) {
	[leftFileName release];
	leftFileName = [val copy];
    }
}

- (NSString *)leftFileName {
    return leftFileName;
}

- (void)setRightFileName:(NSString *)val {
    if (val != rightFileName) {
	[rightFileName release];
	rightFileName = [val copy];
    }    
}

- (NSString *)rightFileName {
    return rightFileName;
}

#pragma mark NSTableView methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    USE(tableView);
    return [editScript numberOfInstructions];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    USE(tableView);
    USE(tableColumn);
    struct HFEditInstruction_t insn = [editScript instructionAtIndex:row];
    if (insn.src.length == 0) {
	return [NSString stringWithFormat:@"Insert %@ at offset 0x%llx", HFDescribeByteCount(insn.dst.length), insn.dst.location];
    }
    else if (insn.dst.length == 0) {
	return [NSString stringWithFormat:@"Delete %@ at offset 0x%llx", HFDescribeByteCount(insn.src.length), insn.src.location];
    }
    else {
	return [NSString stringWithFormat:@"Replace %@ at offset 0x%llx with %@", HFDescribeByteCount(insn.src.length), insn.src.location, HFDescribeByteCount(insn.dst.length)];
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    USE(notification);
    NSInteger row = [diffTable selectedRow];
    [self setFocusedInstructionIndex:row];
}

@end
