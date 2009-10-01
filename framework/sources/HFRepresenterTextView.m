//
//  HFRepresenterTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView_Internal.h>
#import <HexFiend/HFTextRepresenter_Internal.h>
#import <HexFiend/HFTextSelectionPulseView.h>

static const NSTimeInterval HFCaretBlinkFrequency = 0.56;

@implementation HFRepresenterTextView

/* Returns the number of glyphs for the given string, using the given text view, and generating the glyphs if the glyphs parameter is not NULL */
- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingTextView:(NSTextView *)textView glyphs:(CGGlyph *)glyphs {
    NSUInteger glyphIndex, glyphCount;
    HFASSERT(string != NULL);
    HFASSERT(textView != NULL);
    NSGlyph nsglyphs[GLYPH_BUFFER_SIZE];
    [textView setString:string];
    [textView setNeedsDisplay:YES]; //ligature generation doesn't seem to happen without this, for some reason.  This seems very fragile!  We should find a better way to get this ligature information!!
    glyphCount = [[textView layoutManager] getGlyphs:nsglyphs range:NSMakeRange(0, MIN(GLYPH_BUFFER_SIZE, [[textView layoutManager] numberOfGlyphs]))];
    if (glyphs != NULL) {
        /* Convert from unsigned int NSGlyphs to unsigned short CGGlyphs */
        for (glyphIndex = 0; glyphIndex < glyphCount; glyphIndex++) {
            /* Get rid of NSControlGlyph */
            NSGlyph modifiedGlyph = nsglyphs[glyphIndex] == NSControlGlyph ? NSNullGlyph : nsglyphs[glyphIndex];
            HFASSERT(modifiedGlyph <= USHRT_MAX);
            glyphs[glyphIndex] = (CGGlyph)modifiedGlyph;
        }
    }
    return glyphCount;
}

- (NSArray *)displayedSelectedContentsRanges {
    if (! cachedSelectedRanges) {
        cachedSelectedRanges = [[[self representer] displayedSelectedContentsRanges] copy];
    }
    return cachedSelectedRanges;
}

- (BOOL)_shouldHaveCaretTimer {
    NSWindow *window = [self window];
    if (window == NULL) return NO;
    if (! [window isKeyWindow]) return NO;
    if (self != [window firstResponder]) return NO;
    if (! _hftvflags.editable) return NO;
    NSArray *ranges = [self displayedSelectedContentsRanges];
    if ([ranges count] != 1) return NO;
    NSRange range = [[ranges objectAtIndex:0] rangeValue];
    if (range.length != 0) return NO;
    return YES;
}

- (NSPoint)originForCharacterAtByteIndex:(NSUInteger)index {
    NSPoint result;
    NSUInteger bytesPerLine = [self bytesPerLine];
    result.y = (index / bytesPerLine - [self verticalOffset]) * [self lineHeight];
    NSUInteger byteIndexIntoLine = index % bytesPerLine;
    NSUInteger bytesPerColumn = [self bytesPerColumn];
    NSUInteger numConsumedColumns = (bytesPerColumn ? byteIndexIntoLine / bytesPerColumn : 0);
    result.x = [self horizontalContainerInset] + (index % bytesPerLine) * [self advancePerByte] + numConsumedColumns * [self advanceBetweenColumns];
    return result;
}

- (NSUInteger)indexOfCharacterAtPoint:(NSPoint)point {
    NSUInteger bytesPerLine = [self bytesPerLine];
    CGFloat advancePerByte = [self advancePerByte];
    NSUInteger bytesPerColumn = [self bytesPerColumn];
    CGFloat floatRow = (CGFloat)floor([self verticalOffset] + point.y / [self lineHeight]);
    NSUInteger indexWithinRow;
    
    // to compute the column, we need to solve for byteIndexIntoLine in something like this: point.x = [self advancePerByte] * byteIndexIntoLine + [self spaceBetweenColumns] * floor(byteIndexIntoLine / [self bytesPerColumn]).  Start by computing the column (or if bytesPerColumn is 0, we don't have columns)
    CGFloat insetX = point.x - [self horizontalContainerInset];
    if (insetX < 0) {
        //handle the case of dragging within the container inset
        indexWithinRow = 0;
    }
    else if (bytesPerColumn == 0) {
        /* We don't have columns */
        indexWithinRow = insetX / advancePerByte;
    }
    else {
        CGFloat advancePerColumn = [self advancePerColumn];
        HFASSERT(advancePerColumn > 0);
        CGFloat floatColumn = insetX / advancePerColumn;
        HFASSERT(floatColumn >= 0 && floatColumn <= NSUIntegerMax);
        CGFloat startOfColumn = advancePerColumn * HFFloor(floatColumn);
        HFASSERT(startOfColumn <= insetX);
        CGFloat xOffsetWithinColumn = insetX - startOfColumn;
        CGFloat byteIndexWithinColumn = xOffsetWithinColumn / advancePerByte; //byteIndexWithinColumn may be larger than bytesPerColumn if the user clicked on the space between columns
        HFASSERT(byteIndexWithinColumn >= 0 && byteIndexWithinColumn <= NSUIntegerMax);
        indexWithinRow = bytesPerColumn * (NSUInteger)floatColumn + (NSUInteger)byteIndexWithinColumn; //this may trigger overflow to the next column, but that's OK
        indexWithinRow = MIN(indexWithinRow, bytesPerLine); //don't let clicking to the right of the line overflow to the next line
    }
    HFASSERT(floatRow >= 0 && floatRow <= NSUIntegerMax);
    NSUInteger row = (NSUInteger)floatRow;
    return row * bytesPerLine + indexWithinRow;
}

- (NSRect)caretRect {
    NSArray *ranges = [self displayedSelectedContentsRanges];
    HFASSERT([ranges count] == 1);
    NSRange range = [[ranges objectAtIndex:0] rangeValue];
    HFASSERT(range.length == 0);
    
    NSPoint caretBaseline = [self originForCharacterAtByteIndex:range.location];
    return NSMakeRect(caretBaseline.x - 1, caretBaseline.y, 1, [self lineHeight]);
}

- (void)_blinkCaret:(NSTimer *)timer {
    HFASSERT(timer == caretTimer);
    if (_hftvflags.caretVisible) {
        _hftvflags.caretVisible = NO;
        [self setNeedsDisplayInRect:lastDrawnCaretRect];
        caretRectToDraw = NSZeroRect;
    }
    else {
        _hftvflags.caretVisible = YES;
        caretRectToDraw = [self caretRect];
        [self setNeedsDisplayInRect:caretRectToDraw];
    }
}

- (void)_updateCaretTimerWithFirstResponderStatus:(BOOL)treatAsHavingFirstResponder {
    BOOL hasCaretTimer = !! caretTimer;
    BOOL shouldHaveCaretTimer = treatAsHavingFirstResponder && [self _shouldHaveCaretTimer];
    if (shouldHaveCaretTimer == YES && hasCaretTimer == NO) {
        caretTimer = [[NSTimer timerWithTimeInterval:HFCaretBlinkFrequency target:self selector:@selector(_blinkCaret:) userInfo:nil repeats:YES] retain];
        NSRunLoop *loop = [NSRunLoop currentRunLoop];
        [loop addTimer:caretTimer forMode:NSDefaultRunLoopMode];
        [loop addTimer:caretTimer forMode:NSModalPanelRunLoopMode];
        if (HFIsRunningOnLeopardOrLater() && [self enclosingMenuItem] != NULL) {
            [loop addTimer:caretTimer forMode:NSEventTrackingRunLoopMode];            
        }
    }
    else if (shouldHaveCaretTimer == NO && hasCaretTimer == YES) {
        [caretTimer invalidate];
        [caretTimer release];
        caretTimer = nil;
        caretRectToDraw = NSZeroRect;
        if (! NSIsEmptyRect(lastDrawnCaretRect)) {
            [self setNeedsDisplayInRect:lastDrawnCaretRect];
        }
    }
    HFASSERT(shouldHaveCaretTimer == !! caretTimer);
}

