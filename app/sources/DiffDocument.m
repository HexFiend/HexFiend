//
//  DiffDocument.m
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "DiffDocument.h"
#import "DiffOverlayView.h"
#import "DataInspectorRepresenter.h"
#import "HFDocumentOperationView.h"
#import "DiffTextViewContainer.h"
#import "HFBinaryTemplateRepresenter.h"
#import <HexFiend/HexFiend.h>

@interface DiffDocument (ForwardDeclarations)
- (void)setFocusedInstructionIndex:(NSUInteger)index scroll:(BOOL)alsoScrollToIt;
- (void)updateScrollerValue;
- (void)scrollWithScrollEvent:(NSEvent *)event;
- (void)scrollByLines:(long double)lines;
- (void)scrollByKnobToValue:(double)newValue;
- (NSUInteger)visibleLines;
- (NSSize)minimumWindowFrameSizeForProposedSize:(NSSize)frameSize;
- (unsigned long long)concreteToAbstractExpansionBeforeConcreteLocation:(unsigned long long)concreteEndpoint onLeft:(BOOL)left;
- (unsigned long long)abstractToConcreteCollapseBeforeAbstractLocation:(unsigned long long)abstractEndpoint onLeft:(BOOL)left;
- (void)scrollToFocusedInstruction;
- (void)leftLineCountingViewChangedWidth:(NSNotification *)note;
@end

@implementation DiffDocument

