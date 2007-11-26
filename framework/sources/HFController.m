//
//  HFController.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFController.h>
#import <HexFiend/HFRepresenter_Internal.h>
#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFFullMemoryByteArray.h>
#import <HexFiend/HFFullMemoryByteSlice.h>

/* Used for the anchor range and location */
#define NO_SELECTION ULLONG_MAX

#if ! NDEBUG
#define VALIDATE_SELECTION() [self _ensureSelectionIsValid]
#else
#define VALIDATE_SELECTION() do { } while (0)
#endif


static const CGFloat kScrollMultiplier = (CGFloat)1.5;

@implementation HFController

- (id)init {
    [super init];
    bytesPerLine = 16;
    _hfflags.editable = YES;
    _hfflags.selectable = YES;
    representers = [[NSMutableArray alloc] init];
    selectedContentsRanges = [[NSMutableArray alloc] initWithObjects:[HFRangeWrapper withRange:HFRangeMake(0, 0)], nil];
    byteArray = [[HFFullMemoryByteArray alloc] init];
    selectionAnchor = NO_SELECTION;
    return self;
}

- (void)dealloc {
    [representers makeObjectsPerformSelector:@selector(_setController:) withObject:nil];
    [representers release];
    [selectedContentsRanges release];
    [byteArray release];
    [super dealloc];
}

- (NSArray *)representers {
    return [NSArray arrayWithArray:representers];
}

- (void)notifyRepresentersOfChanges:(HFControllerPropertyBits)bits {
    FOREACH(HFRepresenter*, rep, representers) {
        [rep controllerDidChange:bits];
    }
}

- (void)addRepresenter:(HFRepresenter *)representer {
    REQUIRE_NOT_NULL(representer);
    HFASSERT([representers indexOfObjectIdenticalTo:representer] == NSNotFound);
    HFASSERT([representer controller] == nil);
    [representer _setController:self];
    [representers addObject:representer];
    [representer controllerDidChange: -1];
}

- (void)removeRepresenter:(HFRepresenter *)representer {
    REQUIRE_NOT_NULL(representer);    
    HFASSERT([representers indexOfObjectIdenticalTo:representer] != NSNotFound);
    [representers removeObjectIdenticalTo:representer];
    [representer _setController:nil];
}

- (HFRange)displayedContentsRange {
    return displayedContentsRange;
}

- (void)setDisplayedContentsRange:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
    displayedContentsRange = range;
    [self notifyRepresentersOfChanges:HFControllerDisplayedRange];
}

- (BOOL)_shouldInvertSelectedRangesByAnchorRange {
    return _hfflags.selectionInProgress && _hfflags.commandExtendSelection;
}

- (NSArray *)_invertedSelectedContentsRanges {
    HFASSERT([selectedContentsRanges count] > 0);
    HFASSERT(selectionAnchorRange.location != NO_SELECTION);
    if (selectionAnchorRange.length == 0) return [NSArray arrayWithArray:selectedContentsRanges];
    
    NSArray *cleanedRanges = [HFRangeWrapper organizeAndMergeRanges:selectedContentsRanges];
    NSMutableArray *result = [NSMutableArray array];
    
    /* Our algorithm works as follows - add any ranges outside of the selectionAnchorRange, clipped by the selectionAnchorRange.  Then extract every "index" in our cleaned selected arrays that are within the selectionAnchorArray.  An index is the location where a range starts or stops.  Then use those indexes to create the inverted arrays.  A range parity of 1 means that we are adding the range. */
    
    /* Add all the ranges that are outside of selectionAnchorRange, clipping them if necessary */
    HFASSERT(HFSumDoesNotOverflow(selectionAnchorRange.location, selectionAnchorRange.length));
    FOREACH(HFRangeWrapper*, outsideWrapper, cleanedRanges) {
        HFRange range = [outsideWrapper HFRange];
        if (range.location < selectionAnchorRange.location) {
            HFRange clippedRange;
            clippedRange.location = range.location;
            clippedRange.length = MIN(HFMaxRange(range), selectionAnchorRange.location) - clippedRange.location;
            [result addObject:[HFRangeWrapper withRange:clippedRange]];
        }
        if (HFMaxRange(range) > HFMaxRange(selectionAnchorRange)) {
            HFRange clippedRange;
            clippedRange.location = MAX(range.location, HFMaxRange(selectionAnchorRange));
            HFASSERT(HFMaxRange(range) > clippedRange.location);
            clippedRange.length = HFMaxRange(range) - clippedRange.location;
            [result addObject:[HFRangeWrapper withRange:clippedRange]];
        }
    }
    
    HFASSERT(HFSumDoesNotOverflow(selectionAnchorRange.location, selectionAnchorRange.length));
    
    NEW_ARRAY(unsigned long long, partitions, [cleanedRanges count] + 2);
    NSUInteger partitionCount, partitionIndex = 0;
    
    partitions[partitionIndex++] = selectionAnchorRange.location;
    FOREACH(HFRangeWrapper*, wrapper, cleanedRanges) {
        HFRange range = [wrapper HFRange];
        if (! HFIntersectsRange(range, selectionAnchorRange)) continue;
        
        partitions[partitionIndex++] = MAX(selectionAnchorRange.location, range.location);
        partitions[partitionIndex++] = MIN(HFMaxRange(selectionAnchorRange), HFMaxRange(range));
    }
    partitions[partitionIndex++] = HFMaxRange(selectionAnchorRange);
    
    partitionCount = partitionIndex;
    HFASSERT((partitionCount % 2) == 0);
    
    partitionIndex = 0;
    while (partitionIndex < partitionCount) {
        HFASSERT(partitionIndex + 1 < partitionCount);
        HFASSERT(partitions[partitionIndex] <= partitions[partitionIndex + 1]);
        if (partitions[partitionIndex] < partitions[partitionIndex + 1]) {
            HFRange range = HFRangeMake(partitions[partitionIndex], partitions[partitionIndex + 1] - partitions[partitionIndex]);
            [result addObject:[HFRangeWrapper withRange:range]];
        }
        partitionIndex += 2;
    }
    
    FREE_ARRAY(partitions);
    
    if ([result count] == 0) [result addObject:[HFRangeWrapper withRange:HFRangeMake(selectionAnchor, 0)]];
    
    return [HFRangeWrapper organizeAndMergeRanges:result];
}