- (void)_updateCaretTimer {
    [self _updateCaretTimerWithFirstResponderStatus: self == [[self window] firstResponder]];
}

/* When you click or type, the caret appears immediately - do that here */
- (void)_forceCaretOnIfHasCaretTimer {
    if (caretTimer) {
        [caretTimer invalidate];
        [caretTimer release];
        caretTimer = nil;
        [self _updateCaretTimer];
        
        _hftvflags.caretVisible = YES;
        caretRectToDraw = [self caretRect];
        [self setNeedsDisplayInRect:caretRectToDraw];
    }
}

/* Returns the range of lines containing the selected contents ranges (as NSValues containing NSRanges), or {NSNotFound, 0} if ranges is nil or empty */
- (NSRange)_lineRangeForContentsRanges:(NSArray *)ranges {
    NSUInteger minLine = NSUIntegerMax;
    NSUInteger maxLine = 0;
    NSUInteger bytesPerLine = [self bytesPerLine];
    FOREACH(NSValue *, rangeValue, ranges) {
        NSRange range = [rangeValue rangeValue];
        if (range.length > 0) {
            NSUInteger lineForRangeStart = range.location / bytesPerLine;
            NSUInteger lineForRangeEnd = NSMaxRange(range) / bytesPerLine;
            HFASSERT(lineForRangeStart <= lineForRangeEnd);
            minLine = MIN(minLine, lineForRangeStart);
            maxLine = MAX(maxLine, lineForRangeEnd);
        }
    }
    if (minLine > maxLine) return NSMakeRange(NSNotFound, 0);
    else return NSMakeRange(minLine, maxLine - minLine + 1);
}

- (NSRect)_rectForLineRange:(NSRange)lineRange {
    HFASSERT(lineRange.location != NSNotFound);
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSRect bounds = [self bounds];
    NSRect result;
    result.origin.x = NSMinX(bounds);
    result.size.width = NSWidth(bounds);
    result.origin.y = [self originForCharacterAtByteIndex:lineRange.location * bytesPerLine].y;
    result.size.height = [self lineHeight] * lineRange.length;
    return result;
}

static int range_compare(const void *ap, const void *bp) {
    const NSRange *a = ap;
    const NSRange *b = bp;
    if (a->location < b->location) return -1;
    if (a->location > b->location) return 1;
    if (a->length < b->length) return -1;
    if (a->length > b->length) return 1;
    return 0;
}

enum LineCoverage_t {
    eCoverageNone,
    eCoveragePartial,
    eCoverageFull
};

- (void)_linesWithParityChangesFromRanges:(const NSRange *)oldRanges count:(NSUInteger)oldRangeCount toRanges:(const NSRange *)newRanges count:(NSUInteger)newRangeCount intoIndexSet:(NSMutableIndexSet *)result {
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSUInteger oldParity=0, newParity=0;
    NSUInteger oldRangeIndex = 0, newRangeIndex = 0;
    NSUInteger currentCharacterIndex = MIN(oldRanges[oldRangeIndex].location, newRanges[newRangeIndex].location);
    oldParity = (currentCharacterIndex >= oldRanges[oldRangeIndex].location);
    newParity = (currentCharacterIndex >= newRanges[newRangeIndex].location);
    //    NSLog(@"Old %s, new %s at %u (%u, %u)", oldParity ? "on" : "off", newParity ? "on" : "off", currentCharacterIndex, oldRanges[oldRangeIndex].location, newRanges[newRangeIndex].location);
    for (;;) {
        NSUInteger oldDivision = NSUIntegerMax, newDivision = NSUIntegerMax;
        /* Move up to the next parity change */
        if (oldRangeIndex < oldRangeCount) {
            const NSRange oldRange = oldRanges[oldRangeIndex];
            oldDivision = oldRange.location + (oldParity ? oldRange.length : 0);
        }
        if (newRangeIndex < newRangeCount) {
            const NSRange newRange = newRanges[newRangeIndex];            
            newDivision = newRange.location + (newParity ? newRange.length : 0);
        }
        
        NSUInteger division = MIN(oldDivision, newDivision);
        HFASSERT(division > currentCharacterIndex);
        
        //        NSLog(@"Division %u", division);
        
        if (division == NSUIntegerMax) break;
        
        if (oldParity != newParity) {
            /* The parities did not match through this entire range, so add all intersected lines to the result index set */
            NSUInteger startLine = currentCharacterIndex / bytesPerLine;
            NSUInteger endLine = HFDivideULRoundingUp(division, bytesPerLine);
            HFASSERT(endLine >= startLine);
            //            NSLog(@"Adding lines %u -> %u", startLine, endLine);
            [result addIndexesInRange:NSMakeRange(startLine, endLine - startLine)];
        }
        if (division == oldDivision) {
            oldRangeIndex += oldParity;
            oldParity = ! oldParity;
            //            NSLog(@"Old range switching %s at %u", oldParity ? "on" : "off", division);
        }
        if (division == newDivision) {
            newRangeIndex += newParity;
            newParity = ! newParity;
            //            NSLog(@"New range switching %s at %u", newParity ? "on" : "off", division);
        }
        currentCharacterIndex = division;
    }
}

- (void)_addLinesFromRanges:(const NSRange *)ranges count:(NSUInteger)count toIndexSet:(NSMutableIndexSet *)set {
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSUInteger i;
    for (i=0; i < count; i++) {
        NSUInteger firstLine = ranges[i].location / bytesPerLine;
        NSUInteger lastLine = HFDivideULRoundingUp(NSMaxRange(ranges[i]), bytesPerLine);
        [set addIndexesInRange:NSMakeRange(firstLine, lastLine - firstLine)];
    }
}