- (void)showViewForRepresenter:(HFRepresenter *)rep {
    HFRepresenter *leftRep = [allRepresenters objectForKey:[rep className]];
    
    if (rep == statusBarRepresenter) {
        NSView *view = rep.view;
        [self.window setContentBorderThickness:view.frame.size.height forEdge:NSRectEdgeMinY];
        [self.window setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    }
    [[leftTextView controller] addRepresenter:leftRep];
    [[leftTextView layoutRepresenter] addRepresenter:leftRep];
    [[rightTextView controller] addRepresenter:rep];
    [[rightTextView layoutRepresenter] addRepresenter:rep];
}

- (void)hideViewForRepresenter:(HFRepresenter *)rep {
    HFASSERT(rep != nil);
    HFRepresenter *leftRep = [allRepresenters objectForKey:[rep className]];

    HFASSERT([layoutRepresenter.representers indexOfObjectIdenticalTo:rep] != NSNotFound);
    if (rep == statusBarRepresenter) {
        [self.window setContentBorderThickness:0 forEdge:NSRectEdgeMinY];
        [self.window setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    }
    [[leftTextView controller] removeRepresenter:leftRep];
    [[leftTextView layoutRepresenter] removeRepresenter:leftRep];
    [[rightTextView controller] removeRepresenter:rep];
    [[rightTextView layoutRepresenter] removeRepresenter:rep];
}

/* Returns either nil, or an array of two documents that would be compared in the "Compare (Range of) Front Documents" menu item. */
+ (NSArray *)getFrontTwoDocumentsForDiffing {
    id resultDocs[2];
    NSUInteger i = 0;
    for(NSDocument *doc in [NSApp orderedDocuments]) {
        if ([doc isKindOfClass:[DiffDocument class]]) continue;
        if (![doc isKindOfClass:[BaseDataDocument class]]) continue;
        resultDocs[i++] = doc;
        if (i >= 2) break;
    }
    if (i != 2) return nil;
    return [NSArray arrayWithObjects:resultDocs count:2];
}

+ (void)compareDocument:(BaseDataDocument *)document againstDocument:(BaseDataDocument *)otherDocument {
    [DiffDocument compareDocument:document againstDocument:otherDocument usingRange:HFRangeMake(0, 0)];
}

+ (void)compareDocument:(BaseDataDocument *)document againstDocument:(BaseDataDocument *)otherDocument usingRange:(HFRange)range {
    // convert documents to bytearrays
    HFByteArray *leftBytes = [document byteArray];
    HFByteArray *rightBytes = [otherDocument byteArray];
    [self compareByteArray:leftBytes againstByteArray:rightBytes usingRange:range leftFileName:[[document fileURL] path] rightFileName:[[otherDocument fileURL] path]];
}

+ (void)compareByteArray:(HFByteArray *)leftBytes againstByteArray:(HFByteArray *)rightBytes usingRange:(HFRange)range leftFileName:(NSString *)leftFileName rightFileName:(NSString *)rightFileName {
    // extract range if present
    if (range.length > 0) {
        leftBytes = [leftBytes subarrayWithRange:range];
        rightBytes = [rightBytes subarrayWithRange:range];
    }
    
    // launch diff window
    DiffDocument *doc = [[DiffDocument alloc] initWithLeftByteArray:leftBytes rightByteArray:rightBytes range:range];
    NSString *leftDisplayName = [[leftFileName lastPathComponent] stringByDeletingPathExtension];
    NSString *rightDisplayName = [[rightFileName lastPathComponent] stringByDeletingPathExtension];
    if ([leftDisplayName isEqualToString:rightDisplayName]) {
        leftDisplayName = [leftFileName stringByAbbreviatingWithTildeInPath];
        rightDisplayName = [rightFileName stringByAbbreviatingWithTildeInPath];
    }

    doc.leftFileName = leftDisplayName;
    doc.rightFileName = rightDisplayName;
    [[NSDocumentController sharedDocumentController] addDocument:doc];
    [doc makeWindowControllers];
    [doc showWindows];
}

+ (void)compareFrontTwoDocuments {
    [DiffDocument compareFrontTwoDocumentsUsingRange:HFRangeMake(0, 0)];
}

+ (void)compareFrontTwoDocumentsUsingRange:(HFRange)range {
    NSArray *docs = [DiffDocument getFrontTwoDocumentsForDiffing];
    if (!docs) return;
    [DiffDocument compareDocument:docs[0] againstDocument:docs[1] usingRange:range];
}

- (NSString *)displayName {
    NSString *format = @"%@ vs %@";
    if (range_.length > 0) {
        format = [NSString stringWithFormat:@"(%llu:%llu) %@", range_.location, range_.length, format];
    }
    
    return [NSString stringWithFormat:format, _leftFileName, _rightFileName];
}

- (void)showInstructionsFromEditScript {
    NSUInteger i, insnCount = [editScript numberOfInstructions];
    for (i=0; i < insnCount; i++) {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:i];
        if (insn.src.length > 0) {
            [[[leftTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeDiffInsertion range:insn.src];        	    
        }
        if (insn.dst.length > 0) {
            [[[rightTextView controller] byteRangeAttributeArray] addAttribute:kHFAttributeDiffInsertion range:insn.dst];
        }
    }
    
    /* Compute the totalAbstractLength */
    unsigned long long abstractLength = 0;
    unsigned long long leftMatchedLength = [[leftTextView controller] contentsLength], rightMatchedLength = [[rightTextView controller] contentsLength];
    for (i=0; i < insnCount; i++) {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:i];
        unsigned long long insnLength = MAX(insn.src.length, insn.dst.length);
        abstractLength = HFSum(abstractLength, insnLength);
        leftMatchedLength = HFSubtract(leftMatchedLength, insn.src.length);
        rightMatchedLength = HFSubtract(rightMatchedLength, insn.dst.length);
    }
    
    /* If the diff is correct, then the matched text must be equal in length */
    HFASSERT(leftMatchedLength == rightMatchedLength);
    abstractLength = HFSum(abstractLength, leftMatchedLength);
    
    /* Save it */
    self->totalAbstractLength = abstractLength;
    
    [[rightTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
    [[leftTextView controller] representer:nil changedProperties:HFControllerByteRangeAttributes];
    [diffTable reloadData];
    if ([editScript numberOfInstructions] > 0) {
        [self setFocusedInstructionIndex:0 scroll:YES];
    }
}

- (HFTextRepresenter *)textRepresenterFromTextView:(HFTextView *)textView {
    for(HFRepresenter *rep in [textView controller].representers) {
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
            leftRect = [left furthestRectOnEdge:CGRectMaxXEdge forByteRange:leftRange];
        }
        if (rightRange.length == 0) {
            rightRect.origin = [right locationOfCharacterAtByteIndex:rightRange.location];
            rightRect.size = NSMakeSize(0, [[rightTextView controller] lineHeight]);
        }
        else {
            rightRect = [right furthestRectOnEdge:CGRectMinXEdge forByteRange:rightRange];
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
        unsigned long long insnLength = (isLeft ? insn.src.length : insn.dst.length);
        if (byte <= insnStartByte) break;
        
        /* If the byte is midway through the instruction, then limit the length change to its offset in the instruction */
        unsigned long long maxLengthChange = ULLONG_MAX;
        if (byte - insnStartByte < insnLength) {
            maxLengthChange = byte - insnStartByte;
        }
        
        /* Compute how the length changed according to this instruction, by adding the left amount and deleting the right amount (or vice-versa if isLeft is NO) */
        unsigned long long srcLength = MIN(maxLengthChange, insn.src.length), dstLength = MIN(maxLengthChange, insn.dst.length);
        long long lengthChange = (long long)(srcLength - dstLength);
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
		
        [self updateOverlayViewForLeftRange:leftRange rightRange:rightRange];
        [overlayView setHidden:NO];
    }    
}

- (void)synchronizeTableHiddenScrollers {
    /* Work around an AppKit bug that the scrollers don't update their value if they're hidden, but their value becomes very relevant if we scroll via the scroll wheel! */
    NSScrollView *scrollView = [diffTable enclosingScrollView];
    NSClipView *clipView = [scrollView contentView];
    NSRect clipViewBounds = [clipView bounds];
    NSRect documentRect = [clipView documentRect];
    double scrollVal;
    if (NSHeight(clipViewBounds) >= NSHeight(documentRect)) {
        scrollVal = 0;
    } else {
        double scrollHeight = NSHeight(documentRect) - NSHeight(clipViewBounds);
        scrollVal = (NSMinY(clipViewBounds) - NSMinY(documentRect)) / scrollHeight;
    }
    [[scrollView verticalScroller] setDoubleValue:scrollVal];
}

- (void)updateTableViewSelection {
    if (focusedInstructionIndex >= [editScript numberOfInstructions]) {
        [diffTable selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    }
    else {
        [diffTable selectRowIndexes:[NSIndexSet indexSetWithIndex:focusedInstructionIndex] byExtendingSelection:NO];
        [diffTable scrollRowToVisible:focusedInstructionIndex];
        [self synchronizeTableHiddenScrollers];
    }
}

- (void)setFocusedInstructionIndex:(NSUInteger)idx scroll:(BOOL)scroll {
    focusedInstructionIndex = idx;
    if (scroll) [self scrollToFocusedInstruction];
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
        [self setFocusedInstructionIndex:focusedInstructionIndex + direction scroll:YES];
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
    NSUInteger prohibitedFlags = (NSEventModifierFlagShift | NSEventModifierFlagControl | NSEventModifierFlagOption | NSEventModifierFlagCommand);
    if ([event type] == NSEventTypeKeyDown && ! (prohibitedFlags & [event modifierFlags])) {
        if (frInLeftView || frInRightView) {
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
    } else if ([event type] == NSEventTypeScrollWheel) {
        
        /* Redirect scroll wheel events to ourselves, except for those in the table (or, rather, its scroll view). If this scroll event comes very soon after the last one, then we consider it to be a momentum scroll event and direct it at the last target. */
        NSPoint location = [event locationInWindow];
        NSScrollView *scrollView = [diffTable enclosingScrollView];
        CFAbsoluteTime timeOfThisEvent = [event timestamp];
        CFTimeInterval timeBetweenScrollEvents = timeOfThisEvent - timeOfLastScrollEvent;
        if (timeBetweenScrollEvents >= 0 && timeBetweenScrollEvents <= .05) {
            /* Probably a momentum scroll event, so do whatever we did last time */
            handled = handledLastScrollEvent;
        } else {
            /* Don't handle it if it's in our scroll view */
            if (NSMouseInRect(location, [scrollView convertRect:[scrollView bounds] toView:nil], NO /* flipped */)) {
                handled = NO;
            } else {
                NSView *layoutView = [layoutRepresenter view];
                if (layoutView && NSMouseInRect(location, [layoutView convertRect:[layoutView bounds] toView:nil], NO)) {
                    handled = NO;
                } else {
                    handled = YES;
                }
            }
        }
        
        /* Record info about our events */
        handledLastScrollEvent = handled;
        timeOfLastScrollEvent = timeOfThisEvent;
        
        if (handled) {
            [self scrollWithScrollEvent:event];
        }
    }
    return handled;
}

- (instancetype)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right {
    if ((self = [super init])) {
        leftBytes = [left mutableCopy];
        rightBytes = [right mutableCopy];
        //[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronizeControllers:) name:HFControllerDidChangePropertiesNotification object:controller];
        
        /* Initially, the scrolling is just synchronized */
        totalAbstractLength = HFMaxULL([leftBytes length], [rightBytes length]);
        
        /* We haven't receieved a scroll event */
        timeOfLastScrollEvent = -DBL_MAX;
        
        leftColumnRepresenter = [[HFColumnRepresenter alloc] init];
        leftLineCountingRepresenter = [[HFLineCountingRepresenter alloc] init];
        leftBinaryRepresenter = [[HFBinaryTextRepresenter alloc] init];
        leftHexRepresenter = [[HFHexTextRepresenter alloc] init];
        leftAsciiRepresenter = [[HFStringEncodingTextRepresenter alloc] init];
        leftScrollRepresenter = [[HFVerticalScrollerRepresenter alloc] init];
        leftStatusBarRepresenter = [[HFStatusBarRepresenter alloc] init];
        leftDataInspectorRepresenter = [[DataInspectorRepresenter alloc] init];
        leftTextDividerRepresenter = [[HFTextDividerRepresenter alloc] init];
        leftBinaryTemplateRepresenter = [[HFBinaryTemplateRepresenter alloc] init];
        leftBinaryTemplateRepresenter.viewWidth = [NSUserDefaults.standardUserDefaults doubleForKey:@"BinaryTemplateRepresenterWidth"];
        
        allRepresenters = [[NSMutableDictionary<NSString*, HFRepresenter*> alloc] init];
        [allRepresenters setObject:leftColumnRepresenter forKey:[leftColumnRepresenter className]];
        [allRepresenters setObject:leftLineCountingRepresenter forKey:[leftLineCountingRepresenter className]];
        [allRepresenters setObject:leftBinaryRepresenter forKey:[leftBinaryRepresenter className]];
        [allRepresenters setObject:leftHexRepresenter forKey:[leftHexRepresenter className]];
        [allRepresenters setObject:leftAsciiRepresenter forKey:[leftAsciiRepresenter className]];
        [allRepresenters setObject:leftScrollRepresenter forKey:[leftScrollRepresenter className]];
        [allRepresenters setObject:leftStatusBarRepresenter forKey:[leftStatusBarRepresenter className]];
        [allRepresenters setObject:leftDataInspectorRepresenter forKey:[leftDataInspectorRepresenter className]];
        [allRepresenters setObject:leftTextDividerRepresenter forKey:[leftTextDividerRepresenter className]];
        [allRepresenters setObject:leftBinaryTemplateRepresenter forKey:[leftBinaryTemplateRepresenter className]];
        
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver:self selector:@selector(lineCountingViewChangedWidth:) name:HFLineCountingRepresenterMinimumViewWidthChanged object:leftLineCountingRepresenter];
        [center addObserver:self selector:@selector(columnRepresenterViewHeightChanged:) name:HFColumnRepresenterViewHeightChanged object:leftColumnRepresenter];
        [center addObserver:self selector:@selector(lineCountingRepCycledLineNumberFormat:) name:HFLineCountingRepresenterCycledLineNumberFormat object:leftLineCountingRepresenter];
        [center addObserver:self selector:@selector(dataInspectorChangedRowCount:) name:DataInspectorDidChangeRowCount object:leftDataInspectorRepresenter];
        [center addObserver:self selector:@selector(dataInspectorDeletedAllRows:) name:DataInspectorDidDeleteAllRows object:leftDataInspectorRepresenter];
        
        NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
        
        lineCountingRepresenter.lineNumberFormat = (HFLineNumberFormat)[defs integerForKey:@"LineNumberFormat"];
        [columnRepresenter setLineCountingWidth:lineCountingRepresenter.preferredWidth];
    }
    return self;
}

- (instancetype)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right range:(HFRange)range {
    range_ = range;
    return [self initWithLeftByteArray:left rightByteArray:right];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFControllerDidChangePropertiesNotification object:[rightTextView controller]];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFControllerDidChangePropertiesNotification object:[leftTextView controller]];
    [diffComputationView removeObserver:self forKeyPath:@"progress"];
}

/* Diff documents never show a divider */
- (BOOL)dividerRepresenterShouldBeShown {
    return NO;
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


- (void)scrollerDidChangeValue:(NSScroller *)control {
    USE(control);
    HFASSERT(control == scroller);
    switch ([scroller hitPart]) {
        case NSScrollerDecrementPage: [self scrollByLines: -(long long)[self visibleLines]]; break;
        case NSScrollerIncrementPage: [self scrollByLines: (long long)[self visibleLines]]; break;
        case NSScrollerKnob: [self scrollByKnobToValue:[scroller doubleValue]]; break;
        default: break;
    }
}

/* Return the property bits that our overlay view cares about */
- (HFControllerPropertyBits)propertiesAffectingOverlayView {
    return HFControllerContentLength | HFControllerDisplayedLineRange | HFControllerBytesPerLine | HFControllerBytesPerColumn;
}

/* Returns the index of the instruction that either contains the given index, or the index of the first instruction after it. left indicates that we're talking about the instruction source; right indicates the destination. Returns NSNotFound if no instruction contains or is after the given index. */
- (NSUInteger)indexOfInstructionContainingOrAfterIndex:(unsigned long long)idx onLeft:(BOOL)left {
    const NSUInteger insnCount = [editScript numberOfInstructions];
    NSUInteger low = 0, high = insnCount;
    while (low < high) {
        NSUInteger mid = low + (high - low)/2;
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:mid];
        HFRange range = (left ? insn.src : insn.dst);
        
        if (HFLocationInRange(idx, range)) {
            /* If it's in the range we're definitely done */
            low = high = mid;
        } else if (idx > range.location) {
            /* Must have idx >= HFMaxRange(range), so pick a greater range */
            low = mid + 1;
        } else {
            /* Must have idx < range.location, so this range may work */
            high = mid;
        }

    }
    HFASSERT(low <= insnCount);
    if (low == insnCount) return NSNotFound;
    else return low;
}

- (NSRange)visibleInstructionRangeInController:(HFController *)targetController {
    /* TODO: this should be a binary search */
    NSUInteger i, insnCount = [editScript numberOfInstructions];
    HFFPRange displayedLineRange = [targetController displayedLineRange];
    NSUInteger bpl = [targetController bytesPerLine];
    const unsigned long long firstVisibleByte = bpl * HFFPToUL(floorl(displayedLineRange.location));
    const unsigned long long lastVisibleByte = bpl * HFFPToUL(ceill(displayedLineRange.location + displayedLineRange.length));
    NSUInteger firstVisibleInstruction = NSNotFound, lastVisibleInstruction = NSNotFound;
    for (i=0; i < insnCount; i++) {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:i];
        
        HFRange rightRange  = insn.dst;
        
        if (firstVisibleInstruction == NSNotFound) {
            if (rightRange.location >= firstVisibleByte) {
                firstVisibleInstruction = i;
                lastVisibleInstruction = i;
            }
        }
        
        if (firstVisibleInstruction != NSNotFound) {
            if (rightRange.location >= lastVisibleByte) break;
            lastVisibleInstruction = i;
        }
    }
    return NSMakeRange(firstVisibleInstruction, lastVisibleInstruction - firstVisibleInstruction);
}

- (unsigned long long)lastCorrespondingByteBeforeByte:(unsigned long long)targetIndex onLeft:(BOOL)leftToRight {
    /* Given a byte in one of the controllers (left or right according to the parameter), return the corresponding byte in the other controller.  If the byte falls into an inserted range, returns the last byte before that range. */
    unsigned long long lastToIndex = 0, lastFromIndex = 0;
    NSUInteger i, max = [editScript numberOfInstructions];
    for (i=0; i < max; i++) {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:i];
        HFRange fromRange = (leftToRight ? insn.src : insn.dst);
        HFRange toRange = (leftToRight ? insn.dst : insn.src);
        
        /* We expect our instructions to always be increasing. */
        HFASSERT(fromRange.location >= lastFromIndex);
        
        if (fromRange.location > targetIndex) {
            /* This instruction is past the index we care about, so we're done. Add in the amount of matching space. */
            unsigned long long matchingSpace = HFSubtract(targetIndex, lastFromIndex);
            lastToIndex = HFSum(lastToIndex, matchingSpace);
            lastFromIndex = targetIndex;
            break;
        } 
        
        /* We know that fromRange.location <= targetIndex.  Space up to this instruction is matching space.  Advance to that point. */
        unsigned long long matchingSpace = HFSubtract(fromRange.location, lastFromIndex);
        lastToIndex = HFSum(lastToIndex, matchingSpace);
        lastFromIndex = fromRange.location;
        
        if (HFLocationInRange(targetIndex, fromRange)) {
            /* The index we care about is midway through the instruction, so we're done.  Consider bytes that replace each other to correspond. If From.length is larger than To.length, we'll consider the correspondence to be the last byte of To. */
            unsigned long long distanceIntoFrom = HFSubtract(targetIndex, fromRange.location);
            unsigned long long distanceIntoTo = MIN(distanceIntoFrom, toRange.length);
            lastToIndex = HFSum(lastToIndex, distanceIntoTo);
            lastFromIndex = targetIndex;
            break;
        }
        
        /* If we're here, it means that targetIndex is still after this instruction, so add the differences in the instruction lengths. */
        HFASSERT(HFMaxRange(fromRange) <= targetIndex);
        lastFromIndex = HFSum(lastFromIndex, fromRange.length);
        lastToIndex = HFSum(lastToIndex, toRange.length);
    }
    
    /* Any leftover space is matching */
    unsigned long long endMatch = HFSubtract(targetIndex, lastFromIndex);
    //lastFromIndex = HFSum(lastFromIndex, endMatch);
    lastToIndex = HFSum(lastToIndex, endMatch);
    
    /* Done */
    return lastToIndex;
}

- (void)propagateSelectedRangesFromLeftToRight:(BOOL)leftToRight {
    HFController *srcController = leftToRight ? [leftTextView controller] : [rightTextView controller];
    HFController *dstController = leftToRight ? [rightTextView controller] : [leftTextView controller];
    NSArray *selectedRanges = [srcController selectedContentsRanges];
    NSUInteger count = [selectedRanges count];
    NSMutableArray *correspondingRanges = [[NSMutableArray alloc] initWithCapacity:count];
    BOOL hasZeroLengthRange = NO, hasNonzeroLengthRange = NO;
    for(HFRangeWrapper *rangeWrapper in selectedRanges) {
        HFRange range = [rangeWrapper HFRange];
        unsigned long long correspondingStartByte = [self lastCorrespondingByteBeforeByte:range.location onLeft:leftToRight];
        unsigned long long correspondingEndByte = [self lastCorrespondingByteBeforeByte:HFMaxRange(range) onLeft:leftToRight];
        HFRange correspondingRange = HFRangeMake(correspondingStartByte, HFSubtract(correspondingEndByte, correspondingStartByte));
        [correspondingRanges addObject:[HFRangeWrapper withRange:correspondingRange]];
        hasZeroLengthRange = hasZeroLengthRange || (correspondingRange.length == 0);
        hasNonzeroLengthRange = hasNonzeroLengthRange || (correspondingRange.length > 0);
    }
    
    /* Clean up the ranges to ensure that if we have a zero length range, it's all we have. */
    if (hasZeroLengthRange && hasNonzeroLengthRange) {
        /* Remove all zero length ranges */
        NSUInteger i = count;
        while (i--) {
            HFRange testRange = [correspondingRanges[i] HFRange];
            if (testRange.length == 0) [correspondingRanges removeObjectAtIndex:i];
        }
    } else if (hasZeroLengthRange && count > 1) {
        /* We have only zero length ranges.  Keep only the first one. */
        [correspondingRanges removeObjectsInRange:NSMakeRange(1, count - 1)];
    } else {
        /* We have only non-zero length ranges (or none at all).  Keep it that way. */
    }
    
    /* Now apply them */
    if ([correspondingRanges count] > 0) [dstController setSelectedContentsRanges:correspondingRanges];
}

- (void)synchronizeControllers:(NSNotification *)note {
    /* Set and check synchronizingControllers to avoid recursive invocations */
    if (synchronizingControllers) return;
    synchronizingControllers = YES;
    NSNumber *propertyNumber = [note userInfo][HFControllerChangedPropertiesKey];
    HFController *changedController = [note object];
    HFASSERT(changedController == [leftTextView controller] || changedController == [rightTextView controller]);
    BOOL controllerIsLeft = (changedController == [leftTextView controller]);
    HFControllerPropertyBits propertyMask = [propertyNumber unsignedIntegerValue];
    
    /* Update the overlay view to react to things like the bytes per line changing. */
    if (propertyMask & [self propertiesAffectingOverlayView]) {
        [self updateInstructionOverlayView];
    }
    
    /* Synchronize the selection */
    if (propertyMask & HFControllerSelectedRanges) {
        [self propagateSelectedRangesFromLeftToRight:controllerIsLeft];
        
        /* If the user clicks on a range containing a diff, jump to that in the table */
        NSArray *ranges = [changedController selectedContentsRanges];
        if ([ranges count] == 1) {
            HFRange selectedRange = [ranges[0] HFRange];
            if (selectedRange.length == 0) {
                NSUInteger insnIndex = [self indexOfInstructionContainingOrAfterIndex:selectedRange.location onLeft:controllerIsLeft];
                if (insnIndex != NSNotFound) {
                    struct HFEditInstruction_t insn = [editScript instructionAtIndex:insnIndex];
                    if (HFLocationInRange(selectedRange.location, controllerIsLeft ? insn.src : insn.dst)) {
                        [self setFocusedInstructionIndex:insnIndex scroll:NO];
                    }
                }
            }
        }
    }
    
#if 0
    if (changedController != [leftTextView controller]) {
        [self synchronizeController:[leftTextView controller] properties:propertyMask];
    }
    if (changedController != [rightTextView controller]) {
        [self synchronizeController:[rightTextView controller] properties:propertyMask];
    }
#endif
#if 0
    if (propertyMask & HFControllerDisplayedLineRange) {
        /* Scroll our table view to show the instruction.  If our focused instruction is not visible, scroll to it; otherwise scroll to the first visible one. */
        NSRange visibleInstructions = [self visibleInstructionRangeInController:changedController];
        
        NSLog(@"visibleInstructions: %@", NSStringFromRange(visibleInstructions));
        
        //	NSLog(@"visible instructions: %@", NSStringFromRange(visibleInstructions));
        if (visibleInstructions.location != NSNotFound) {
            [diffTable scrollRowToVisible:NSMaxRange(visibleInstructions)];
            [diffTable scrollRowToVisible:visibleInstructions.location];
        }
        
    }
#endif

    synchronizingControllers = NO;
}

- (NSArray *)runningOperationViews {
    NSArray *result = [super runningOperationViews];
    if ([diffComputationView operationIsRunning]) {
        result = [result arrayByAddingObject:diffComputationView];
    }
    return result;
}

- (void)updateOverlayViewForChangedLeftScroller:(NSNotification *)note {
    NSNumber *propertyNumber = [note userInfo][HFControllerChangedPropertiesKey];
    HFControllerPropertyBits propertyMask = [propertyNumber unsignedIntegerValue];
    if (propertyMask & [self propertiesAffectingOverlayView]) {
        [self updateInstructionOverlayView];
    }
}

- (void)fixupTextView:(HFTextView *)textView {
    [textView setBordered:NO];
    
    /* Install our undo manager */
    [[textView controller] setUndoManager:[self undoManager]]; 
    
    /* Set the bytes per column */
    [[textView controller] setBytesPerColumn:[controller bytesPerColumn]];
    
    /* It maximizes BPL.  We enforce the same BPL between the text views by adjusting their widths. */
    [[textView layoutRepresenter] setMaximizesBytesPerLine:YES];
    
    /* Remove the representers we don't want */
    for(HFRepresenter *rep in [textView layoutRepresenter].representers) {
        [[textView layoutRepresenter] removeRepresenter:rep];
        [[textView controller] removeRepresenter:rep];
    }
    
    /* It's not editable */
    [[textView controller] setEditable:NO];
}

- (void)close {
    /* Make sure we cancel if we close */
    [diffComputationView cancelViewOperation:self];
    [super close];
}

- (void)kickOffComputeDiff {
    HFASSERT(! [diffComputationView operationIsRunning]);
    
    [leftBytes incrementChangeLockCounter];
    [rightBytes incrementChangeLockCounter];
    NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;
    BOOL onlyReplace = [userDefaults boolForKey:@"OnlyReplaceInComparison"];
    BOOL skipOneByteMatches = [userDefaults boolForKey:@"SkipOneByteMatches"];
    [diffComputationView startOperation:^id(HFProgressTracker *tracker) {
        return [[HFByteArrayEditScript alloc] initWithDifferenceFromSource:self->leftBytes
                                                             toDestination:self->rightBytes
                                                               onlyReplace:onlyReplace
                                                        skipOneByteMatches:skipOneByteMatches
                                                          trackingProgress:tracker];
    } completionHandler:^(id script) {
        [self->leftBytes decrementChangeLockCounter];
        [self->rightBytes decrementChangeLockCounter];
        
        /* script may be nil if we cancelled */
        if (! script) {
            [self close];
        } else {
            
            /* Hide the script banner */
            if (self->operationView != nil && self->operationView == self->diffComputationView) [self hideBannerFirstThenDo:NULL];
            
            self->editScript = script;
            [self showInstructionsFromEditScript];	
        }
    }];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
    [super windowControllerDidLoadNib:windowController];
    NSWindow *window = [self window];
    
    /* Replace the right text view's controller and layout representer with our own */
    [rightTextView setController:controller];
    [rightTextView setLayoutRepresenter:layoutRepresenter];
    
    /* Fix up our two text views */
    [self fixupTextView:leftTextView];
    [self fixupTextView:rightTextView];
    [self showViewForRepresenter:lineCountingRepresenter];
    [self showViewForRepresenter:hexRepresenter];
    [self showViewForRepresenter:asciiRepresenter];
    [self showViewForRepresenter:textDividerRepresenter];

    /* Install the two byte arrays */
    [[leftTextView controller] setByteArray:leftBytes];
    [[rightTextView controller] setByteArray:rightBytes];
    
    /* Get told when our left one scrolls */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateOverlayViewForChangedLeftScroller:) name:HFControllerDidChangePropertiesNotification object:[leftTextView controller]];
    
    /* Get notified when our controllers change */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronizeControllers:) name:HFControllerDidChangePropertiesNotification object:[leftTextView controller]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(synchronizeControllers:) name:HFControllerDidChangePropertiesNotification object:[rightTextView controller]];
    
    /* Fix up the scroller.  It wants to move northwards because of the resize corner.  Update its size. */
    [self updateScrollerValue];
    NSView *superview = [scroller superview];
    NSRect scrollerFrame = [scroller frame];
    scrollerFrame.size.height = NSMaxY([superview bounds]) - scrollerFrame.origin.y;
    [scroller setFrame:scrollerFrame];

    /* Create the diff computation view */
    if (! diffComputationView) {
        diffComputationView = [self newOperationViewForNibName:@"DiffComputationBanner" displayName:@"Diffing"];
    }
    [self prepareBannerWithView:diffComputationView withTargetFirstResponder:nil];
    [self kickOffComputeDiff];
    
    [self synchronizeController:[leftTextView controller] properties:(HFControllerPropertyBits)-1];
    [self synchronizeController:[rightTextView controller] properties:(HFControllerPropertyBits)-1];
    
    /* Create and install the overlay view */
    overlayView = [[DiffOverlayView alloc] initWithFrame:[[window contentView] bounds]];
    [overlayView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [overlayView setLeftView:leftTextView];
    [overlayView setRightView:rightTextView];
    [[window contentView] addSubview:overlayView];
    
    /* Update our window size so it's the right size for our data */
    NSRect windowFrame = [window frame];
    const NSUInteger bytesPerLine = [(NSNumber *)[NSUserDefaults.standardUserDefaults objectForKey:@"BytesPerLine"] unsignedIntegerValue];
    windowFrame.size.width = [textViewContainer minimumViewWidthForBytesPerLine:bytesPerLine];
    [window setFrame:windowFrame display:YES];
    
    /* Start at instruction zero */
    [self setFocusedInstructionIndex:0 scroll:YES];
}

- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"DiffDocument";
}

- (void)setFont:(NSFont *)font registeringUndo:(BOOL)undo {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[self window] disableFlushWindow];
#pragma clang diagnostic pop
    [super setFont:font registeringUndo:undo];
    [[leftTextView controller] setFont:font];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    [[self window] enableFlushWindow];
#pragma clang diagnostic pop
}

#pragma mark NSTableView methods

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    USE(tableView);
    NSInteger result = [editScript numberOfInstructions];
    if (result == 0 && editScript != nil) {
        result = 1; //will say "Documents are identical"
    }
    return result;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    USE(tableView);
    USE(tableColumn);
    if ([editScript numberOfInstructions] == 0) {
        return @"Documents are identical";
    } else {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:row];
        char offsetBuffer[64];
        HFLineNumberFormat format = [lineCountingRepresenter lineNumberFormat];
        switch (format) {
            default:
            case HFLineNumberFormatHexadecimal:
                snprintf(offsetBuffer, sizeof offsetBuffer, "0x%llx", insn.dst.location);
                break;
            case HFLineNumberFormatDecimal:
                snprintf(offsetBuffer, sizeof offsetBuffer, "%llx", insn.dst.location);
                break;
        }
        
        if (insn.src.length == 0) {
            return [NSString stringWithFormat:@"%ld: Insert %@ at offset 0x%llx", (long)row + 1, HFDescribeByteCount(insn.dst.length), insn.dst.location];
        }
        else if (insn.dst.length == 0) {
            return [NSString stringWithFormat:@"%ld: Delete %@ at offset 0x%llx", (long)row + 1, HFDescribeByteCount(insn.src.length), insn.src.location];
        }
        else {
            return [NSString stringWithFormat:@"%ld: Replace %@ at offset 0x%llx with %@", (long)row + 1, HFDescribeByteCount(insn.src.length), insn.src.location, HFDescribeByteCount(insn.dst.length)];
        }
    }
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    USE(notification);
    NSInteger row = [diffTable selectedRow];
    
    /* If we are synchronizing controllers, we'll take care of scrolling things. If we are not synchronizing controllers, scroll to the focused instruction. */
    [self setFocusedInstructionIndex:row scroll: ! synchronizingControllers];
}