#if ! NDEBUG
- (void)_ensureSelectionIsValid {
    HFASSERT(selectedContentsRanges != nil);
    HFASSERT([selectedContentsRanges count] > 0);
    BOOL onlyOneWrapper = ([selectedContentsRanges count] == 1);
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange range = [wrapper HFRange];
        HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])) || (onlyOneWrapper && range.location == [self contentsLength] && range.length == 0));
        if (onlyOneWrapper == NO) HFASSERT(range.length > 0); /* If we have more than one wrapper, then none of them should be zero length */
    }
}
#endif

- (NSArray *)selectedContentsRanges {
    VALIDATE_SELECTION();
    if ([self _shouldInvertSelectedRangesByAnchorRange]) return [self _invertedSelectedContentsRanges];
    else return [NSArray arrayWithArray:selectedContentsRanges];
}

- (unsigned long long)contentsLength {
    if (! byteArray) return 0;
    else return [byteArray length];
}

- (void)copyBytes:(unsigned char *)bytes range:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax); // it doesn't make sense to ask for a buffer larger than can be stored in memory
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
    [byteArray copyBytes:bytes range:range];
}

- (void)_updateDisplayedRange {
    const unsigned long long contentLength = [self contentsLength];
    unsigned long long  maxDisplayedBytes;
    unsigned long long displayedRangeLocation = displayedContentsRange.location;
    NSUInteger maxBytesForViewSize = NSUIntegerMax;
    FOREACH(HFRepresenter*, rep, representers) {
        NSView *view = [rep view];
        NSUInteger repMaxBytesPerLine = [rep maximumNumberOfBytesForViewSize:[view frame].size];
        maxBytesForViewSize = MIN(repMaxBytesPerLine, maxBytesForViewSize);
    }
    
    maxDisplayedBytes = MIN(contentLength, maxBytesForViewSize);
    displayedRangeLocation = MIN(displayedContentsRange.location, contentLength - maxDisplayedBytes);
    HFRange proposedNewDisplayRange = HFRangeMake(displayedRangeLocation, maxDisplayedBytes);
    HFASSERT(HFRangeIsSubrangeOfRange(proposedNewDisplayRange, HFRangeMake(0, contentLength)));
    if (! HFRangeEqualsRange(proposedNewDisplayRange, displayedContentsRange)) {
        displayedContentsRange = proposedNewDisplayRange;
        propertiesToUpdate |= HFControllerDisplayedRange;
    }
}

- (void)_ensureVisibilityOfLocation:(unsigned long long)location {
    HFASSERT(location <= [self contentsLength]);
    if (! HFLocationInRange(location, displayedContentsRange)) {
        HFASSERT(location < displayedContentsRange.location || location >= HFMaxRange(displayedContentsRange));
        HFASSERT(displayedContentsRange.location % bytesPerLine == 0);
        if (location < displayedContentsRange.location) {
            unsigned long long bytesDifference = displayedContentsRange.location - location;
            unsigned long long bytesToScroll = bytesPerLine * HFDivideULLRoundingUp(bytesDifference, bytesPerLine);
            HFASSERT(displayedContentsRange.location >= bytesToScroll); //we should never think we need to scroll up more than our location
            displayedContentsRange.location -= bytesToScroll;
        }
        else {
            unsigned long long bytesDifference = HFMaxRange(displayedContentsRange) - location;
            unsigned long long bytesToScroll = bytesPerLine * HFDivideULLRoundingUp(bytesDifference, bytesPerLine);
            displayedContentsRange.location += bytesToScroll;
        }
    }
    [self notifyRepresentersOfChanges: HFControllerDisplayedRange];
}