- (NSIndexSet *)_indexSetOfLinesNeedingRedrawWhenChangingSelectionFromRanges:(NSArray *)oldSelectedRangeArray toRanges:(NSArray *)newSelectedRangeArray {
    NSUInteger oldRangeCount = 0, newRangeCount = 0;
    
    NEW_ARRAY(NSRange, oldRanges, [oldSelectedRangeArray count]);
    NEW_ARRAY(NSRange, newRanges, [newSelectedRangeArray count]);
    
    NSMutableIndexSet *result = [NSMutableIndexSet indexSet];
    
    /* Extract all the ranges into a local array */
    FOREACH(NSValue *, rangeValue1, oldSelectedRangeArray) {
        NSRange range = [rangeValue1 rangeValue];
        if (range.length > 0) {
            oldRanges[oldRangeCount++] = range;
        }
    }
    FOREACH(NSValue *, rangeValue2, newSelectedRangeArray) {
        NSRange range = [rangeValue2 rangeValue];
        if (range.length > 0) {
            newRanges[newRangeCount++] = range;
        }
    }
    
#if ! NDEBUG
    /* Assert that ranges of arrays do not have any self-intersection; this is supposed to be enforced by our HFController.  Also assert that they aren't "just touching"; if they are they should be merged into a single range. */
    for (NSUInteger i=0; i < oldRangeCount; i++) {
        for (NSUInteger j=i+1; j < oldRangeCount; j++) {
            HFASSERT(NSIntersectionRange(oldRanges[i], oldRanges[j]).length == 0);
            HFASSERT(NSMaxRange(oldRanges[i]) != oldRanges[j].location && NSMaxRange(oldRanges[j]) != oldRanges[i].location);
        }
    }
    for (NSUInteger i=0; i < newRangeCount; i++) {
        for (NSUInteger j=i+1; j < newRangeCount; j++) {
            HFASSERT(NSIntersectionRange(newRanges[i], newRanges[j]).length == 0);
            HFASSERT(NSMaxRange(newRanges[i]) != newRanges[j].location && NSMaxRange(newRanges[j]) != newRanges[i].location);
        }
    }
#endif
    
    if (newRangeCount == 0) {
        [self _addLinesFromRanges:oldRanges count:oldRangeCount toIndexSet:result];
    }
    else if (oldRangeCount == 0) {
        [self _addLinesFromRanges:newRanges count:newRangeCount toIndexSet:result];
    }
    else {
        /* Sort the arrays, since _linesWithParityChangesFromRanges needs it */
        qsort(oldRanges, oldRangeCount, sizeof *oldRanges, range_compare);
        qsort(newRanges, newRangeCount, sizeof *newRanges, range_compare);
        
        [self _linesWithParityChangesFromRanges:oldRanges count:oldRangeCount toRanges:newRanges count:newRangeCount intoIndexSet:result];
    }
    
    FREE_ARRAY(oldRanges);
    FREE_ARRAY(newRanges);
    
    return result;
}

- (void)updateSelectedRanges {
    NSArray *oldSelectedRanges = cachedSelectedRanges;
    cachedSelectedRanges = [[[self representer] displayedSelectedContentsRanges] copy];
    NSIndexSet *indexSet = [self _indexSetOfLinesNeedingRedrawWhenChangingSelectionFromRanges:oldSelectedRanges toRanges:cachedSelectedRanges];
    BOOL lastCaretRectNeedsRedraw = ! NSIsEmptyRect(lastDrawnCaretRect);
    NSRange lineRangeToInvalidate = NSMakeRange(NSUIntegerMax, 0);
    for (NSUInteger lineIndex = [indexSet firstIndex]; ; lineIndex = [indexSet indexGreaterThanIndex:lineIndex]) {
        if (lineIndex != NSNotFound && NSMaxRange(lineRangeToInvalidate) == lineIndex) {
            lineRangeToInvalidate.length++;
        }
        else {
            if (lineRangeToInvalidate.length > 0) {
                NSRect rectToInvalidate = [self _rectForLineRange:lineRangeToInvalidate];
                [self setNeedsDisplayInRect:rectToInvalidate];
                lastCaretRectNeedsRedraw = lastCaretRectNeedsRedraw && ! NSContainsRect(rectToInvalidate, lastDrawnCaretRect);
            }
            lineRangeToInvalidate = NSMakeRange(lineIndex, 1);
        }
        if (lineIndex == NSNotFound) break;
    }
    
    if (lastCaretRectNeedsRedraw) [self setNeedsDisplayInRect:lastDrawnCaretRect];
    [oldSelectedRanges release]; //balance the retain we borrowed from the ivar
    [self _updateCaretTimer];
    [self _forceCaretOnIfHasCaretTimer];
}

- (void)drawPulseBackgroundInRect:(NSRect)pulseRect {
    [[NSColor yellowColor] set];
    if (HFIsRunningOnLeopardOrLater()) {
        CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextSaveGState(ctx);
        [[NSBezierPath bezierPathWithRoundedRect:pulseRect xRadius:25 yRadius:25] addClip];
        NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor yellowColor] endingColor:[NSColor colorWithCalibratedRed:(CGFloat)1. green:(CGFloat).75 blue:0 alpha:1]];
        [gradient drawInRect:pulseRect angle:90];
        [gradient release];
        CGContextRestoreGState(ctx);
    }
    else {
        NSRectFill(pulseRect);
    }
}

- (void)fadePulseWindowTimer:(NSTimer *)timer {
    NSWindow *window = [timer userInfo];
    CGFloat alpha = [window alphaValue];
    alpha -= (CGFloat)(3. / 30.);
    if (alpha < 0) {
        [window close];
        [timer invalidate];
    }
    else {
        [window setAlphaValue:alpha];
    }
}