@end

/* This code looks a lot like the code in HFController.m.  Can it be factored so it's shared? */
@implementation DiffDocument (ScrollHandling)

static const CGFloat kScrollMultiplier = (CGFloat)1.5;

- (unsigned long long)totalLineCount {
    NSUInteger bytesPerLine = [[leftTextView controller] bytesPerLine];
    return HFDivideULLRoundingUp(HFRoundUpToNextMultipleSaturate(totalAbstractLength, bytesPerLine), bytesPerLine);
}

- (HFFPRange)displayedLineRange {
    HFController *controller1 = [leftTextView controller], *controller2 = [rightTextView controller];
    HFFPRange lineRange;
    lineRange.location = currentScrollPosition;
    lineRange.length = MAX([controller1 displayedLineRange].length, [controller2 displayedLineRange].length);
    return lineRange;
}

- (unsigned long long)concreteToAbstractExpansionBeforeConcreteLocation:(unsigned long long)concreteEndpoint onLeft:(BOOL)left {
    NSUInteger i, max = [editScript numberOfInstructions];
    unsigned long long concreteLocation = 0, abstractLocation = 0;
    unsigned long long remainingConcreteDistance = concreteEndpoint;
    for (i=0; i < max; i++) {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:i];
        
        HFRange leftRange = insn.src, rightRange = insn.dst;
        
        /* Figure out the location of this instruction */
        unsigned long long insnLocation = (left ? leftRange.location : rightRange.location);
        
        /* This is our new concrete location */
        unsigned long long locationIncrease = HFSubtract(insnLocation, concreteLocation);
        /* But don't let it increase past the abstract location */
        locationIncrease = MIN(locationIncrease, remainingConcreteDistance);
        
        /* Add it */
        concreteLocation = HFSum(concreteLocation, locationIncrease);
        abstractLocation = HFSum(abstractLocation, locationIncrease);
        remainingConcreteDistance = HFSubtract(remainingConcreteDistance, locationIncrease);
        
        /* Maybe we're done */
        HFASSERT(concreteLocation <= concreteEndpoint);
        if (concreteLocation == concreteEndpoint) break;
        
        /* Figure out how many bytes are in the "from" and "to" part of this instruction */
        const unsigned long long fromLength = (left ? insn.src.length : insn.dst.length);
        const unsigned long long toLength = (left ? insn.dst.length : insn.src.length);
        
        unsigned long long abstractExpansion = MAX(fromLength, toLength);
        unsigned long long concreteExpansion = fromLength;
        
        /* But don't let it expand more than remainingAbstractDistance */
        abstractExpansion = MIN(abstractExpansion, remainingConcreteDistance);
        concreteExpansion = MIN(concreteExpansion, remainingConcreteDistance);
        
        /* Add them */
        concreteLocation = HFSum(concreteLocation, concreteExpansion);
        abstractLocation = HFSum(abstractLocation, abstractExpansion);
        remainingConcreteDistance = HFSubtract(remainingConcreteDistance, concreteExpansion);
        
        /* Maybe we're done */
        HFASSERT(concreteLocation <= concreteEndpoint);
        if (concreteLocation == concreteEndpoint) break;
    }
    
    /* There may be more remaining after the last instruction */
    abstractLocation = HFSum(abstractLocation, remainingConcreteDistance);
    concreteLocation = HFSum(concreteLocation, remainingConcreteDistance);
    
    return HFSubtract(abstractLocation, concreteLocation);    
}