- (void)setByteArray:(HFByteArray *)val {
    REQUIRE_NOT_NULL(val);
    [val retain];
    [byteArray release];
    byteArray = val;
    propertiesToUpdate = HFControllerContentValue | HFControllerContentLength;
    [self _updateDisplayedRange];
    [self notifyRepresentersOfChanges: propertiesToUpdate];
}

- (HFByteArray *)byteArray {
    return byteArray;
}

- (NSUInteger)bytesPerLine {
    return bytesPerLine;
}

- (BOOL)isEditable {
    return _hfflags.editable;
}

- (void)setEditable:(BOOL)flag {
    if (flag != _hfflags.editable) {
        _hfflags.editable = flag;
        [self notifyRepresentersOfChanges:HFControllerEditable];
    }
}

- (void)_updateBytesPerLine {
    NSUInteger newBytesPerLine = NSUIntegerMax;
    FOREACH(HFRepresenter*, rep, representers) {
        NSView *view = [rep view];
        CGFloat width = [view frame].size.width;
        NSUInteger repMaxBytesPerLine = [rep maximumBytesPerLineForViewWidth:width];
        newBytesPerLine = MIN(repMaxBytesPerLine, newBytesPerLine);
    }
    if (newBytesPerLine != bytesPerLine) {
        HFASSERT(newBytesPerLine > 0);
        bytesPerLine = newBytesPerLine;
        propertiesToUpdate |= HFControllerBytesPerLine;
    }
}

- (void)representer:(HFRepresenter *)rep changedProperties:(HFControllerPropertyBits)properties {
    USE(rep);
    propertiesToUpdate = 0;
    if (properties & HFControllerBytesPerLine) {
        [self _updateBytesPerLine];
        properties &= ~HFControllerBytesPerLine;
    }
    if (properties & HFControllerDisplayedRange) {
        [self _updateDisplayedRange];
        properties &= ~HFControllerDisplayedRange;
    }
    if (properties) {
        NSLog(@"Unknown properties: %lx", properties);
    }
    if (propertiesToUpdate) [self notifyRepresentersOfChanges:propertiesToUpdate];
}

/* Flattens the selected range to a single range (the selected range becomes any character within or between the selected ranges).  Modifies the selectedContentsRanges and returns the new single HFRange.  Does not call notifyRepresentersOfChanges: */
- (HFRange)_flattenSelectionRange {
    HFASSERT([selectedContentsRanges count] >= 1);
    
    HFRange resultRange = [[selectedContentsRanges objectAtIndex:0] HFRange];
    if ([selectedContentsRanges count] == 1) return resultRange; //already flat
    
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange selectedRange = [wrapper HFRange];
        if (selectedRange.location < resultRange.location) {
            /* Extend our result range backwards */
            resultRange.length += resultRange.location - selectedRange.location;
            resultRange.location = selectedRange.location;
        }
        if (HFRangeExtendsPastRange(selectedRange, resultRange)) {
            HFASSERT(selectedRange.location >= resultRange.location); //must be true by if statement above
            HFASSERT(HFSumDoesNotOverflow(selectedRange.location - resultRange.location, selectedRange.length));
            resultRange.length = selectedRange.location - resultRange.location + selectedRange.length;
        }
    }
    [selectedContentsRanges removeAllObjects];
    [selectedContentsRanges addObject:[HFRangeWrapper withRange:resultRange]];
    return resultRange;
}

- (unsigned long long)_minimumSelectionLocation {
    HFASSERT([selectedContentsRanges count] >= 1);
    unsigned long long minSelection = ULLONG_MAX;
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange range = [wrapper HFRange];
        minSelection = MIN(minSelection, range.location);
    }
    return minSelection;
}

- (unsigned long long)_maximumSelectionLocation {
    HFASSERT([selectedContentsRanges count] >= 1);
    unsigned long long maxSelection = 0;
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange range = [wrapper HFRange];
        maxSelection = MAX(maxSelection, HFMaxRange(range));
    }
    return maxSelection;
}