- (void)updateSelectionPulse {
    double selectionPulseAmount = [[self representer] selectionPulseAmount];
    if (selectionPulseAmount == 0) {
        [[self window] removeChildWindow:pulseWindow];
        [pulseWindow setFrame:pulseWindowBaseFrameInScreenCoordinates display:YES animate:NO];
        [NSTimer scheduledTimerWithTimeInterval:1. / 30. target:self selector:@selector(fadePulseWindowTimer:) userInfo:pulseWindow repeats:YES];
        //release is not necessary, since it relases when closed by default
        pulseWindow = nil;
        pulseWindowBaseFrameInScreenCoordinates = NSZeroRect;
    }
    else {
        if (pulseWindow == nil) {
            NSArray *ranges = [self displayedSelectedContentsRanges];
            if ([ranges count] > 0) {
                NSWindow *thisWindow = [self window];
                NSRange firstRange = [[ranges objectAtIndex:0] rangeValue];
                NSRange lastRange = [[ranges lastObject] rangeValue];
                NSPoint startPoint = [self originForCharacterAtByteIndex:firstRange.location];
                // don't just use originForCharacterAtByteIndex:NSMaxRange(lastRange), because if the last selected character is at the end of the line, this will cause us to highlight the next line.  Instead, get the last selected character, and add an advance to it.
                //                HFASSERT(lastRange.length > 0);
                NSPoint endPoint;
                if (! NSEqualRanges(firstRange, lastRange)) {
                    endPoint = [self originForCharacterAtByteIndex:NSMaxRange(lastRange) - 1];
                }
                else {
                    endPoint = startPoint;
                }
                endPoint.x += [self advancePerByte];
                HFASSERT(endPoint.y >= startPoint.y);
                NSRect bounds = [self bounds];
                NSRect windowFrameInBoundsCoords;
                windowFrameInBoundsCoords.origin.x = bounds.origin.x;
                windowFrameInBoundsCoords.origin.y = startPoint.y;
                windowFrameInBoundsCoords.size.width = bounds.size.width;
                windowFrameInBoundsCoords.size.height = endPoint.y - startPoint.y + [self lineHeight];
                
                pulseWindowBaseFrameInScreenCoordinates = [self convertRect:windowFrameInBoundsCoords toView:nil];
                pulseWindowBaseFrameInScreenCoordinates.origin = [[self window] convertBaseToScreen:pulseWindowBaseFrameInScreenCoordinates.origin];
                
                pulseWindow = [[NSWindow alloc] initWithContentRect:pulseWindowBaseFrameInScreenCoordinates styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
                [pulseWindow setOpaque:NO];
                HFTextSelectionPulseView *pulseView = [[HFTextSelectionPulseView alloc] initWithFrame:[[pulseWindow contentView] frame]];
                [pulseWindow setContentView:pulseView];
                [pulseView release];
                
                /* Render our image at 200% of its current size */
                const CGFloat imageScale = 2;
                NSRect imageRect = (NSRect){NSZeroPoint, NSMakeSize(windowFrameInBoundsCoords.size.width * imageScale, windowFrameInBoundsCoords.size.height * imageScale)};
                NSImage *image = [[NSImage alloc] initWithSize:imageRect.size];
                [image setCacheMode:NSImageCacheNever];
                [image setFlipped:YES];
                [image lockFocus];
                CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
                CGContextClearRect(ctx, *(CGRect *)&imageRect);
                [self drawPulseBackgroundInRect:imageRect];
                [[NSColor blackColor] set];
                [[font screenFont] set];
                if (! [self shouldAntialias]) CGContextSetShouldAntialias(ctx, NO);
                CGContextScaleCTM(ctx, imageScale, imageScale);
                CGContextTranslateCTM(ctx, -windowFrameInBoundsCoords.origin.x, -windowFrameInBoundsCoords.origin.y);
                [self drawTextWithClip:windowFrameInBoundsCoords restrictingToTextInRanges:ranges];
                [image unlockFocus];
                [pulseView setImage:image];
                
                if (thisWindow) {
                    [thisWindow addChildWindow:pulseWindow ordered:NSWindowAbove];
                }
            }
        }
        
        if (pulseWindow) {
            CGFloat scale = (CGFloat)(selectionPulseAmount * .25 + 1.);
            NSRect scaledWindowFrame;
            scaledWindowFrame.size.width = HFRound(pulseWindowBaseFrameInScreenCoordinates.size.width * scale);
            scaledWindowFrame.size.height = HFRound(pulseWindowBaseFrameInScreenCoordinates.size.height * scale);
            scaledWindowFrame.origin.x = pulseWindowBaseFrameInScreenCoordinates.origin.x - HFRound(((scale - 1) * scaledWindowFrame.size.width / 2));
            scaledWindowFrame.origin.y = pulseWindowBaseFrameInScreenCoordinates.origin.y - HFRound(((scale - 1) * scaledWindowFrame.size.height / 2));
            [pulseWindow setFrame:scaledWindowFrame display:YES animate:NO];
        }
    }
}

- (void)drawCaretIfNecessaryWithClip:(NSRect)clipRect {
    NSRect caretRect = NSIntersectionRect(caretRectToDraw, clipRect);
    if (! NSIsEmptyRect(caretRect)) {
        [[NSColor blackColor] set];
        NSRectFill(caretRect);
        lastDrawnCaretRect = caretRect;
    }
    if (NSIsEmptyRect(caretRectToDraw)) lastDrawnCaretRect = NSZeroRect;
}

- (BOOL)shouldHaveForegroundHighlightColor {
    NSWindow *window = [self window];
    if (window == nil) return YES;
    if (! [window isKeyWindow]) return NO;
    if (self != [window firstResponder]) return NO;
    return YES;
}

- (void)drawSelectionIfNecessaryWithClip:(NSRect)clipRect {
    NSArray *ranges = [self displayedSelectedContentsRanges];
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSColor *textHighlightColor = ([self shouldHaveForegroundHighlightColor] ? [NSColor selectedTextBackgroundColor] : [NSColor colorWithCalibratedWhite: (CGFloat)(212./255.) alpha:1]);
    [textHighlightColor set];
    CGFloat lineHeight = [self lineHeight];
    FOREACH(NSValue *, rangeValue, ranges) {
        NSRange range = [rangeValue rangeValue];
        if (range.length > 0) {
            NSUInteger startCharacterIndex = range.location;
            NSUInteger endCharacterIndexForRange = range.location + range.length - 1;
            NSUInteger characterIndex = startCharacterIndex;
            while (characterIndex <= endCharacterIndexForRange) {
                NSUInteger endCharacterIndexForLine = ((characterIndex / bytesPerLine) + 1) * bytesPerLine - 1;
                NSUInteger endCharacterForThisLineOfRange = MIN(endCharacterIndexForRange, endCharacterIndexForLine);
                NSPoint startPoint = [self originForCharacterAtByteIndex:characterIndex];
                NSPoint endPoint = [self originForCharacterAtByteIndex:endCharacterForThisLineOfRange];
                NSRect selectionRect = NSMakeRect(startPoint.x, startPoint.y, endPoint.x + [self advancePerByte] - startPoint.x, lineHeight);
                NSRect clippedSelectionRect = NSIntersectionRect(selectionRect, clipRect);
                if (! NSIsEmptyRect(clippedSelectionRect)) {
                    NSRectFill(clippedSelectionRect);
                }
                characterIndex = endCharacterForThisLineOfRange + 1;
            }
        }
    }
}

- (void)pulseSelection {
    pulseStartTime = CFAbsoluteTimeGetCurrent();
    if (! pulseTimer) {
        pulseTimer = [[NSTimer scheduledTimerWithTimeInterval:(1. / 30.) target:self selector:@selector(pulseSelectionTimer:) userInfo:nil repeats:YES] retain];
    }
}

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)hasVisibleDisplayedSelectedContentsRange {
    FOREACH(NSValue *, rangeValue, [self displayedSelectedContentsRanges]) {
        NSRange range = [rangeValue rangeValue];
        if (range.length > 0) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)becomeFirstResponder {
    BOOL result = [super becomeFirstResponder];
    [self _updateCaretTimerWithFirstResponderStatus:YES];
    if ([self showsFocusRing] || [self hasVisibleDisplayedSelectedContentsRange]) {
        [self setNeedsDisplay:YES];
    }
    return result;
}

- (BOOL)resignFirstResponder {
    BOOL result = [super resignFirstResponder];
    [self _updateCaretTimerWithFirstResponderStatus:NO];
    BOOL needsRedisplay = NO;
    if ([self showsFocusRing]) needsRedisplay = YES;
    else if (! NSIsEmptyRect(lastDrawnCaretRect)) needsRedisplay = YES;
    else if ([self hasVisibleDisplayedSelectedContentsRange]) needsRedisplay = YES;
    if (needsRedisplay) [self setNeedsDisplay:YES];
    return result;
}

- initWithRepresenter:(HFTextRepresenter *)rep {
    [super initWithFrame:NSMakeRect(0, 0, 1, 1)];
    horizontalContainerInset = 4;
    representer = rep;
    _hftvflags.editable = YES;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:representer forKey:@"HFRepresenter"];
    [coder encodeObject:font forKey:@"HFFont"];
    [coder encodeObject:data forKey:@"HFData"];
    [coder encodeDouble:verticalOffset forKey:@"HFVerticalOffset"];
    [coder encodeDouble:horizontalContainerInset forKey:@"HFHorizontalContainerOffset"];
    [coder encodeDouble:defaultLineHeight forKey:@"HFDefaultLineHeight"];
    [coder encodeInt64:bytesBetweenVerticalGuides forKey:@"HFBytesBetweenVerticalGuides"];
    [coder encodeInt64:startingLineBackgroundColorIndex forKey:@"HFStartingLineBackgroundColorIndex"];
    [coder encodeObject:rowBackgroundColors forKey:@"HFRowBackgroundColors"];
    [coder encodeBool:_hftvflags.antialias forKey:@"HFAntialias"];
    [coder encodeBool:_hftvflags.editable forKey:@"HFEditable"];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    representer = [coder decodeObjectForKey:@"HFRepresenter"];
    font = [[coder decodeObjectForKey:@"HFFont"] retain];
    data = [[coder decodeObjectForKey:@"HFData"] retain];
    verticalOffset = (CGFloat)[coder decodeDoubleForKey:@"HFVerticalOffset"];
    horizontalContainerInset = (CGFloat)[coder decodeDoubleForKey:@"HFHorizontalContainerOffset"];
    defaultLineHeight = (CGFloat)[coder decodeDoubleForKey:@"HFDefaultLineHeight"];
    bytesBetweenVerticalGuides = (NSUInteger)[coder decodeInt64ForKey:@"HFBytesBetweenVerticalGuides"];
    startingLineBackgroundColorIndex = (NSUInteger)[coder decodeInt64ForKey:@"HFStartingLineBackgroundColorIndex"];
    rowBackgroundColors = [[coder decodeObjectForKey:@"HFRowBackgroundColors"] retain];
    _hftvflags.antialias = [coder decodeBoolForKey:@"HFAntialias"];
    _hftvflags.editable = [coder decodeBoolForKey:@"HFEditable"];
    return self;
}