- (unsigned long long)abstractToConcreteCollapseBeforeAbstractLocation:(unsigned long long)abstractEndpoint onLeft:(BOOL)left {
    NSUInteger i, max = [editScript numberOfInstructions];
    unsigned long long concreteLocation = 0, abstractLocation = 0;
    unsigned long long remainingAbstractDistance = abstractEndpoint;
    for (i=0; i < max; i++) {
        struct HFEditInstruction_t insn = [editScript instructionAtIndex:i];
        
        HFRange leftRange = insn.src, rightRange = insn.dst;
		
        /* Figure out the location of this instruction */
        unsigned long long insnLocation = (left ? leftRange.location : rightRange.location);
        
        /* This is our new concrete location */
        unsigned long long locationIncrease = HFSubtract(insnLocation, concreteLocation);
        /* But don't let it increase past the abstract location */
        locationIncrease = MIN(locationIncrease, remainingAbstractDistance);
        
        /* Add it */
        concreteLocation = HFSum(concreteLocation, locationIncrease);
        abstractLocation = HFSum(abstractLocation, locationIncrease);
        remainingAbstractDistance = HFSubtract(remainingAbstractDistance, locationIncrease);
        
        /* Maybe we're done */
        HFASSERT(abstractLocation <= abstractEndpoint);
        if (abstractLocation == abstractEndpoint) break;
        
        /* Figure out how many bytes are in the "from" and "to" part of this instruction */
        const unsigned long long fromLength = (left ? insn.src.length : insn.dst.length);
        const unsigned long long toLength = (left ? insn.dst.length : insn.src.length);
        
        unsigned long long abstractExpansion = MAX(fromLength, toLength);
        unsigned long long concreteExpansion = fromLength;
        
        /* But don't let it expand more than remainingAbstractDistance */
        abstractExpansion = MIN(abstractExpansion, remainingAbstractDistance);
        concreteExpansion = MIN(concreteExpansion, remainingAbstractDistance);
        
        /* Add them */
        concreteLocation = HFSum(concreteLocation, concreteExpansion);
        abstractLocation = HFSum(abstractLocation, abstractExpansion);
        remainingAbstractDistance = HFSubtract(remainingAbstractDistance, abstractExpansion);
        
        /* Maybe we're done */
        HFASSERT(abstractLocation <= abstractEndpoint);
        if (abstractLocation == abstractEndpoint) break;
    }
    
    /* There may be more remaining after the last instruction */
    abstractLocation = HFSum(abstractLocation, remainingAbstractDistance);
    concreteLocation = HFSum(concreteLocation, remainingAbstractDistance);
    
    return HFSubtract(abstractLocation, concreteLocation);
}