/* Put the selection at the left or right end of the current selection, with zero length.  Modifies the selectedContentsRanges and returns the new single HFRange.  Does not call notifyRepresentersOfChanges: */
- (HFRange)_telescopeSelectionRangeInDirection:(HFControllerMovementDirection)direction {
    HFRange resultRange;
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    resultRange.location = (direction == HFControllerDirectionLeft ? [self _minimumSelectionLocation] : [self _maximumSelectionLocation]);
    resultRange.length = 0;
    [selectedContentsRanges removeAllObjects];
    [selectedContentsRanges addObject:[HFRangeWrapper withRange:resultRange]];
    return resultRange;
}

- (void)beginSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)characterIndex {
    USE(event);
    HFASSERT(characterIndex <= [self contentsLength]);
    
    /* Determine how to perform the selection - normally, with command key, or with shift key.  Command + shift is the same as command. The shift key closes the selection - the selected range becomes the single range containing the first and last character. */
    _hfflags.shiftExtendSelection = NO;
    _hfflags.commandExtendSelection = NO;
    NSUInteger flags = [event modifierFlags];
    if (flags & NSCommandKeyMask) _hfflags.commandExtendSelection = YES;
    else if (flags & NSShiftKeyMask) _hfflags.shiftExtendSelection = YES;

    selectionAnchor = NO_SELECTION;
    selectionAnchorRange = HFRangeMake(NO_SELECTION, 0);

    _hfflags.selectionInProgress = YES;
    if (_hfflags.commandExtendSelection) {
        /* The selection anchor is used to track the "invert" range.  All characters within this range have their selection inverted.  This is tracked by the _shouldInvertSelectedRangesByAnchorRange method. */
        selectionAnchor = characterIndex;
        selectionAnchorRange = HFRangeMake(characterIndex, 0);
    }
    else if (_hfflags.shiftExtendSelection) {
        /* The selection anchor is used to track the single (flattened) selected range. */
        HFRange selectedRange = [self _flattenSelectionRange];
        unsigned long long distanceFromRangeStart = HFAbsoluteDifference(selectedRange.location, characterIndex);
        unsigned long long distanceFromRangeEnd = HFAbsoluteDifference(selectedRange.location + selectedRange.length, characterIndex);
        if (distanceFromRangeStart >= distanceFromRangeEnd) {
            /* Push the "end forwards" */
            selectedRange.length = distanceFromRangeStart;
            selectionAnchor = selectedRange.location;
        }
        else {
            /* Push the "start back" */
            selectedRange.location = selectedRange.location + selectedRange.length - distanceFromRangeEnd;
            selectedRange.length = distanceFromRangeEnd;
            HFASSERT(HFSumDoesNotOverflow(selectedRange.length, selectedRange.location));
            selectionAnchor = selectedRange.length + selectedRange.location;
        }
        HFASSERT(HFRangeIsSubrangeOfRange(selectedRange, HFRangeMake(0, [self contentsLength])));
        selectionAnchorRange = selectedRange;
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:selectedRange]];
    }
    else {
        /* No modifier key selection.  The selection anchor is not used.  */
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:HFRangeMake(characterIndex, 0)]];
        selectionAnchor = characterIndex;
    }
    
    [self notifyRepresentersOfChanges:HFControllerSelectedRanges];
}

- (void)continueSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)characterIndex {
    USE(event);
    HFASSERT(_hfflags.selectionInProgress);
    HFASSERT(characterIndex <= [self contentsLength]);
    if (_hfflags.commandExtendSelection) {
        selectionAnchorRange.location = MIN(characterIndex, selectionAnchor);
        selectionAnchorRange.length = MAX(characterIndex, selectionAnchor) - selectionAnchorRange.location;
    }
    else if (_hfflags.shiftExtendSelection) {
        HFASSERT(selectionAnchorRange.location != NO_SELECTION);
        HFASSERT(selectionAnchor != NO_SELECTION);
        HFRange range;
        if (! HFLocationInRange(characterIndex, selectionAnchorRange)) {
            /* The character index is outside of the selection anchor range.  The new range is just the selected anchor range combined with the character index. */
            range.location = MIN(characterIndex, selectionAnchorRange.location);
            HFASSERT(HFSumDoesNotOverflow(selectionAnchorRange.location, selectionAnchorRange.length));
            unsigned long long rangeEnd = MAX(characterIndex, selectionAnchorRange.location + selectionAnchorRange.length);
            HFASSERT(rangeEnd >= range.location);
            range.length = rangeEnd - range.location;
        }
        else {
            /* The character is within the selection anchor range.  We use the selection anchor index to determine which "side" of the range is selected. */
            range.location = MIN(selectionAnchor, characterIndex);
            range.length = HFAbsoluteDifference(selectionAnchor, characterIndex);
        }
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:range]];
    }
    else {
        /* No modifier key selection */
        HFRange range;
        range.location = MIN(characterIndex, selectionAnchor);
        range.length = MAX(characterIndex, selectionAnchor) - range.location;
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:range]];
    }
    [self notifyRepresentersOfChanges:HFControllerSelectedRanges];
}