- (CGFloat)horizontalContainerInset {
    return horizontalContainerInset;
}

- (void)setHorizontalContainerInset:(CGFloat)inset {
    horizontalContainerInset = inset;
}

- (void)setBytesBetweenVerticalGuides:(NSUInteger)val {
    bytesBetweenVerticalGuides = val;
}

- (NSUInteger)bytesBetweenVerticalGuides {
    return bytesBetweenVerticalGuides;
}


- (void)setFont:(NSFont *)val {
    if (val != font) {
        [font release];
        font = [val retain];
        NSLayoutManager *manager = [[NSLayoutManager alloc] init];
        defaultLineHeight = [manager defaultLineHeightForFont:font];
        [manager release];
        [self setNeedsDisplay:YES];
    }
}

- (CGFloat)lineHeight {
    return defaultLineHeight;
}

- (NSFont *)font {
    return font;
}

- (NSData *)data {
    return data;
}

- (void)setData:(NSData *)val {
    if (val != data) {
        NSUInteger oldLength = [data length];
        NSUInteger newLength = [val length];
        const unsigned char *oldBytes = (const unsigned char *)[data bytes];
        const unsigned char *newBytes = (const unsigned char *)[val bytes];
        NSUInteger firstDifferingIndex = HFIndexOfFirstByteThatDiffers(oldBytes, oldLength, newBytes, newLength);
        NSUInteger lastDifferingIndex = HFIndexOfLastByteThatDiffers(oldBytes, oldLength, newBytes, newLength);
        if (firstDifferingIndex == NSNotFound) {
            /* Nothing to do!  Data is identical! */
        }
        else {
            const NSUInteger bytesPerLine = [self bytesPerLine];
            const CGFloat lineHeight = [self lineHeight];
            CGFloat vertOffset = [self verticalOffset];
            NSUInteger lastLine = HFDivideULRoundingUp(MAX(oldLength, newLength), bytesPerLine);
            /* The +1 is for the following case - if we change the last character, then it may push the caret into the next line (even though there's no text there).  This last line may have a background color, so we need to make it draw if it did not draw before (or vice versa - when deleting the last character which pulls the caret from the last line). */
            NSUInteger lastDifferingLine = (lastDifferingIndex == NSNotFound ? lastLine : HFDivideULRoundingUp(lastDifferingIndex + 1, bytesPerLine));
            CGFloat lastDifferingLineBottom = (lastDifferingLine - vertOffset) * lineHeight;
            NSUInteger line = firstDifferingIndex / bytesPerLine;
            CGFloat yOrigin = (line - vertOffset) * lineHeight;
            NSRect bounds = [self bounds];
            NSRect dirtyRect = NSMakeRect(0, yOrigin, NSWidth(bounds), lastDifferingLineBottom - yOrigin);
            [self setNeedsDisplayInRect:dirtyRect];
        }
        [data release];
        data = [val copy];
        [self _updateCaretTimer];
    }
}

- (void)setVerticalOffset:(CGFloat)val {
    if (val != verticalOffset) {
        verticalOffset = val;
        [self setNeedsDisplay:YES];
    }
}

- (CGFloat)verticalOffset {
    return verticalOffset;
}

- (NSUInteger)startingLineBackgroundColorIndex {
    return startingLineBackgroundColorIndex;
}

- (void)setStartingLineBackgroundColorIndex:(NSUInteger)val {
    startingLineBackgroundColorIndex = val;
}

- (BOOL)isFlipped {
    return YES;
}

- (HFTextRepresenter *)representer {
    return representer;
}

- (void)dealloc {
    [caretTimer invalidate];
    [caretTimer release];
    [font release];
    [data release];
    [cachedSelectedRanges release];
    NSWindow *window = [self window];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (window) {
        [center removeObserver:self name:NSWindowDidBecomeKeyNotification object:window];
        [center removeObserver:self name:NSWindowDidResignKeyNotification object:window];        
    }
    if (_hftvflags.registeredForAppNotifications) {
        [center removeObserver:self name:NSApplicationDidBecomeActiveNotification object:nil];
        [center removeObserver:self name:NSApplicationDidResignActiveNotification object:nil];
    }
    [super dealloc];
}

- (NSColor *)backgroundColorForEmptySpace {
    NSArray *colors = [[self representer] rowBackgroundColors];
    if (! [colors count]) return [NSColor clearColor]; 
    else return [colors objectAtIndex:0];
}

- (NSColor *)backgroundColorForLine:(NSUInteger)line {
    NSArray *colors = [[self representer] rowBackgroundColors];
    NSUInteger colorCount = [colors count];
    if (colorCount == 0) return [NSColor clearColor];
    NSUInteger colorIndex = (line + startingLineBackgroundColorIndex) % colorCount;
    if (colorIndex == 0) return nil; //will be drawn by empty space
    else return [colors objectAtIndex:colorIndex]; 
}

- (NSUInteger)bytesPerLine {
    HFASSERT([self representer] != nil);
    return [[self representer] bytesPerLine];
}

- (NSUInteger)bytesPerColumn {
    HFASSERT([self representer] != nil);
    return [[self representer] bytesPerColumn];
}

- (void)_drawLineBackgrounds:(NSRect)clip withLineHeight:(CGFloat)lineHeight maxLines:(NSUInteger)maxLines {
    NSRect bounds = [self bounds];
    NSUInteger lineIndex;
    NSRect lineRect = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), lineHeight);
    if ([self showsFocusRing]) lineRect = NSInsetRect(lineRect, 2, 0);
    lineRect.origin.y -= [self verticalOffset] * [self lineHeight];
    NSUInteger drawableLineIndex = 0;
    NEW_ARRAY(NSRect, lineRects, maxLines);
    NEW_ARRAY(NSColor*, lineColors, maxLines);
    for (lineIndex = 0; lineIndex < maxLines; lineIndex++) {
        NSRect clippedLineRect = NSIntersectionRect(lineRect, clip);
        if (! NSIsEmptyRect(clippedLineRect)) {
            NSColor *lineColor = [self backgroundColorForLine:lineIndex];
            if (lineColor) {
                lineColors[drawableLineIndex] = lineColor;
                lineRects[drawableLineIndex] = clippedLineRect;
                drawableLineIndex++;
            }
        }
        lineRect.origin.y += lineHeight;
    }
    
    if (drawableLineIndex > 0) {
        NSRectFillListWithColorsUsingOperation(lineRects, lineColors, drawableLineIndex, NSCompositeSourceOver);
    }
    
    FREE_ARRAY(lineRects);
    FREE_ARRAY(lineColors);
}                              