- (HFFPRange)concreteLineRangeForController:(HFController *)testController forAbstractLineRange:(HFFPRange)abstractRange {
    /* Compute the line range for the controller corresponding to the given range in our abstract scroll space. */
    HFASSERT(testController == [leftTextView controller] || testController == [rightTextView controller]);
    BOOL left = (testController == [leftTextView controller]);
    const NSUInteger bytesPerLine = [testController bytesPerLine];
    
    /* Now figure out the change in line length before the start line */
    unsigned long long firstDisplayedAbstractCharacterIndex = HFProductULL(HFFPToUL(floorl(abstractRange.location)), bytesPerLine);
    unsigned long long collapse = [self abstractToConcreteCollapseBeforeAbstractLocation:firstDisplayedAbstractCharacterIndex onLeft:left];
    HFASSERT(collapse <= firstDisplayedAbstractCharacterIndex);
    
    /* We collapse by an integer number of lines (rounded down) */
    HFASSERT(bytesPerLine > 0);
    collapse -= collapse % bytesPerLine;
    
    /* Now get the concrete character index */
    unsigned long long firstDisplayedConcreteCharacterIndex = firstDisplayedAbstractCharacterIndex - collapse;
    
    /* Don't let it go past the max */
    firstDisplayedConcreteCharacterIndex = MIN(firstDisplayedConcreteCharacterIndex, [testController contentsLength]);
    
    /* Figure out the new start line */
    long double startLine = firstDisplayedConcreteCharacterIndex / bytesPerLine;
    
    /* We, uh, can't have more lines than we can have. */
    const long double maxLineCount = HFULToFP([testController totalLineCount]);
    long double lineCount = MIN(abstractRange.length, maxLineCount);
    long double maxStartLine = MAX(0, maxLineCount - abstractRange.length);
    startLine = MIN(startLine, maxStartLine);
    
    /* Can't be negative */
    HFASSERT(startLine >= 0);
    HFASSERT(lineCount >= 0);
    
    /* Done */
    HFFPRange clippedRange = (HFFPRange){startLine, lineCount};
    return clippedRange;
}