- (void)endSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)characterIndex {
    USE(event);
    HFASSERT(_hfflags.selectionInProgress);
    HFASSERT(characterIndex <= [self contentsLength]);
    if (_hfflags.commandExtendSelection) {
        selectionAnchorRange.location = MIN(characterIndex, selectionAnchor);
        selectionAnchorRange.length = MAX(characterIndex, selectionAnchor) - selectionAnchorRange.location;
        
        /* "Commit" our selectionAnchorRange */
        NSArray *newSelection = [self _invertedSelectedContentsRanges];
        [selectedContentsRanges setArray:newSelection];
    }
    else if (_hfflags.shiftExtendSelection) {
        HFASSERT(selectionAnchorRange.location != NO_SELECTION);
        HFASSERT(selectionAnchor != NO_SELECTION);
        HFRange range;
        if (! HFLocationInRange(characterIndex, selectionAnchorRange)) {
            /* The character index is outside of the selection anchor range.  The new range is just the selected anchor range combined with the character index. */
            range.location = MIN(characterIndex, selectionAnchorRange.location);
            HFASSERT(HFSumDoesNotOverflow(selectionAnchorRange.location, selectionAnchorRange.length));
            unsigned long long rangeEnd = MAX(characterIndex, selectionAnchorRange.location + selectionAnchorRange.length);
            HFASSERT(rangeEnd >= range.location);
            range.length = rangeEnd - range.location;
        }
        else {
            /* The character is within the selection anchor range.  We use the selection anchor index to determine which "side" of the range is selected. */
            range.location = MIN(selectionAnchor, characterIndex);
            range.length = HFAbsoluteDifference(selectionAnchor, characterIndex);
        }
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:range]];
    }
    else {
        /* No modifier key selection */
        HFRange range;
        range.location = MIN(characterIndex, selectionAnchor);
        range.length = MAX(characterIndex, selectionAnchor) - range.location;
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:range]];
    }

    _hfflags.selectionInProgress = NO;    
    _hfflags.shiftExtendSelection = NO;
    _hfflags.commandExtendSelection = NO;
    selectionAnchor = NO_SELECTION;
    
    [self notifyRepresentersOfChanges:HFControllerSelectedRanges];
}

- (void)scrollWithScrollEvent:(NSEvent *)scrollEvent {
    HFASSERT(scrollEvent != NULL);
    HFASSERT([scrollEvent type] == NSScrollWheel);
    CGFloat scrollY = kScrollMultiplier * [scrollEvent deltaY];
#if NSUIntegerMax >= LLONG_MAX
    HFASSERT(bytesPerLine <= LLONG_MAX);
#endif
    long long amountToScroll = ((long long)bytesPerLine) * (long long)HFRound( - scrollY);
    if (amountToScroll == 0) amountToScroll = (signbit(scrollY) ? (long long)bytesPerLine : - (long long)bytesPerLine); //minimum of one line of scroll
    NSLog(@"Amount to scroll: %lld", amountToScroll);
    unsigned long long contentsLength = [self contentsLength];
    HFRange newDisplayedContentsRange = displayedContentsRange;
    if (amountToScroll != 0) {
        HFASSERT(newDisplayedContentsRange.length <= [self contentsLength]);
        if (amountToScroll < 0) {
            unsigned long long unsignedAmountToScroll = (unsigned long long)( - amountToScroll);
            unsignedAmountToScroll -= unsignedAmountToScroll % bytesPerLine;

            newDisplayedContentsRange.location -= MIN(newDisplayedContentsRange.location, unsignedAmountToScroll);
        }
        else {
            /* amountToScroll > 0 */
            unsigned long long unsignedAmountToScroll = (unsigned long long)amountToScroll;
            unsignedAmountToScroll -= unsignedAmountToScroll % bytesPerLine;
            
            HFASSERT(contentsLength >= newDisplayedContentsRange.length);
            unsigned long long maxScroll = contentsLength - newDisplayedContentsRange.length;
            maxScroll -= maxScroll % bytesPerLine;
            HFASSERT(HFSumDoesNotOverflow(newDisplayedContentsRange.location, unsignedAmountToScroll));
            newDisplayedContentsRange.location = MIN(newDisplayedContentsRange.location + unsignedAmountToScroll, maxScroll);
        }
    }
    
    if (! HFRangeEqualsRange(newDisplayedContentsRange, displayedContentsRange)) {
        displayedContentsRange = newDisplayedContentsRange;
        [self notifyRepresentersOfChanges:HFControllerDisplayedRange];
    }
}

- (IBAction)selectAll:sender {
    USE(sender);
    if (_hfflags.selectable) {
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:HFRangeMake(0, [self contentsLength])]];
        [self notifyRepresentersOfChanges:HFControllerSelectedRanges];
    }
}