/* Draw vertical guidelines every four bytes */
- (void)drawVerticalGuideLines:(NSRect)clip {
    if (bytesBetweenVerticalGuides == 0) return;
    
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSRect bounds = [self bounds];
    CGFloat advancePerByte = [self advancePerByte];
    CGFloat spaceAdvancement = advancePerByte / 2;
    CGFloat advanceAmount = (advancePerByte + spaceAdvancement) * bytesBetweenVerticalGuides;
    CGFloat lineOffset = (CGFloat)(NSMinX(bounds) + [self horizontalContainerInset] + advanceAmount - spaceAdvancement / 2.);
    CGFloat endOffset = NSMaxX(bounds) - [self horizontalContainerInset];
    
    NSUInteger numGuides = (bytesPerLine - 1) / bytesBetweenVerticalGuides; // -1 is a trick to avoid drawing the last line
    NSUInteger guideIndex = 0, rectIndex = 0;
    NEW_ARRAY(NSRect, lineRects, numGuides);
    
    while (lineOffset < endOffset && guideIndex < numGuides) {
        NSRect lineRect = NSMakeRect(lineOffset - 1, NSMinY(bounds), 1, NSHeight(bounds));
        NSRect clippedLineRect = NSIntersectionRect(lineRect, clip);
        if (! NSIsEmptyRect(clippedLineRect)) {
            lineRects[rectIndex++] = clippedLineRect;
        }
        lineOffset += advanceAmount;
        guideIndex++;
    }
    if (rectIndex > 0) {
        [[NSColor colorWithCalibratedWhite:(CGFloat).8 alpha:1] set];
        NSRectFillListUsingOperation(lineRects, rectIndex, NSCompositePlusDarker);
    }
    FREE_ARRAY(lineRects);
}

- (NSUInteger)maximumGlyphCountForByteCount:(NSUInteger)byteCount {
    USE(byteCount);
    UNIMPLEMENTED();
}

- (void)drawGlyphs:(CGGlyph *)glyphs withAdvances:(CGSize *)advances count:(NSUInteger)glyphCount {
    HFASSERT(glyphs != NULL);
    HFASSERT(advances != NULL);
    HFASSERT(glyphCount > 0);
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextShowGlyphsWithAdvances(ctx, glyphs, advances, glyphCount);
}


- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(CGGlyph *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    USE(bytes);
    USE(numBytes);
    USE(offsetIntoLine);
    USE(glyphs);
    USE(advances);
    USE(resultGlyphCount);
    UNIMPLEMENTED_VOID();
}

- (void)extractGlyphsForBytes:(const unsigned char *)bytePtr range:(NSRange)byteRange intoArray:(CGGlyph *)glyphs advances:(CGSize *)advances withInclusionRanges:(NSArray *)restrictingToRanges initialTextOffset:(CGFloat *)initialTextOffset resultingGlyphCount:(NSUInteger *)resultingGlyphCount {
    NSParameterAssert(glyphs != NULL && advances != NULL && restrictingToRanges != nil && bytePtr != NULL);
    NSRange priorIntersectionRange = {NSUIntegerMax, NSUIntegerMax};
    NSUInteger glyphBufferIndex = 0;
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSUInteger restrictionRangeCount = [restrictingToRanges count];
    for (NSUInteger rangeIndex = 0; rangeIndex < restrictionRangeCount; rangeIndex++) {
        NSRange inclusionRange = [[restrictingToRanges objectAtIndex:rangeIndex] rangeValue];
        NSRange intersectionRange = NSIntersectionRange(inclusionRange, byteRange);
        if (intersectionRange.length == 0) continue;
        
        NSUInteger offsetIntoLine = intersectionRange.location % bytesPerLine;
        
        NSRange byteRangeToSkip;
        if (priorIntersectionRange.location == NSUIntegerMax) {
            byteRangeToSkip = NSMakeRange(byteRange.location, intersectionRange.location - byteRange.location);
        }
        else {
            HFASSERT(intersectionRange.location >= NSMaxRange(priorIntersectionRange));
            byteRangeToSkip.location = NSMaxRange(priorIntersectionRange);
            byteRangeToSkip.length = intersectionRange.location - byteRangeToSkip.location;
        }
        
        if (byteRangeToSkip.length > 0) {
            CGFloat additionalAdvance = [self totalAdvanceForBytesInRange:byteRangeToSkip];
            if (glyphBufferIndex == 0) {
                *initialTextOffset = *initialTextOffset + additionalAdvance;
            }
            else {
                advances[glyphBufferIndex - 1].width += additionalAdvance;
            }
        }
        
        NSUInteger glyphCountForRange = NSUIntegerMax;
        [self extractGlyphsForBytes:bytePtr + intersectionRange.location count:intersectionRange.length offsetIntoLine:offsetIntoLine intoArray:glyphs + glyphBufferIndex advances:advances + glyphBufferIndex resultingGlyphCount:&glyphCountForRange];
        HFASSERT(glyphCountForRange != NSUIntegerMax);
        glyphBufferIndex += glyphCountForRange;
        priorIntersectionRange = intersectionRange;
    }
    if (resultingGlyphCount) *resultingGlyphCount = glyphBufferIndex;
}

- (void)drawTextWithClip:(NSRect)clip restrictingToTextInRanges:(NSArray *)restrictingToRanges {
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    NSRect bounds = [self bounds];
    CGFloat lineHeight = [self lineHeight];
    
    CGAffineTransform textTransform = CGContextGetTextMatrix(ctx);
    CGContextSetTextDrawingMode(ctx, kCGTextFill);
    
    NSUInteger byteIndex, bytesPerLine = [self bytesPerLine];
    NSData *dataObject = [self data];
    NSFont *fontObject = [[self font] screenFont];
    NSUInteger byteCount = [dataObject length];
    
    const unsigned char * const bytePtr = [dataObject bytes];
    
    NSRect lineRectInBoundsSpace = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), lineHeight);
    lineRectInBoundsSpace.origin.y -= [self verticalOffset] * lineHeight;
    
    /* Start us off with the horizontal inset and move the baseline down by the ascender so our glyphs just graze the top of our view */
    textTransform.tx += [self horizontalContainerInset];
    textTransform.ty += [fontObject ascender] - lineHeight * [self verticalOffset];
    NSUInteger lineIndex = 0;
    const NSUInteger maxGlyphCount = [self maximumGlyphCountForByteCount:bytesPerLine];
    NEW_ARRAY(CGGlyph, glyphs, maxGlyphCount);
    NEW_ARRAY(CGSize, advances, maxGlyphCount);
    for (byteIndex = 0; byteIndex < byteCount; byteIndex += bytesPerLine) {
        if (byteIndex > 0) {
            textTransform.ty += lineHeight;
            lineRectInBoundsSpace.origin.y += lineHeight;
        }
        if (NSIntersectsRect(lineRectInBoundsSpace, clip)) {
            NSUInteger numBytes = MIN(bytesPerLine, byteCount - byteIndex);
            NSUInteger resultGlyphCount = 0;
            CGFloat initialTextOffset = 0;
            if (restrictingToRanges == nil) {
                [self extractGlyphsForBytes:bytePtr + byteIndex count:numBytes offsetIntoLine:0 intoArray:glyphs advances:advances resultingGlyphCount:&resultGlyphCount];
            }
            else {
                [self extractGlyphsForBytes:bytePtr range:NSMakeRange(byteIndex, numBytes) intoArray:glyphs advances:advances withInclusionRanges:restrictingToRanges initialTextOffset:&initialTextOffset resultingGlyphCount:&resultGlyphCount];
            }
            HFASSERT(resultGlyphCount <= maxGlyphCount);
            
            if (resultGlyphCount > 0) {
                textTransform.tx += initialTextOffset;
                CGContextSetTextMatrix(ctx, textTransform);
                textTransform.tx -= initialTextOffset;
                [self drawGlyphs:glyphs withAdvances:advances count:resultGlyphCount];
            }
        }
        else if (NSMinY(lineRectInBoundsSpace) > NSMaxY(clip)) {
            break;
        }
        lineIndex++;
    }
    FREE_ARRAY(glyphs);
    FREE_ARRAY(advances);
}