- (void)setDisplayedLineRange:(HFFPRange)lineRange {
    currentScrollPosition = lineRange.location;
    [self updateScrollerValue];
    
    [[leftTextView controller] setDisplayedLineRange:[self concreteLineRangeForController:[leftTextView controller] forAbstractLineRange:lineRange]];
    [[rightTextView controller] setDisplayedLineRange:[self concreteLineRangeForController:[rightTextView controller] forAbstractLineRange:lineRange]];
}

- (void)updateScrollerValue {
    /* Most of this code is copied from HFVerticalScrollerRepresenter.m. */
    CGFloat value, proportion;
    BOOL enable = YES;
    unsigned long long length = totalAbstractLength;
    HFFPRange lineRange = [self displayedLineRange];
    
    HFASSERT(lineRange.location >= 0 && lineRange.length >= 0);
    if (length == 0) {
        value = 0;
        proportion = 1;
        enable = NO;
    }
    else {
        long double availableLines = HFULToFP([self totalLineCount]);
        long double consumedLines = MAX(1., lineRange.length);
        proportion = ld2f(lineRange.length / availableLines);
        
        long double maxScroll = availableLines - consumedLines;
        HFASSERT(maxScroll >= lineRange.location);
        if (maxScroll == 0.) {
            enable = NO;
            value = 0;
        }
        else {
            value = ld2f(lineRange.location / maxScroll);
        }
    }
    [scroller setDoubleValue:value];
    [scroller setKnobProportion:proportion];
    [scroller setEnabled:enable];
}

- (void)scrollByLines:(long double)lines {
    HFFPRange lineRange = [self displayedLineRange];
    HFASSERT(HFULToFP([self totalLineCount]) >= lineRange.length);
    long double maxScroll = HFULToFP([self totalLineCount]) - lineRange.length;
    long double newLineRangeLocation = lineRange.location + lines;

    // ensure it's in range
    newLineRangeLocation = fminl(newLineRangeLocation, maxScroll);
    newLineRangeLocation = fmaxl(newLineRangeLocation, 0);
    
    // Note: This comparison is often false, e.g. if we scroll to the end or beginning, especially with momentum scrolling.  It's a worthwhile optimization.
    if (newLineRangeLocation != lineRange.location) {
        lineRange.location = newLineRangeLocation;
        [self setDisplayedLineRange:lineRange];
    }
}

- (void)scrollWithScrollEvent:(NSEvent *)scrollEvent {
    HFASSERT(scrollEvent != nil);
    HFASSERT([scrollEvent type] == NSEventTypeScrollWheel);
    long double scrollY = 0;
    
    /* Prefer precise deltas */
    if ([scrollEvent hasPreciseScrollingDeltas]) {
        /* In this case, we're going to scroll by a certain number of points */
        scrollY = -[scrollEvent scrollingDeltaY] / [[leftTextView controller] lineHeight];
    } else {
        scrollY = -kScrollMultiplier * [scrollEvent scrollingDeltaY];
    }
    
    [self scrollByLines:scrollY];
}