- (void)_addRangeToSelection:(HFRange)range {
    [selectedContentsRanges addObject:[HFRangeWrapper withRange:range]];
    [selectedContentsRanges setArray:[HFRangeWrapper organizeAndMergeRanges:selectedContentsRanges]];
    VALIDATE_SELECTION();
}

- (void)_removeRangeFromSelection:(HFRange)inputRange withCursorLocationIfAllSelectionRemoved:(unsigned long long)cursorLocation {
    NSUInteger selectionCount = [selectedContentsRanges count];
    HFASSERT(selectionCount > 0 && selectionCount <= NSUIntegerMax / 2);
    NSUInteger rangeIndex = 0;
    NSArray *wrappers;
    NEW_ARRAY(HFRange, tempRanges, selectionCount * 2);
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange range = [wrapper HFRange];
        if (! HFIntersectsRange(range, inputRange)) {
            tempRanges[rangeIndex++] = range;
        }
        else {
            if (range.location < inputRange.location) {
                tempRanges[rangeIndex++] = HFRangeMake(range.location, inputRange.location - range.location);
             }
             if (HFMaxRange(range) > HFMaxRange(inputRange)) {
                tempRanges[rangeIndex++] = HFRangeMake(HFMaxRange(inputRange), HFMaxRange(range) - HFMaxRange(inputRange));
             }
        }
    }
    if (rangeIndex == 0) {
        /* We removed all of our range.  Telescope us. */
        HFASSERT(cursorLocation <= [self contentsLength]);
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:HFRangeMake(cursorLocation, 0)]];
    }
    else {
        wrappers = [HFRangeWrapper withRanges:tempRanges count:rangeIndex];
        [selectedContentsRanges setArray:[HFRangeWrapper organizeAndMergeRanges:wrappers]];
    }
    FREE_ARRAY(tempRanges);
    VALIDATE_SELECTION();    
}

- (void)_moveDirectionWithoutModifyingSelection:(HFControllerMovementDirection)direction {
    BOOL selectionWasEmpty = ([selectedContentsRanges count] == 1 && [[selectedContentsRanges objectAtIndex:0] HFRange].length == 0);
    /* Vertical movement always telescopes left. */
    HFRange selectedRange = [self _telescopeSelectionRangeInDirection: (direction == HFControllerDirectionRight ? HFControllerDirectionRight : HFControllerDirectionLeft)];
    HFASSERT(selectedRange.length == 0);
    switch (direction) {
        case HFControllerDirectionLeft:
            if (selectionWasEmpty && selectedRange.location > 0) selectedRange.location -= 1;
            break;
        case HFControllerDirectionRight:
            if (selectionWasEmpty && selectedRange.location < [self contentsLength]) selectedRange.location += 1; /* Allow the selectedRange.location to be equal to the contents length, so the cursor can be at the end */
            break;
        case HFControllerDirectionUp:
            selectedRange.location -= MIN([self bytesPerLine], selectedRange.location);
            break;
        case HFControllerDirectionDown:
            selectedRange.location += MIN([self bytesPerLine], [self contentsLength] - selectedRange.location);
            break;
    }
    selectionAnchor = NO_SELECTION;
    [selectedContentsRanges removeAllObjects];
    [selectedContentsRanges addObject:[HFRangeWrapper withRange:selectedRange]];
    propertiesToUpdate = HFControllerSelectedRanges;
    [self _ensureVisibilityOfLocation:selectedRange.location];
    [self notifyRepresentersOfChanges:propertiesToUpdate];
}

- (void)_moveDirectionWhileModifyingSelection:(HFControllerMovementDirection)direction {
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight || direction == HFControllerDirectionUp || direction == HFControllerDirectionDown);
    unsigned long long minSelection = [self _minimumSelectionLocation];
    unsigned long long maxSelection = [self _maximumSelectionLocation];
    BOOL selectionChanged = NO;
    unsigned long long locationToMakeVisible = NO_SELECTION;
    if (selectionAnchor == NO_SELECTION) {
        /* Pick the anchor opposite the choice of direction */
        if (direction == HFControllerDirectionLeft || direction == HFControllerDirectionUp) selectionAnchor = maxSelection;
        else selectionAnchor = minSelection;
    }
    if (direction == HFControllerDirectionLeft) {
        if (minSelection >= selectionAnchor && maxSelection > minSelection) {
            [self _removeRangeFromSelection:HFRangeMake(maxSelection-1, 1) withCursorLocationIfAllSelectionRemoved:minSelection];
            selectionChanged = YES;
            locationToMakeVisible = maxSelection - 1;
        }
        else {
            if (minSelection > 0) {
                [self _addRangeToSelection:HFRangeMake(minSelection-1, 1)];
                selectionChanged = YES;
                locationToMakeVisible = minSelection - 1;
            }
        }
    }
    else if (direction == HFControllerDirectionRight) {
        if (maxSelection <= selectionAnchor && maxSelection > minSelection) {
            [self _removeRangeFromSelection:HFRangeMake(minSelection, 1) withCursorLocationIfAllSelectionRemoved:maxSelection];
            selectionChanged = YES;
            locationToMakeVisible = minSelection + 1;
        }
        else {
            if (maxSelection < [self contentsLength]) {
                [self _addRangeToSelection:HFRangeMake(maxSelection, 1)];
                selectionChanged = YES;
                locationToMakeVisible = maxSelection;
            }
        }
    }
    if (selectionChanged) {
        propertiesToUpdate = HFControllerSelectedRanges;
        if (locationToMakeVisible != NO_SELECTION) [self _ensureVisibilityOfLocation:locationToMakeVisible];
        [self notifyRepresentersOfChanges:propertiesToUpdate];
    }
}