- (void)drawFocusRingWithClip:(NSRect)clip {
    USE(clip);
    [NSGraphicsContext saveGraphicsState];
    NSSetFocusRingStyle(NSFocusRingOnly);
    [[NSColor clearColor] set];
    NSRectFill([self bounds]);
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawRect:(NSRect)clip {
    [[self backgroundColorForEmptySpace] set];
    NSRectFillUsingOperation(clip, NSCompositeSourceOver);
    BOOL antialias = [self shouldAntialias];
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    
    if ([self showsFocusRing]) {
        NSWindow *window = [self window];
        if (self == [window firstResponder] && [window isKeyWindow]) {
            [self drawFocusRingWithClip:clip];
        }
    }
    
    NSUInteger bytesPerLine = [self bytesPerLine];
    if (bytesPerLine == 0) return;
    NSUInteger byteCount = [data length];
    [[font screenFont] set];
    
    [self _drawLineBackgrounds:clip withLineHeight:[self lineHeight] maxLines:ll2l(HFRoundUpToNextMultiple(byteCount, bytesPerLine) / bytesPerLine)];
    [self drawSelectionIfNecessaryWithClip:clip];
    
    NSColor *textColor = [NSColor blackColor];
    [textColor set];
    
    if (! antialias) {
        CGContextSaveGState(ctx);
        CGContextSetShouldAntialias(ctx, NO);
    }
    [self drawTextWithClip:clip restrictingToTextInRanges:nil];
    if (! antialias) {
        CGContextRestoreGState(ctx);
    }
    
    // Vertical dividers only make sense in single byte mode.
    if ([self bytesPerColumn] == 1) {
        [self drawVerticalGuideLines:clip];
    }
    
    [self drawCaretIfNecessaryWithClip:clip];
}

- (NSUInteger)availableLineCount {
    CGFloat result = (CGFloat)ceil(NSHeight([self bounds]) / [self lineHeight]);
    HFASSERT(result >= 0.);
    HFASSERT(result <= NSUIntegerMax);
    return (NSUInteger)result;
}

- (double)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
    return viewHeight / [self lineHeight];
}

- (void)setFrameSize:(NSSize)size {
    NSUInteger currentBytesPerLine = [self bytesPerLine];
    double currentLineCount = [self maximumAvailableLinesForViewHeight:NSHeight([self bounds])];
    [super setFrameSize:size];
    NSUInteger newBytesPerLine = [self maximumBytesPerLineForViewWidth:size.width];
    double newLineCount = [self maximumAvailableLinesForViewHeight:NSHeight([self bounds])];
    HFControllerPropertyBits bits = 0;
    if (newBytesPerLine != currentBytesPerLine) bits |= (HFControllerBytesPerLine | HFControllerDisplayedLineRange);
    if (newLineCount != currentLineCount) bits |= HFControllerDisplayedLineRange;
    if (bits) [[self representer] representerChangedProperties:bits];
}

- (CGFloat)advancePerByte {
    UNIMPLEMENTED();
}

- (CGFloat)advanceBetweenColumns {
    UNIMPLEMENTED();
}

- (CGFloat)advancePerColumn {
    NSUInteger bytesPerColumn = [self bytesPerColumn];
    if (bytesPerColumn == 0) {
        return 0;
    }
    else {
        return [self advancePerByte] * [self bytesPerColumn] + [self advanceBetweenColumns];
    }
}

- (CGFloat)totalAdvanceForBytesInRange:(NSRange)range {
    if (range.length == 0) return 0;
    NSUInteger bytesPerColumn = [self bytesPerColumn];
    HFASSERT(bytesPerColumn == 0 || [self bytesPerLine] % bytesPerColumn == 0);
    CGFloat result = range.length * [self advancePerByte];
    if (bytesPerColumn > 0) {
        NSUInteger numColumnSpaces = NSMaxRange(range) / bytesPerColumn - range.location / bytesPerColumn; //note that integer division does not distribute
        result += numColumnSpaces * [self advanceBetweenColumns];
    }
    return result;
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    CGFloat availableSpace = (CGFloat)(viewWidth - 2. * [self horizontalContainerInset]);
    NSUInteger bytesPerColumn = [self bytesPerColumn];
    if (bytesPerColumn == 0) {
        return (NSUInteger)fmax(1., availableSpace / [self advancePerByte]);
    }
    else {
        CGFloat advancePerColumn = [self advancePerColumn];
        //spaceRequiredForNColumns = N * (advancePerColumn) - spaceBetweenColumns
        CGFloat fractionalColumns = (availableSpace + [self advanceBetweenColumns]) / advancePerColumn;
        NSUInteger columnCount = (NSUInteger)fmax(1., HFFloor(fractionalColumns));
        return columnCount * [self bytesPerColumn];
    }
}


- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    HFASSERT(bytesPerLine > 0);
    NSUInteger bytesPerColumn = [self bytesPerColumn];
    if (bytesPerColumn == 0) {
        return (CGFloat)((2. * [self horizontalContainerInset]) + bytesPerLine * [self advancePerByte]);
    }
    else {
        HFASSERT(bytesPerLine % [self bytesPerColumn] == 0);
        return (CGFloat)((2. * [self horizontalContainerInset]) + [self advancePerColumn] * (bytesPerLine / [self bytesPerColumn]) - [self advanceBetweenColumns]);
    }
}

- (BOOL)isEditable {
    return _hftvflags.editable;
}

- (void)setEditable:(BOOL)val {
    if (val != _hftvflags.editable) {
        _hftvflags.editable = val;
        [self _updateCaretTimer];
    }
}

- (BOOL)shouldAntialias {
    return _hftvflags.antialias;
}

- (void)setShouldAntialias:(BOOL)val {
    _hftvflags.antialias = !!val;
    [self setNeedsDisplay:YES];
}

- (BOOL)behavesAsTextField {
    return [[self representer] behavesAsTextField];
}

- (BOOL)showsFocusRing {
    return [[self representer] behavesAsTextField];
}

- (BOOL)isWithinMouseDown {
    return _hftvflags.withinMouseDown;
}

- (void)_windowDidChangeKeyStatus:(NSNotification *)note {
    USE(note);
    [self _updateCaretTimer];
    if ([[note name] isEqualToString:NSWindowDidBecomeKeyNotification]) {
        [self _forceCaretOnIfHasCaretTimer];
    }
    if ([self showsFocusRing] && self == [[self window] firstResponder]) {
        [[self superview] setNeedsDisplayInRect:NSInsetRect([self frame], -6, -6)];
    }
    [self setNeedsDisplay:YES];
}

