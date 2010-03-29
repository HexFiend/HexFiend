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

- (void)showInstructionsFromEditScript {
    NSUInteger i, insnCount = [editScript numberOfInstructions];
    for (i=0; i < insnCount; i++) {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:i];
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

- (HFTextRepresenter *)textRepresenterFromTextView:(HFTextView *)textView {
    FOREACH(HFRepresenter *, rep, [[textView controller] representers]) {
        if ([rep isKindOfClass:[HFTextRepresenter class]]) {
            return (HFTextRepresenter *)rep;
        }
    }    
    return nil; 
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
        [overlayView setLeftRect:[overlayView convertRect:leftRect fromView:[left view]]];
        [overlayView setRightRect:[overlayView convertRect:rightRect fromView:[right view]]];
    }
}

- (void)setFocusedInstructionIndex:(NSUInteger)idx {
    focusedInstructionIndex = idx;
    struct HFEditInstruction_t insn = [editScript instructionAtIndex:focusedInstructionIndex];
    [[[leftTextView controller] byteRangeAttributeArray] removeAttribute:kHFAttributeFocused];
    [[[rightTextView controller] byteRangeAttributeArray] removeAttribute:kHFAttributeFocused];
    HFRange leftRange, rightRange;
    if (insn.isInsertion) {
        leftRange = HFRangeMake(insn.range.location, 0);
        rightRange = HFRangeMake(insn.offsetInDestinationForInsertion, insn.range.length);
        [[[rightTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeFocused range:rightRange];
    }
    else {
        leftRange = insn.range;
        rightRange = HFRangeMake(insn.range.location, 0);
        [[[leftTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeFocused range:insn.range];        
    }
    [[rightTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
    [[leftTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
    
    [self updateOverlayViewForLeftRange:leftRange rightRange:rightRange];
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

- (long long)changeInLengthBeforeByte:(unsigned long long)rightByte {
    return 0;
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
    [super dealloc];
}

- (void)synchronizeController:(HFController *)client properties:(HFControllerPropertyBits)propertyMask {
    if (propertyMask & HFControllerDisplayedLineRange) {
        HFFPRange displayedLineRange = [controller displayedLineRange];
        NSUInteger bytesPerLine = [controller bytesPerLine];
        unsigned long long lineStart = HFFPToUL(floorl(displayedLineRange.location));
        unsigned long long firstByteShown = HFProductULL(bytesPerLine, lineStart);
        unsigned long long leftByteToShow = firstByteShown + [self changeInLengthBeforeByte:firstByteShown];
        
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
    [[window contentView] addSubview:overlayView];
    [overlayView release];
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