- (void)moveDirection:(HFControllerMovementDirection)direction andModifySelection:(BOOL)extendSelection {
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight || direction == HFControllerDirectionUp || direction == HFControllerDirectionDown);
    if (! extendSelection) {
        [self _moveDirectionWithoutModifyingSelection:direction];
    }
    else {
        [self _moveDirectionWhileModifyingSelection:direction];
    }
}

#ifndef NDEBUG
#define HFTEST(a) do { if (! (a)) { printf("Test failed on line %u of file %s: %s\n", __LINE__, __FILE__, #a); exit(0); } } while (0)
+ (void)_testRangeFunctions {
    HFRange range = HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL);
    HFTEST(range.location == UINT_MAX + 573ULL && range.length == UINT_MAX * 2ULL);
    HFTEST(HFRangeIsSubrangeOfRange(range, range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), range));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length, 0), range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), HFRangeMake(range.location, 0)));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), HFRangeMake(range.location + 1, 0)));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + 6, 0), range));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length, 0), range));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length + 1, 0), range));
    HFTEST(! HFRangeIsSubrangeOfRange(range, HFRangeMake(34, 0)));
    HFTEST(HFRangeIsSubrangeOfRange(range, HFRangeMake(range.location - 32, range.length + 54)));
    HFTEST(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, ULLONG_MAX)));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 23), HFRangeMake(ULLONG_MAX - 3, 23)));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 22), HFRangeMake(ULLONG_MAX - 3, 23)));
    
    HFTEST(HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL)));
    HFTEST(! HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL + 1)));
    
    HFTEST(HFIntersectsRange(range, HFRangeMake(UINT_MAX + 3ULL, UINT_MAX * 2ULL + 1)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(3, 0)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 0), HFRangeMake(3, 0)));
    HFTEST(HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(3, 3)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(6, 0)));
    
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(range, range), range));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(0, 25), HFRangeMake(10, 11)), HFRangeMake(10, 11)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(15, 10)), HFRangeMake(15, 6)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(150, 10)), HFRangeMake(0, 0)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(0, 25), HFRangeMake(10, 11)), HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(0, 25))));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(15, 10)), HFIntersectionRange(HFRangeMake(15, 10), HFRangeMake(10, 11))));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(150, 10)), HFIntersectionRange(HFRangeMake(150, 10), HFRangeMake(10, 11))));
    
    HFTEST(HFRangeEqualsRange(HFUnionRange(HFRangeMake(1, 3), HFRangeMake(2, 3)), HFRangeMake(1, 4)));
    HFTEST(HFRangeEqualsRange(HFUnionRange(HFRangeMake(1, 3), HFRangeMake(4, 4)), HFRangeMake(1, 7)));
    
    HFTEST(HFSumDoesNotOverflow(ULLONG_MAX, 0));
    HFTEST(! HFSumDoesNotOverflow(ULLONG_MAX, 1));
    HFTEST(HFSumDoesNotOverflow(ULLONG_MAX / 2, ULLONG_MAX / 2));
    HFTEST(HFSumDoesNotOverflow(0, 0));
    HFTEST(ll2l((unsigned long long)UINT_MAX) == UINT_MAX);
    
    const HFRange dirtyRanges1[] = { {4, 6}, {6, 2}, {7, 3} };
    const HFRange cleanedRanges1[] = { {4, 6} };
    
    const HFRange dirtyRanges2[] = { {4, 6}, {6, 2}, {50, 5}, {7, 3}, {50, 1}};
    const HFRange cleanedRanges2[] = { {4, 6}, {50, 5} };
    
    const HFRange dirtyRanges3[] = { {40, 50}, {10, 20} };
    const HFRange cleanedRanges3[] = { {10, 20}, {40, 50} };
    
    const HFRange dirtyRanges4[] = { {11, 3}, {5, 6}, {23, 54} };
    const HFRange cleanedRanges4[] = { {5, 9}, {23, 54} };

    
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges1 count:sizeof dirtyRanges1 / sizeof *dirtyRanges1]] isEqual:[HFRangeWrapper withRanges:cleanedRanges1 count:sizeof cleanedRanges1 / sizeof *cleanedRanges1]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges2 count:sizeof dirtyRanges2 / sizeof *dirtyRanges2]] isEqual:[HFRangeWrapper withRanges:cleanedRanges2 count:sizeof cleanedRanges2 / sizeof *cleanedRanges2]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges3 count:sizeof dirtyRanges3 / sizeof *dirtyRanges3]] isEqual:[HFRangeWrapper withRanges:cleanedRanges3 count:sizeof cleanedRanges3 / sizeof *cleanedRanges3]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges4 count:sizeof dirtyRanges4 / sizeof *dirtyRanges4]] isEqual:[HFRangeWrapper withRanges:cleanedRanges4 count:sizeof cleanedRanges4 / sizeof *cleanedRanges4]]);
    //NSLog(@"%@", [HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges4 count:sizeof dirtyRanges4 / sizeof *dirtyRanges4]]);
}