- (void)viewDidMoveToWindow {
    [self _updateCaretTimer];
    NSWindow *newWindow = [self window];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (newWindow) {
        [center addObserver:self selector:@selector(_windowDidChangeKeyStatus:) name:NSWindowDidBecomeKeyNotification object:newWindow];
        [center addObserver:self selector:@selector(_windowDidChangeKeyStatus:) name:NSWindowDidResignKeyNotification object:newWindow];
    }
    if (! _hftvflags.registeredForAppNotifications) {
        [center addObserver:self selector:@selector(_windowDidChangeKeyStatus:) name:NSApplicationDidBecomeActiveNotification object:nil];
        [center addObserver:self selector:@selector(_windowDidChangeKeyStatus:) name:NSApplicationDidResignActiveNotification object:nil];        
        _hftvflags.registeredForAppNotifications = YES;
    }
    [super viewDidMoveToWindow];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    USE(newWindow);
    NSWindow *oldWindow = [self window];
    if (oldWindow) {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center removeObserver:self name:NSWindowDidBecomeKeyNotification object:oldWindow];
        [center removeObserver:self name:NSWindowDidResignKeyNotification object:oldWindow];
    }
}

/* Computes the character at the given index for selection, properly handling the case where the point is outside the bounds */
- (NSUInteger)characterAtPointForSelection:(NSPoint)point {
    NSPoint mungedPoint = point;
    // shift us right by half an advance so that we trigger at the midpoint of each character, rather than at the x origin
    mungedPoint.x += [self advancePerByte] / (CGFloat)2.;
    // make sure we're inside the bounds
    const NSRect bounds = [self bounds];
    mungedPoint.x = HFMax(NSMinX(bounds), mungedPoint.x);
    mungedPoint.x = HFMin(NSMaxX(bounds), mungedPoint.x);
    mungedPoint.y = HFMax(NSMinY(bounds), mungedPoint.y);
    mungedPoint.y = HFMin(NSMaxY(bounds), mungedPoint.y);
    return [self indexOfCharacterAtPoint:mungedPoint];
}

- (void)mouseDown:(NSEvent *)event {
    HFASSERT(_hftvflags.withinMouseDown == 0);
    _hftvflags.withinMouseDown = 1;
    [self _forceCaretOnIfHasCaretTimer];
    NSPoint mouseDownLocation = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self characterAtPointForSelection:mouseDownLocation];
    characterIndex = MIN(characterIndex, [[self data] length]); //characterIndex may be one beyond the last index, to represent the cursor at the end of the document
    [[self representer] beginSelectionWithEvent:event forCharacterIndex:characterIndex];
    
    /* Drive the event loop in event tracking mode until we're done */
    HFASSERT(_hftvflags.receivedMouseUp == NO); //paranoia - detect any weird recursive invocations
    NSDate *endDate = [NSDate distantFuture];
    
    /* Start periodic events for autoscroll */
    [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.05];
    
    NSPoint autoscrollLocation = mouseDownLocation;
    while (! _hftvflags.receivedMouseUp) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSEvent *event = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask untilDate:endDate inMode:NSEventTrackingRunLoopMode dequeue:YES];
	
	if ([event type] == NSPeriodic) {
	    // autoscroll if drag is out of view bounds
	    CGFloat amountToScroll = 0;
	    NSRect bounds = [self bounds];
	    if (autoscrollLocation.y < NSMinY(bounds)) {
		amountToScroll = (autoscrollLocation.y - NSMinY(bounds)) / [self lineHeight];
	    }
	    else if (autoscrollLocation.y > NSMaxY(bounds)) {
		amountToScroll = (autoscrollLocation.y - NSMaxY(bounds)) / [self lineHeight];
	    }
	    if (amountToScroll != 0.) {
		[[[self representer] controller] scrollByLines:amountToScroll];
		NSUInteger characterIndex = [self characterAtPointForSelection:autoscrollLocation];
		characterIndex = MIN(characterIndex, [[self data] length]);
		[[self representer] continueSelectionWithEvent:event forCharacterIndex:characterIndex];
	    }
	}
	else if ([event type] == NSLeftMouseDragged) {
	    autoscrollLocation = [self convertPoint:[event locationInWindow] fromView:nil];
	}
	
        [NSApp sendEvent:event]; 
        [pool drain];
    }
    
    [NSEvent stopPeriodicEvents];
    
    _hftvflags.receivedMouseUp = NO;
    _hftvflags.withinMouseDown = 0;
}

- (void)mouseDragged:(NSEvent *)event {
    if (! _hftvflags.withinMouseDown) return;
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self characterAtPointForSelection:location];
    characterIndex = MIN(characterIndex, [[self data] length]);
    [[self representer] continueSelectionWithEvent:event forCharacterIndex:characterIndex];    
}

- (void)mouseUp:(NSEvent *)event {
    if (! _hftvflags.withinMouseDown) return;
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self characterAtPointForSelection:location];
    characterIndex = MIN(characterIndex, [[self data] length]);
    [[self representer] endSelectionWithEvent:event forCharacterIndex:characterIndex];
    _hftvflags.receivedMouseUp = YES;
}

- (void)keyDown:(NSEvent *)event {
    HFASSERT(event != NULL);
    [self interpretKeyEvents:[NSArray arrayWithObject:event]];
}

- (void)scrollWheel:(NSEvent *)event {
    [[self representer] scrollWheel:event];
}

- (void)insertText:(id)string {
    if (! [self isEditable]) {
        NSBeep();
    }
    else {
        if ([string isKindOfClass:[NSAttributedString class]]) string = [string string];
        [NSCursor setHiddenUntilMouseMoves:YES];
        [[self representer] insertText:string];
    }
}

- (BOOL)handleCommand:(SEL)sel {
    if (sel == @selector(insertTabIgnoringFieldEditor:)) {
        [self insertText:@"\t"];
    }
    else if ([self respondsToSelector:sel]) {
        [self performSelector:sel withObject:nil];
    }
    else {
        return NO;
    }
    return YES;
}

- (void)doCommandBySelector:(SEL)sel {
    HFRepresenter *rep = [self representer];
    //    NSLog(@"%s%s", _cmd, sel);
    if ([self handleCommand:sel]) {
        /* Nothing to do */
    }
    else if ([rep respondsToSelector:sel]) {
        [rep performSelector:sel withObject:self];
    }
    else {
        [super doCommandBySelector:sel];
    }
}

- (IBAction)selectAll:sender {
    [[self representer] selectAll:sender];
}

/* Indicates whether at least one byte is selected */
- (BOOL)_selectionIsNonEmpty {
    NSArray *selection = [[[self representer] controller] selectedContentsRanges];
    FOREACH(HFRangeWrapper *, rangeWrapper, selection) {
        if ([rangeWrapper HFRange].length > 0) return YES;
    }
    return NO;
}

- (SEL)_pasteboardOwnerStringTypeWritingSelector {
    UNIMPLEMENTED();
}

- (void)paste:sender {
    if (! [self isEditable]) {
        NSBeep();
    }
    else {
        USE(sender);
        [[self representer] pasteBytesFromPasteboard:[NSPasteboard generalPasteboard]];
    }
}

- (void)copy:sender {
    USE(sender);
    [[self representer] copySelectedBytesToPasteboard:[NSPasteboard generalPasteboard]];
}

- (void)cut:sender {
    USE(sender);
    [[self representer] cutSelectedBytesToPasteboard:[NSPasteboard generalPasteboard]];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    SEL action = [item action];
    if (action == @selector(selectAll:)) return YES;
    else if (action == @selector(cut:)) return [[self representer] canCut];
    else if (action == @selector(copy:)) return [self _selectionIsNonEmpty];
    else if (action == @selector(paste:)) return [[self representer] canPasteFromPasteboard:[NSPasteboard generalPasteboard]];
    else return YES;
}

@end