- (void)scrollByKnobToValue:(double)newValue {
    HFASSERT(newValue >= 0. && newValue <= 1.);
    unsigned long long contentsLength = totalAbstractLength;
    NSUInteger bytesPerLine = [[leftTextView controller] bytesPerLine];
    HFASSERT(bytesPerLine > 0);
    unsigned long long totalLineCount = HFDivideULLRoundingUp(contentsLength, bytesPerLine);
    HFFPRange currentLineRange = [self displayedLineRange];
    HFASSERT(currentLineRange.length < HFULToFP(totalLineCount));
    long double maxScroll = totalLineCount - currentLineRange.length;
    long double newScroll = maxScroll * (long double)newValue;
    [self setDisplayedLineRange:(HFFPRange){newScroll, currentLineRange.length}];
}

- (HFFPRange)abstractLineRangeForConcreteContentsRange:(HFRange)range onLeft:(BOOL)left {
    HFTextView *textView = left ? leftTextView : rightTextView;
    NSUInteger bytesPerLine = [[textView controller] bytesPerLine];
    unsigned long long concreteRangeStart = range.location, concreteRangeEnd = HFMaxRange(range), abstractRangeStart, abstractRangeEnd;
    abstractRangeStart = HFSum(range.location, [self concreteToAbstractExpansionBeforeConcreteLocation:concreteRangeStart onLeft:left]);
    abstractRangeEnd = HFSum(concreteRangeEnd, [self concreteToAbstractExpansionBeforeConcreteLocation:concreteRangeEnd onLeft:left]);
    HFASSERT(abstractRangeEnd >= abstractRangeStart);
    
    long double startLine = HFULToFP(abstractRangeStart / bytesPerLine), endLine = HFULToFP(abstractRangeEnd / bytesPerLine);
    HFASSERT(endLine >= startLine);
    return (HFFPRange){startLine, endLine - startLine};
}

- (void)scrollToFocusedInstruction {
    if (focusedInstructionIndex < [editScript numberOfInstructions]) {
        struct HFEditInstruction_t instruction = [editScript instructionAtIndex:focusedInstructionIndex];
        HFRange leftRange = instruction.src, rightRange = instruction.dst;
        HFFPRange currentLineRange = [self displayedLineRange];
        unsigned long long contentsLength = totalAbstractLength;
        NSUInteger bytesPerLine = [[leftTextView controller] bytesPerLine];
        HFASSERT(bytesPerLine > 0);
        unsigned long long totalLineCountTimesBytesPerLine = HFRoundUpToNextMultipleSaturate(contentsLength, bytesPerLine);
        HFASSERT(totalLineCountTimesBytesPerLine == ULLONG_MAX || totalLineCountTimesBytesPerLine % bytesPerLine == 0);
        unsigned long long totalLineCount = HFDivideULLRoundingUp(totalLineCountTimesBytesPerLine, bytesPerLine);
        
        
        /* Figure out the line ranges */
        HFFPRange leftLines = [self abstractLineRangeForConcreteContentsRange:leftRange onLeft:YES];
        HFFPRange rightLines = [self abstractLineRangeForConcreteContentsRange:rightRange onLeft:NO];
        
        /* Construct a line range that encompasses both ranges.  Computing the length is done in a way that tries to preserve precision. */
        HFFPRange desiredLineRange;
        desiredLineRange.location = fminl(leftLines.location, rightLines.location);
        if (leftLines.location + leftLines.length > rightLines.location + rightLines.length) {
            desiredLineRange.length = leftLines.length + (leftLines.location - desiredLineRange.location);
        } else {
            desiredLineRange.length = rightLines.length + (rightLines.location - desiredLineRange.location);
        }
        
        /* Try centering this line range */
        long double proposedScrollLocation;
        if (desiredLineRange.length <= currentLineRange.length) {
            /* Both line ranges fit, so center it */
            proposedScrollLocation = desiredLineRange.location - (currentLineRange.length - desiredLineRange.length)/2;
        } else {
            /* The line range doesn't fit, so pin us to the top */
            proposedScrollLocation = desiredLineRange.location;
        }
        
        /* Ensure we aren't too big or too little */
        long double maxScroll = totalLineCount - currentLineRange.length;
        long double actualScroll = MAX(0, MIN(maxScroll, proposedScrollLocation));
        
        [self setDisplayedLineRange:(HFFPRange){actualScroll, currentLineRange.length}];	
    }
}


- (NSUInteger)visibleLines {
    return ll2l(HFFPToUL(ceill([self displayedLineRange].length)));
}


/* Override of BaseDataDocument methods */
- (NSSize)minimumWindowFrameSizeForProposedSize:(NSSize)frameSize {
    NSSize resultSize;
    
    /* Compute the fixed space, occupied by our scroller.  This doesn't do the right thing under HiDPI. */
    NSWindow *window = [self window];
    NSRect containerWindowRect = [textViewContainer convertRect:[textViewContainer bounds] toView:nil];
    CGFloat fixedWidth = [window frame].size.width - NSWidth(containerWindowRect);
    
    /* Figure out what this frameSize implies for the container */
    NSSize proposedContainerWindowSize = NSMakeSize(frameSize.width - fixedWidth, frameSize.height);
    NSSize proposedContainerSize = [textViewContainer convertSize:proposedContainerWindowSize fromView:nil];
    
    /* Find the min container frame size */
    NSSize containerSize = [textViewContainer minimumFrameSizeForProposedSize:proposedContainerSize];
    
    /* Convert back and we're done */
    resultSize.width = [textViewContainer convertSize:containerSize toView:nil].width + fixedWidth;
    resultSize.height = frameSize.height;
    return resultSize;
}

- (NSView *)bannerAssociateView
{
    NSView *view = [textViewContainer superview];
    HFASSERT([view isKindOfClass:[NSSplitView class]]);
    return view;
}

#pragma mark Set representer properties (override BaseDocument)
- (void)setStringEncoding:(HFStringEncoding *)encoding {
    [(HFStringEncodingTextRepresenter *)leftAsciiRepresenter setEncoding:encoding];
    [super setStringEncoding:encoding];
}

- (IBAction)setLineNumberFormat:(id)sender {
    const NSInteger tag = ((NSMenuItem*)sender).tag;
    const HFLineNumberFormat format = (HFLineNumberFormat)tag;
    HFASSERT(format == HFLineNumberFormatDecimal || format == HFLineNumberFormatHexadecimal);
    leftLineCountingRepresenter.lineNumberFormat = format;
    [super setLineNumberFormat:sender];
}

- (BOOL)setByteGrouping:(NSUInteger)newBytesPerColumn {
    [[leftTextView controller] setBytesPerColumn:newBytesPerColumn];
    return [super setByteGrouping:newBytesPerColumn];
}

- (BOOL)shouldSaveWindowState {
    return NO;
}

@end