static NSData *randomDataOfLength(NSUInteger length) {
    if (! length) return [NSData data];
    
    unsigned char* buff = check_malloc(length);
    
    unsigned* word = (unsigned*)buff;
    NSUInteger wordCount = length / sizeof *word;
    NSUInteger i;
    unsigned randBits = 0;
    unsigned numUsedRandBits = 31;
    for (i=0; i < wordCount; i++) {
        if (numUsedRandBits >= 31) {
            randBits = random();
            numUsedRandBits = 0;
        }
        unsigned randVal = random() << 1;
        randVal |= (randBits & 1);
        randBits >>= 1;
        numUsedRandBits++;
        word[i] = randVal;
    }
    
    unsigned byteIndex = wordCount * sizeof *word;
    while (byteIndex < length) {
        buff[byteIndex++] = random() & 0xFF;
    }
    
    return [NSData dataWithBytesNoCopy:buff length:length freeWhenDone:YES];
}

+ (void)_testByteArray {
    const BOOL should_debug = NO;
#define DEBUG if (should_debug)  
    DEBUG puts("Beginning TAVL Tree test:");
    HFByteArray* first = [[[HFFullMemoryByteArray alloc] init] autorelease];
    HFByteArray* second = [[[HFFullMemoryByteArray alloc] init] autorelease];
    
    //srandom(time(NULL));
    
    unsigned opCount = 5000;
    unsigned long long expectedLength = 0;
    unsigned i;
    for (i=1; i <= opCount; i++) {
	NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
	unsigned op;
	const unsigned long long length = [first length];
	unsigned long long offset;
	unsigned long long number;
	switch ((op = (random()%2))) {
	    case 0: { //insert
		NSData *data = randomDataOfLength(1 + random()%1000);
		offset = random() % (1 + length);
		HFByteSlice* slice = [[HFFullMemoryByteSlice alloc] initWithData:data];
		DEBUG printf("%u)\tInserting %llu bytes at %llu...", i, [slice length], offset);
		[first insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
		[second insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
		expectedLength += [data length];
		[slice release];
		break;
	    }
	    case 1: { //delete
		if (length > 0) {
		    offset = random() % length;
		    number = 1 + random() % (length - offset);
		    DEBUG printf("%u)\tDeleting at %llu for %llu...", i, offset, number);
		    [first deleteBytesInRange:HFRangeMake(offset, number)];
		    [second deleteBytesInRange:HFRangeMake(offset, number)];
		    expectedLength -= number;
		}
		else DEBUG printf("%u)\tLength of zero, no delete...", i);
		break;
	    }
	}
	[pool release];
	fflush(NULL);
	if ([first _debugIsEqual:second]) {
	    DEBUG printf("OK! Length: %llu\t%s\n", [second length], [[second description] UTF8String]);
	}
	else {
	    DEBUG printf("Error! expected length: %llu mem length: %llu tavl length:%llu desc: %s\n", expectedLength, [first length], [second length], [[second description] UTF8String]);
	    exit(EXIT_FAILURE);
	}
    }
    DEBUG puts("Done!");
    DEBUG printf("%s\n", [[second description] UTF8String]);
}

+ (void)_runAllTests {
    [self _testRangeFunctions];
    [self _testByteArray];

}
#endif

#ifndef NDEBUG
+ (void)initialize {
    if (self == [HFController class]) {
        [self _runAllTests];
    }
}
#endif

@end
