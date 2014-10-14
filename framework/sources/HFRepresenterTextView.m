//
//  HFRepresenterTextView.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView_Internal.h>
#import <HexFiend/HFTextRepresenter_Internal.h>
#import <HexFiend/HFTextSelectionPulseView.h>
#import <HexFiend/HFTextVisualStyleRun.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFRepresenterTextViewCallout.h>
#import <objc/message.h>

static const NSTimeInterval HFCaretBlinkFrequency = 0.56;

static const CGFloat HFTeardropRadius = 12;

@implementation HFRepresenterTextView

- (NSUInteger)_getGlyphs:(CGGlyph *)glyphs forString:(NSString *)string font:(NSFont *)inputFont {
    NSUInteger length = [string length];
    UniChar chars[256];
    HFASSERT(length <= sizeof chars / sizeof *chars);
    HFASSERT(inputFont != nil);
    [string getCharacters:chars range:NSMakeRange(0, length)];
    if (! CTFontGetGlyphsForCharacters((CTFontRef)inputFont, chars, glyphs, length)) {
        /* Some or all characters were not mapped.  This is OK.  We'll use the replacement glyph. */
    }
    return length;
}

- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingLayoutManager:(NSLayoutManager *)layoutManager glyphs:(CGGlyph *)glyphs {
    HFASSERT(layoutManager != NULL);
    HFASSERT(string != NULL);
    NSGlyph nsglyphs[GLYPH_BUFFER_SIZE];
    [[[layoutManager textStorage] mutableString] setString:string];
    NSUInteger glyphIndex, glyphCount = [layoutManager getGlyphs:nsglyphs range:NSMakeRange(0, MIN(GLYPH_BUFFER_SIZE, [layoutManager numberOfGlyphs]))];
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

/* Returns the number of glyphs for the given string, using the given text view, and generating the glyphs if the glyphs parameter is not NULL */
- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingTextView:(NSTextView *)textView glyphs:(CGGlyph *)glyphs {
    HFASSERT(string != NULL);
    HFASSERT(textView != NULL);
    [textView setString:string];
    [textView setNeedsDisplay:YES]; //ligature generation doesn't seem to happen without this, for some reason.  This seems very fragile!  We should find a better way to get this ligature information!!
    return [self _glyphsForString:string withGeneratingLayoutManager:[textView layoutManager] glyphs:glyphs];
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
    NSRange range = [ranges[0] rangeValue];
    if (range.length != 0) return NO;
    return YES;
}

- (NSUInteger)_effectiveBytesPerColumn {
    /* returns the bytesPerColumn, unless it's larger than the bytes per character, in which case it returns 0 */
    NSUInteger bytesPerColumn = [self bytesPerColumn], bytesPerCharacter = [self bytesPerCharacter];
    return bytesPerColumn >= bytesPerCharacter ? bytesPerColumn : 0;
}

// note: index may be negative
- (NSPoint)originForCharacterAtByteIndex:(NSInteger)index {
    NSPoint result;
    NSInteger bytesPerLine = (NSInteger)[self bytesPerLine];
    
    // We want a nonnegative remainder
    NSInteger lineIndex = index / bytesPerLine;
    NSInteger byteIndexIntoLine = index % bytesPerLine;
    while (byteIndexIntoLine < 0) {
        byteIndexIntoLine += bytesPerLine;
        lineIndex--;
    }

    NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn];
    NSUInteger numConsumedColumns = (bytesPerColumn ? byteIndexIntoLine / bytesPerColumn : 0);
    NSUInteger characterIndexIntoLine = byteIndexIntoLine / [self bytesPerCharacter];
    
    result.x = [self horizontalContainerInset] + characterIndexIntoLine * [self advancePerCharacter] + numConsumedColumns * [self advanceBetweenColumns];
    result.y = (lineIndex - [self verticalOffset]) * [self lineHeight];
    
    return result;
}

- (NSUInteger)indexOfCharacterAtPoint:(NSPoint)point {
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSUInteger bytesPerCharacter = [self bytesPerCharacter];
    HFASSERT(bytesPerLine % bytesPerCharacter == 0);
    CGFloat advancePerCharacter = [self advancePerCharacter];
    NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn];
    CGFloat floatRow = (CGFloat)floor([self verticalOffset] + point.y / [self lineHeight]);
    NSUInteger byteIndexWithinRow;
    
    // to compute the column, we need to solve for byteIndexIntoLine in something like this: point.x = [self advancePerCharacter] * charIndexIntoLine + [self spaceBetweenColumns] * floor(byteIndexIntoLine / [self bytesPerColumn]).  Start by computing the column (or if bytesPerColumn is 0, we don't have columns)
    CGFloat insetX = point.x - [self horizontalContainerInset];
    if (insetX < 0) {
        //handle the case of dragging within the container inset
        byteIndexWithinRow = 0;
    }
    else if (bytesPerColumn == 0) {
        /* We don't have columns */
        byteIndexWithinRow = bytesPerCharacter * (NSUInteger)(insetX / advancePerCharacter);
    }
    else {
        CGFloat advancePerColumn = [self advancePerColumn];
        HFASSERT(advancePerColumn > 0);
        CGFloat floatColumn = insetX / advancePerColumn;
        HFASSERT(floatColumn >= 0 && floatColumn <= NSUIntegerMax);
        CGFloat startOfColumn = advancePerColumn * HFFloor(floatColumn);
        HFASSERT(startOfColumn <= insetX);
        CGFloat xOffsetWithinColumn = insetX - startOfColumn;
        CGFloat charIndexWithinColumn = xOffsetWithinColumn / advancePerCharacter; //charIndexWithinColumn may be larger than bytesPerColumn if the user clicked on the space between columns
        HFASSERT(charIndexWithinColumn >= 0 && charIndexWithinColumn <= NSUIntegerMax / bytesPerCharacter);
        NSUInteger byteIndexWithinColumn = bytesPerCharacter * (NSUInteger)charIndexWithinColumn;
        byteIndexWithinRow = bytesPerColumn * (NSUInteger)floatColumn + byteIndexWithinColumn; //this may trigger overflow to the next column, but that's OK
        byteIndexWithinRow = MIN(byteIndexWithinRow, bytesPerLine); //don't let clicking to the right of the line overflow to the next line
    }
    HFASSERT(floatRow >= 0 && floatRow <= NSUIntegerMax);
    NSUInteger row = (NSUInteger)floatRow;
    return (row * bytesPerLine + byteIndexWithinRow) / bytesPerCharacter;
}

- (NSRect)caretRect {
    NSArray *ranges = [self displayedSelectedContentsRanges];
    HFASSERT([ranges count] == 1);
    NSRange range = [ranges[0] rangeValue];
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
        if ([self enclosingMenuItem] != NULL) {
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
    
    // A new pulse window will be created at the new selected range if necessary.
    [self terminateSelectionPulse];
}

- (void)drawPulseBackgroundInRect:(NSRect)pulseRect {
    [[NSColor yellowColor] set];
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSaveGState(ctx);
    [[NSBezierPath bezierPathWithRoundedRect:pulseRect xRadius:25 yRadius:25] addClip];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:[NSColor yellowColor] endingColor:[NSColor colorWithCalibratedRed:(CGFloat)1. green:(CGFloat).75 blue:0 alpha:1]];
    [gradient drawInRect:pulseRect angle:90];
    [gradient release];
    CGContextRestoreGState(ctx);
}

- (void)fadePulseWindowTimer:(NSTimer *)timer {
    // TODO: close & invalidate immediatley if view scrolls.
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

- (void)terminateSelectionPulse {
    if (pulseWindow) {
        [[self window] removeChildWindow:pulseWindow];
        [pulseWindow setFrame:pulseWindowBaseFrameInScreenCoordinates display:YES animate:NO];
        [NSTimer scheduledTimerWithTimeInterval:1. / 30. target:self selector:@selector(fadePulseWindowTimer:) userInfo:pulseWindow repeats:YES];
        //release is not necessary, since it relases when closed by default
        pulseWindow = nil;
        pulseWindowBaseFrameInScreenCoordinates = NSZeroRect;
    }
}

- (void)updateSelectionPulse {
    double selectionPulseAmount = [[self representer] selectionPulseAmount];
    if (selectionPulseAmount == 0) {
        [self terminateSelectionPulse];
    }
    else {
        if (pulseWindow == nil) {
            NSArray *ranges = [self displayedSelectedContentsRanges];
            if ([ranges count] > 0) {
                NSWindow *thisWindow = [self window];
                NSRange firstRange = [ranges[0] rangeValue];
                NSRange lastRange = [[ranges lastObject] rangeValue];
                BOOL emptySelection = [ranges count] == 1 && firstRange.length == 0;
                NSPoint startPoint = [self originForCharacterAtByteIndex:firstRange.location];
                // don't just use originForCharacterAtByteIndex:NSMaxRange(lastRange), because if the last selected character is at the end of the line, this will cause us to highlight the next line.  Instead, get the last selected character, and add an advance to it.
                NSPoint endPoint = [self originForCharacterAtByteIndex:NSMaxRange(lastRange) - 1];
                endPoint.x += [self advancePerCharacter];
                HFASSERT(endPoint.y >= startPoint.y);
                NSRect bounds = [self bounds];
                NSRect windowFrameInBoundsCoords;
                if (emptySelection) {
                    CGFloat w = (CGFloat)fmax([self advancePerColumn], [self advancePerCharacter]);
                    windowFrameInBoundsCoords.origin.x = startPoint.x - w/2;
                    windowFrameInBoundsCoords.size.width = w;
                } else {
                    windowFrameInBoundsCoords.origin.x = bounds.origin.x;
                    windowFrameInBoundsCoords.size.width = bounds.size.width;
                }
                windowFrameInBoundsCoords.origin.y = startPoint.y;
                windowFrameInBoundsCoords.size.height = endPoint.y - startPoint.y + [self lineHeight];
                
                pulseWindowBaseFrameInScreenCoordinates = [self convertRect:windowFrameInBoundsCoords toView:nil];
                pulseWindowBaseFrameInScreenCoordinates.origin = [[self window] convertRectToScreen:pulseWindowBaseFrameInScreenCoordinates].origin;
                
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
                [image lockFocusFlipped:YES];
                CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
                CGContextClearRect(ctx, *(CGRect *)&imageRect);
                [self drawPulseBackgroundInRect:imageRect];
                [[NSColor blackColor] set];
                [[self.font screenFont] set];
                if (! [self shouldAntialias]) CGContextSetShouldAntialias(ctx, NO);
                CGContextScaleCTM(ctx, imageScale, imageScale);
                CGContextTranslateCTM(ctx, -windowFrameInBoundsCoords.origin.x, -windowFrameInBoundsCoords.origin.y);
                [self drawTextWithClip:windowFrameInBoundsCoords restrictingToTextInRanges:ranges];
                [image unlockFocus];
                [pulseView setImage:image];
                [image release];
                
                if (thisWindow) {
                    [thisWindow addChildWindow:pulseWindow ordered:NSWindowAbove];
                }
            }
        }
        
        if (pulseWindow) {
            CGFloat scale = (CGFloat)(1. + .08 * selectionPulseAmount);
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


/* This is the color when we are the first responder in the key window */
- (NSColor *)primaryTextSelectionColor {
    return [NSColor selectedTextBackgroundColor];
}

/* This is the color when we are not in the key window */
- (NSColor *)inactiveTextSelectionColor {
    return [NSColor colorWithCalibratedWhite: (CGFloat)(212./255.) alpha:1];
}

/* This is the color when we are not the first responder, but we are in the key window */
- (NSColor *)secondaryTextSelectionColor {
    return [[self primaryTextSelectionColor] blendedColorWithFraction:.66 ofColor:[NSColor colorWithCalibratedWhite:.8f alpha:1]];
}

- (NSColor *)textSelectionColor {
    NSWindow *window = [self window];
    if (window == nil) return [self primaryTextSelectionColor];
    else if (! [window isKeyWindow]) return [self inactiveTextSelectionColor];
    else if (self != [window firstResponder]) return [self secondaryTextSelectionColor];
    else return [self primaryTextSelectionColor];
}

- (void)drawSelectionIfNecessaryWithClip:(NSRect)clipRect {
    NSArray *ranges = [self displayedSelectedContentsRanges];
    NSUInteger bytesPerLine = [self bytesPerLine];
    [[self textSelectionColor] set];
    CGFloat lineHeight = [self lineHeight];
    FOREACH(NSValue *, rangeValue, ranges) {
        NSRange range = [rangeValue rangeValue];
        if (range.length > 0) {
            NSUInteger startByteIndex = range.location;
            NSUInteger endByteIndexForThisRange = range.location + range.length - 1;
            NSUInteger byteIndex = startByteIndex;
            while (byteIndex <= endByteIndexForThisRange) {
                NSUInteger endByteIndexForLine = ((byteIndex / bytesPerLine) + 1) * bytesPerLine - 1;
                NSUInteger endByteForThisLineOfRange = MIN(endByteIndexForThisRange, endByteIndexForLine);
                NSPoint startPoint = [self originForCharacterAtByteIndex:byteIndex];
                NSPoint endPoint = [self originForCharacterAtByteIndex:endByteForThisLineOfRange];
                NSRect selectionRect = NSMakeRect(startPoint.x, startPoint.y, endPoint.x + [self advancePerCharacter] - startPoint.x, lineHeight);
                NSRect clippedSelectionRect = NSIntersectionRect(selectionRect, clipRect);
                if (! NSIsEmptyRect(clippedSelectionRect)) {
                    NSRectFill(clippedSelectionRect);
                }
                byteIndex = endByteForThisLineOfRange + 1;
            }
        }
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

- (instancetype)initWithRepresenter:(HFTextRepresenter *)rep {
    self = [super initWithFrame:NSMakeRect(0, 0, 1, 1)];
    horizontalContainerInset = 4;
    representer = rep;
    _hftvflags.editable = YES;
    
    return self;
}

- (void)clearRepresenter {
    representer = nil;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:representer forKey:@"HFRepresenter"];
    [coder encodeObject:_font forKey:@"HFFont"];
    [coder encodeObject:_data forKey:@"HFData"];
    [coder encodeDouble:verticalOffset forKey:@"HFVerticalOffset"];
    [coder encodeDouble:horizontalContainerInset forKey:@"HFHorizontalContainerOffset"];
    [coder encodeDouble:defaultLineHeight forKey:@"HFDefaultLineHeight"];
    [coder encodeInt64:bytesBetweenVerticalGuides forKey:@"HFBytesBetweenVerticalGuides"];
    [coder encodeInt64:startingLineBackgroundColorIndex forKey:@"HFStartingLineBackgroundColorIndex"];
    [coder encodeObject:rowBackgroundColors forKey:@"HFRowBackgroundColors"];
    [coder encodeBool:_hftvflags.antialias forKey:@"HFAntialias"];
    [coder encodeBool:_hftvflags.drawCallouts forKey:@"HFDrawCallouts"];
    [coder encodeBool:_hftvflags.editable forKey:@"HFEditable"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    representer = [coder decodeObjectForKey:@"HFRepresenter"];
    _font = [[coder decodeObjectForKey:@"HFFont"] retain];
    _data = [[coder decodeObjectForKey:@"HFData"] retain];
    verticalOffset = (CGFloat)[coder decodeDoubleForKey:@"HFVerticalOffset"];
    horizontalContainerInset = (CGFloat)[coder decodeDoubleForKey:@"HFHorizontalContainerOffset"];
    defaultLineHeight = (CGFloat)[coder decodeDoubleForKey:@"HFDefaultLineHeight"];
    bytesBetweenVerticalGuides = (NSUInteger)[coder decodeInt64ForKey:@"HFBytesBetweenVerticalGuides"];
    startingLineBackgroundColorIndex = (NSUInteger)[coder decodeInt64ForKey:@"HFStartingLineBackgroundColorIndex"];
    rowBackgroundColors = [[coder decodeObjectForKey:@"HFRowBackgroundColors"] retain];
    _hftvflags.antialias = [coder decodeBoolForKey:@"HFAntialias"];
    _hftvflags.drawCallouts = [coder decodeBoolForKey:@"HFDrawCallouts"];
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
    if (val != _font) {
        [_font release];
        _font = [val retain];
        NSLayoutManager *manager = [[NSLayoutManager alloc] init];
        defaultLineHeight = [manager defaultLineHeightForFont:_font];
        [manager release];
        [self setNeedsDisplay:YES];
    }
}

- (CGFloat)lineHeight {
    return defaultLineHeight;
}

/* The base implementation does not support font substitution, so we require that it be the base font. */
- (NSFont *)fontAtSubstitutionIndex:(uint16_t)idx {
    HFASSERT(idx == 0);
    USE(idx);
    return _font;
}

- (NSRange)roundPartialByteRange:(NSRange)byteRange {
    NSUInteger bytesPerCharacter = [self bytesPerCharacter];
    /* Get the left and right edges of the range */
    NSUInteger left = byteRange.location, right = NSMaxRange(byteRange);
    
    /* Round both to the left.  This may make the range bigger or smaller, or empty! */
    left -= left % bytesPerCharacter;
    right -= right % bytesPerCharacter;
    
    /* Done */
    HFASSERT(right >= left);
    return NSMakeRange(left, right - left);
    
}

- (void)setNeedsDisplayForLinesInRange:(NSRange)lineRange {
    // redisplay the lines in the given range
    if (lineRange.length == 0) return;
    NSUInteger firstLine = lineRange.location, lastLine = NSMaxRange(lineRange);
    CGFloat lineHeight = [self lineHeight];
    CGFloat vertOffset = [self verticalOffset];
    CGFloat yOrigin = (firstLine - vertOffset) * lineHeight;
    CGFloat lastLineBottom = (lastLine - vertOffset) * lineHeight;
    NSRect bounds = [self bounds];
    NSRect dirtyRect = NSMakeRect(bounds.origin.x, bounds.origin.y + yOrigin, NSWidth(bounds), lastLineBottom - yOrigin);
    [self setNeedsDisplayInRect:dirtyRect];
}

- (void)setData:(NSData *)val {
    if (val != _data) {
        NSUInteger oldLength = [_data length];
        NSUInteger newLength = [val length];
        const unsigned char *oldBytes = (const unsigned char *)[_data bytes];
        const unsigned char *newBytes = (const unsigned char *)[val bytes];
        NSUInteger firstDifferingIndex = HFIndexOfFirstByteThatDiffers(oldBytes, oldLength, newBytes, newLength);
        if (firstDifferingIndex == NSUIntegerMax) {
            /* Nothing to do!  Data is identical! */
        }
        else {
            NSUInteger lastDifferingIndex = HFIndexOfLastByteThatDiffers(oldBytes, oldLength, newBytes, newLength);
            HFASSERT(lastDifferingIndex != NSUIntegerMax); //if we have a first different byte, we must have a last different byte
            /* Expand to encompass characters that they touch */
            NSUInteger bytesPerCharacter = [self bytesPerCharacter];
            firstDifferingIndex -= firstDifferingIndex % bytesPerCharacter;
            lastDifferingIndex = HFRoundUpToMultipleInt(lastDifferingIndex, bytesPerCharacter);
            
            /* Now figure out the line range they touch */
            const NSUInteger bytesPerLine = [self bytesPerLine];
            NSUInteger firstLine = firstDifferingIndex / bytesPerLine;
            NSUInteger lastLine = HFDivideULRoundingUp(MAX(oldLength, newLength), bytesPerLine);
            /* The +1 is for the following case - if we change the last character, then it may push the caret into the next line (even though there's no text there).  This last line may have a background color, so we need to make it draw if it did not draw before (or vice versa - when deleting the last character which pulls the caret from the last line). */
            NSUInteger lastDifferingLine = (lastDifferingIndex == NSNotFound ? lastLine : HFDivideULRoundingUp(lastDifferingIndex + 1, bytesPerLine));
            if (lastDifferingLine > firstLine) {
                [self setNeedsDisplayForLinesInRange:NSMakeRange(firstLine, lastDifferingLine - firstLine)];
            }
        }
        [_data release];
        _data = [val copy];
        [self _updateCaretTimer];
    }
}

- (void)setStyles:(NSArray *)newStyles {
    if (! [_styles isEqual:newStyles]) {
        
        /* Figure out which styles changed - that is, we want to compute those objects that are not in oldStyles or newStyles, but not both. */
        NSMutableSet *changedStyles = _styles ? [[NSMutableSet alloc] initWithArray:_styles] : [[NSMutableSet alloc] init];
        FOREACH(HFTextVisualStyleRun *, run, newStyles) {
            if ([changedStyles containsObject:run]) {
                [changedStyles removeObject:run];
            }
            else {
                [changedStyles addObject:run];
            }
        }
        
        /* Now figure out the first and last indexes of changed ranges. */
        NSUInteger firstChangedIndex = NSUIntegerMax, lastChangedIndex = 0;
        FOREACH(HFTextVisualStyleRun *, changedRun, changedStyles) {
            NSRange range = [changedRun range];
            if (range.length > 0) {
                firstChangedIndex = MIN(firstChangedIndex, range.location);
                lastChangedIndex = MAX(lastChangedIndex, NSMaxRange(range) - 1);
            }
        }
        
        /* Don't need this any more */
        [changedStyles release];
        
        /* Expand to cover all touched characters */
        NSUInteger bytesPerCharacter = [self bytesPerCharacter];
        firstChangedIndex -= firstChangedIndex % bytesPerCharacter;
        lastChangedIndex = HFRoundUpToMultipleInt(lastChangedIndex, bytesPerCharacter);        
        
        /* Figure out the changed lines, and trigger redisplay */
        if (firstChangedIndex <= lastChangedIndex) {
            const NSUInteger bytesPerLine = [self bytesPerLine];
            NSUInteger firstLine = firstChangedIndex / bytesPerLine;
            NSUInteger lastLine = HFDivideULRoundingUp(lastChangedIndex, bytesPerLine);
            [self setNeedsDisplayForLinesInRange:NSMakeRange(firstLine, lastLine - firstLine + 1)];   
        }
        
        /* Do the usual Cocoa thing */
        [_styles release];
        _styles = [newStyles copy];
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
    HFUnregisterViewForWindowAppearanceChanges(self, _hftvflags.registeredForAppNotifications /* appToo */);
    [caretTimer invalidate];
    [caretTimer release];
    [_font release];
    [_data release];
    [_styles release];
    [cachedSelectedRanges release];
    [callouts release];
    if(byteColoring) Block_release(byteColoring);
    [super dealloc];
}

- (NSColor *)backgroundColorForEmptySpace {
    NSArray *colors = [[self representer] rowBackgroundColors];
    if (! [colors count]) return [NSColor clearColor]; 
    else return colors[0];
}

- (NSColor *)backgroundColorForLine:(NSUInteger)line {
    NSArray *colors = [[self representer] rowBackgroundColors];
    NSUInteger colorCount = [colors count];
    if (colorCount == 0) return [NSColor clearColor];
    NSUInteger colorIndex = (line + startingLineBackgroundColorIndex) % colorCount;
    if (colorIndex == 0) return nil; //will be drawn by empty space
    else return colors[colorIndex]; 
}

- (NSUInteger)bytesPerLine {
    HFASSERT([self representer] != nil);
    return [[self representer] bytesPerLine];
}

- (NSUInteger)bytesPerColumn {
    HFASSERT([self representer] != nil);
    return [[self representer] bytesPerColumn];
}

- (void)_drawDefaultLineBackgrounds:(NSRect)clip withLineHeight:(CGFloat)lineHeight maxLines:(NSUInteger)maxLines {
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

- (HFTextVisualStyleRun *)styleRunForByteAtIndex:(NSUInteger)byteIndex {
    if (! _styles) return nil;
    FOREACH(HFTextVisualStyleRun *, run, _styles) {
        if (NSLocationInRange(byteIndex, [run range])) {
            return run;
        }
    }
    [NSException raise:NSInvalidArgumentException format:@"Byte index %lu not present in runs %@", (unsigned long)byteIndex, _styles];
    return nil;
}

/* Given a list of rects and a parallel list of values, find cases of equal adjacent values, and union together their corresponding rects, deleting the second element from the list.  Next, delete all nil values.  Returns the new count of the list. */
static size_t unionAndCleanLists(NSRect *rectList, id *valueList, size_t count) {
    size_t trailing = 0, leading = 0;
    while (leading < count) {
        /* Copy our value left */
        valueList[trailing] = valueList[leading];
        rectList[trailing] = rectList[leading];
        
        /* Skip one - no point unioning with ourselves */
        leading += 1;
        
        /* Sweep right, unioning until we reach a different value or the end */
        id targetValue = valueList[trailing];
        for (; leading < count; leading++) {
            id testValue = valueList[leading];
            if (targetValue == testValue || (testValue && [targetValue isEqual:testValue])) {
                /* Values match, so union the two rects */
                rectList[trailing] = NSUnionRect(rectList[trailing], rectList[leading]);
            }
            else {
                /* Values don't match, we're done sweeping */
                break;
            }
        }
        
        /* We're done with this index */
        trailing += 1;
    }
    
    /* trailing keeps track of how many values we have */
    count = trailing;
    
    /* Now do the same thing, except delete nil values */
    for (trailing = leading = 0; leading < count; leading++) {
        if (valueList[leading] != nil) {
            valueList[trailing] = valueList[leading];
            rectList[trailing] = rectList[leading];
            trailing += 1;
        }
    }
    count = trailing;    
    
    /* All done */
    return count;
}

/* Draw vertical guidelines every four bytes */
- (void)drawVerticalGuideLines:(NSRect)clip {
    if (bytesBetweenVerticalGuides == 0) return;
    
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSRect bounds = [self bounds];
    CGFloat advancePerCharacter = [self advancePerCharacter];
    CGFloat spaceAdvancement = advancePerCharacter / 2;
    CGFloat advanceAmount = (advancePerCharacter + spaceAdvancement) * bytesBetweenVerticalGuides;
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

- (NSColor *)colorForBookmark:(NSUInteger)bookmark withAlpha:(CGFloat)alpha {
    // OMG this is so clever I'm going to die.  Reverse our bits and use that as a hue lookup into the color wheel.
    NSUInteger v = bookmark - 1; //because bookmarks are indexed from 1
    NSUInteger reverse = v;
    unsigned int s = (CHAR_BIT * sizeof v) - 1;
    for (v >>= 1; v; v >>= 1) {
        reverse <<= 1;
        reverse |= (v & 1);
        s--;
    }
    reverse <<= s; // shift when v's highest bits are zero
    
    double hue = reverse / (1. + NSUIntegerMax);
    return [NSColor colorWithCalibratedHue:hue saturation:1. brightness:.6 alpha:alpha];
}

- (NSColor *)colorForBookmark:(NSUInteger)bookmark {
    return [self colorForBookmark:bookmark withAlpha:(CGFloat).66];
}

- (void)drawBookmark:(NSUInteger)bookmark inRect:(NSRect)rect {
    [NSGraphicsContext saveGraphicsState];
    NSColor *color = [self colorForBookmark:bookmark];
    if (color) {
        NSBezierPath *path = [[NSBezierPath alloc] init];
        [path appendBezierPathWithOvalInRect:NSMakeRect(rect.origin.x, rect.origin.y, 6, 6)];
        [path appendBezierPathWithRect:NSMakeRect(rect.origin.x, rect.origin.y, 2, defaultLineHeight)];
        [path fill];
        [path release];
        NSRectFill(NSMakeRect(rect.origin.x, NSMaxY(rect) - 1, rect.size.width, (CGFloat).75));
    }
    [NSGraphicsContext restoreGraphicsState];
}

- (void)drawBookmarkStarts:(NSIndexSet *)bookmarkStarts inRect:(NSRect)rect {
    NSUInteger i = 0;
    NSUInteger idx;
    NSRect ovalRect = NSMakeRect(rect.origin.x, rect.origin.y, 6, 6);
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    for (idx = [bookmarkStarts firstIndex]; idx != NSNotFound; idx = [bookmarkStarts indexGreaterThanIndex:idx]) {
        NSBezierPath *path = [[NSBezierPath alloc] init];
        //[path appendBezierPathWithOvalInRect:ovalRect];
        if (i == 0) [path appendBezierPathWithRect:NSMakeRect(rect.origin.x, rect.origin.y, 2, defaultLineHeight)];
        [[self colorForBookmark:idx] set];
        BOOL needsClip = ! NSContainsRect(rect, ovalRect);
        if (needsClip) {
            [context saveGraphicsState];
            [NSBezierPath clipRect:rect];
        }
        [path fill];
        if (needsClip) {
            [context restoreGraphicsState];
        }
        [path release];
        
        i++;
        ovalRect.origin.y += ovalRect.size.height;
        if (ovalRect.origin.y > NSMaxY(rect)) break;
    }
}

- (void)drawBookmarkExtents:(NSIndexSet *)bookmarkExtents inRect:(NSRect)rect {
    NSUInteger idx = 0, numBookmarks = [bookmarkExtents count];
    const CGFloat lineThickness = 1.5;
    [NSBezierPath setDefaultLineWidth:lineThickness];
    
    CGFloat stripeLength;
    switch (numBookmarks) {
        case 0:
        case 1:
            stripeLength = NSWidth(rect);
            break;
        case 2:
            stripeLength = 16;
            break;
        case 3:
            stripeLength = 10;
            break;
        case 4:
        default:
            stripeLength = 6;
            break;
    }
    
    CGFloat initialStripeOffset = rect.origin.x;
    CGFloat stripeSpace = stripeLength * numBookmarks;
    for (NSUInteger bookmark = [bookmarkExtents firstIndex]; bookmark != NSNotFound; bookmark = [bookmarkExtents indexGreaterThanIndex:bookmark]) {
        [[self colorForBookmark:bookmark] set];
        
        NSRect stripeRect = NSMakeRect(initialStripeOffset, NSMaxY(rect) - 1.25, stripeLength, lineThickness);
        CGFloat remainingWidthInRect = NSMaxX(rect) - initialStripeOffset;
        while (remainingWidthInRect > 0) {
            // don't draw beyond the end of the rect
            stripeRect.size.width = fmin(remainingWidthInRect, stripeRect.size.width);
            
            NSRectFill(stripeRect);
            stripeRect.origin.x += stripeSpace;
            remainingWidthInRect -= stripeSpace;
        }
        
        // start the next stripe offset from the first
        initialStripeOffset += stripeLength;
    }
}

- (void)drawBookmarkEnds:(NSIndexSet *)bookmarkEnds inRect:(NSRect)rect {
    NSUInteger i = 0;
    NSUInteger idx;
    NSRect ovalRect = NSMakeRect(NSMaxX(rect) - 6, rect.origin.y, 6, 6);
    NSGraphicsContext *context = [NSGraphicsContext currentContext];
    for (idx = [bookmarkEnds firstIndex]; idx != NSNotFound; idx = [bookmarkEnds indexGreaterThanIndex:idx]) {
        NSBezierPath *path = [[NSBezierPath alloc] init];
        [path appendBezierPathWithOvalInRect:ovalRect];
        if (i == 0) [path appendBezierPathWithRect:NSMakeRect(NSMaxX(rect) - 2, rect.origin.y, 2, defaultLineHeight)];
        [[self colorForBookmark:idx] set];
        BOOL needsClip = ! NSContainsRect(rect, ovalRect);
        if (needsClip) {
            [context saveGraphicsState];
            [NSBezierPath clipRect:rect];
        }
        [path fill];
        if (needsClip) {
            [context restoreGraphicsState];
        }
        [path release];
        
        i++;
        ovalRect.origin.y += ovalRect.size.height;
        if (ovalRect.origin.y > NSMaxY(rect)) break;
    }
}

- (void)setByteColoring:(void (^)(uint8_t, uint8_t*, uint8_t*, uint8_t*, uint8_t*))coloring {
    Block_release(byteColoring);
    byteColoring = coloring ? Block_copy(coloring) : NULL;
    [self setNeedsDisplay:YES];
}

- (void)drawByteColoringBackground:(NSRange)range inRect:(NSRect)rect {
    if(!byteColoring) return;
    
    size_t width = (size_t)rect.size.width;
    
    // A rgba, 8-bit, single row image.
    // +1 in case messing around with floats makes us overshoot a bit.
    uint32_t *buffer = calloc(width+1, 4);
    
    const uint8_t *bytes = [_data bytes];
    bytes += range.location;
    
    NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn];
    CGFloat advancePerCharacter = [self advancePerCharacter];
    CGFloat advanceBetweenColumns = [self advanceBetweenColumns];
    
    // For each character, draw the corresponding part of the image
    CGFloat offset = [self horizontalContainerInset];
    for(NSUInteger i = 0; i < range.length; i++) {
        uint8_t r, g, b, a;
        byteColoring(bytes[i], &r, &g, &b, &a);
        uint32_t c = ((uint32_t)r<<0) | ((uint32_t)g<<8) | ((uint32_t)b<<16) | ((uint32_t)a<<24);
        memset_pattern4(&buffer[(size_t)offset], &c, 4*(size_t)(advancePerCharacter+1));
        offset += advancePerCharacter;
        if(bytesPerColumn && (i+1) % bytesPerColumn == 0)
            offset += advanceBetweenColumns;
    }
    
    // Do a CGImage dance to draw the buffer
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, buffer, 4 * width, NULL);
    CGColorSpaceRef cgcolorspace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    CGImageRef image = CGImageCreate(width, 1, 8, 32, 4 * width, cgcolorspace,
                                     (CGBitmapInfo)kCGImageAlphaLast, provider, NULL, false, kCGRenderingIntentDefault);
    CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], NSRectToCGRect(rect), image);
    CGColorSpaceRelease(cgcolorspace);
    CGImageRelease(image);
    CGDataProviderRelease(provider);
    free(buffer);
}

- (void)drawStyledBackgroundsForByteRange:(NSRange)range inRect:(NSRect)rect {
    NSRect remainingRunRect = rect;
    NSRange remainingRange = range;
    
    /* Our caller lies to us a little */
    remainingRunRect.origin.x += [self horizontalContainerInset];
    
    const NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn];
    
    /* Here are the properties we care about */
    struct PropertyInfo_t {
        SEL stylePropertyAccessor; // the selector we use to get the property
        NSRect *rectList; // the list of rects corresponding to the property values
        id *propertyValueList; // the list of the property values
        size_t count; //list count, only gets set after cleaning up our lists
    } propertyInfos[] = {
        {.stylePropertyAccessor = @selector(backgroundColor)},
        {.stylePropertyAccessor = @selector(bookmarkStarts)},
        {.stylePropertyAccessor = @selector(bookmarkExtents)},
        {.stylePropertyAccessor = @selector(bookmarkEnds)}
    };
    
    /* Each list has the same capacity, and (initially) the same count */
    size_t i, listCount = 0, listCapacity = 0;
    
    /* The function pointer we use to get our property values */
    id (* const funcPtr)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
    
    size_t propertyIndex;
    const size_t propertyInfoCount = sizeof propertyInfos / sizeof *propertyInfos;
    
    while (remainingRange.length > 0) {
        /* Get the next run for the remaining range. */
        HFTextVisualStyleRun *styleRun = [self styleRunForByteAtIndex:remainingRange.location];
        
        /* The length of the run is the end of the style run or the end of the range we're given (whichever is smaller), minus the beginning of the range we care about. */
        NSUInteger runStart = remainingRange.location;
        NSUInteger runLength = MIN(NSMaxRange(range), NSMaxRange([styleRun range])) - runStart;
        
        /* Get the width of this run and use it to compute the rect */
        CGFloat runRectWidth = [self totalAdvanceForBytesInRange:NSMakeRange(remainingRange.location, runLength)];
        NSRect runRect = remainingRunRect;
        runRect.size.width = runRectWidth;
        
        /* Update runRect and remainingRunRect based on what we just learned */
        remainingRunRect.origin.x += runRectWidth;
        remainingRunRect.size.width -= runRectWidth;
		
        /* Do a hack - if we end at a column boundary, subtract the advance between columns.  If the next run has the same value for this property, then we'll end up unioning the rects together and the column gap will be filled.  This is the primary purpose of this function. */
        if (bytesPerColumn > 0 && (runStart + runLength) % bytesPerColumn == 0) {
            runRect.size.width -= MIN([self advanceBetweenColumns], runRect.size.width);
        }
        
        /* Extend our lists if necessary */
        if (listCount == listCapacity) {
            /* Our list is too small, extend it */
            listCapacity = listCapacity + 16;
            
            for (propertyIndex = 0; propertyIndex < propertyInfoCount; propertyIndex++) {
                struct PropertyInfo_t *p = propertyInfos + propertyIndex;
                p->rectList = check_realloc(p->rectList, listCapacity * sizeof *p->rectList);
                p->propertyValueList = check_realloc(p->propertyValueList, listCapacity * sizeof *p->propertyValueList);
            }
        }
        
        /* Now append our values to our lists, even if it's nil */
        for (propertyIndex = 0; propertyIndex < propertyInfoCount; propertyIndex++) {
            struct PropertyInfo_t *p = propertyInfos + propertyIndex;
            id value = funcPtr(styleRun, p->stylePropertyAccessor);
            p->rectList[listCount] = runRect;
            p->propertyValueList[listCount] = value;
        }
        
        listCount++;
		
        /* Update remainingRange */
        remainingRange.location += runLength;
        remainingRange.length -= runLength;		
        
    }
    
    /* Now clean up our lists, to delete the gaps we may have introduced */
    for (propertyIndex = 0; propertyIndex < propertyInfoCount; propertyIndex++) {
        struct PropertyInfo_t *p = propertyInfos + propertyIndex;
        p->count = unionAndCleanLists(p->rectList, p->propertyValueList, listCount);
    }
    
    /* Finally we can draw them! First, draw byte backgrounds. */
    [self drawByteColoringBackground:range inRect:rect];
    
    const struct PropertyInfo_t *p;
    
    /* Draw backgrounds */
    p = propertyInfos + 0;
    if (p->count > 0) NSRectFillListWithColorsUsingOperation(p->rectList, p->propertyValueList, p->count, NSCompositeSourceOver);
    
    /* Draw bookmark starts, extents, and ends */
    p = propertyInfos + 1;
    for (i=0; i < p->count; i++) [self drawBookmarkStarts:p->propertyValueList[i] inRect:p->rectList[i]];
    
    p = propertyInfos + 2;
    for (i=0; i < p->count; i++) [self drawBookmarkExtents:p->propertyValueList[i] inRect:p->rectList[i]];
    
    p = propertyInfos + 3;
    for (i=0; i < p->count; i++) [self drawBookmarkEnds:p->propertyValueList[i] inRect:p->rectList[i]];
    
    /* Clean up */
    for (propertyIndex = 0; propertyIndex < propertyInfoCount; propertyIndex++) {
        p = propertyInfos + propertyIndex;
        free(p->rectList);
        free(p->propertyValueList);
    }    
}

- (void)drawGlyphs:(const struct HFGlyph_t *)glyphs atPoint:(NSPoint)point withAdvances:(const CGSize *)advances withStyleRun:(HFTextVisualStyleRun *)styleRun count:(NSUInteger)glyphCount {
    HFASSERT(glyphs != NULL);
    HFASSERT(advances != NULL);
    HFASSERT(glyphCount > 0);
    if ([styleRun shouldDraw]) {
        [styleRun set];
        CGContextRef ctx =  [[NSGraphicsContext currentContext] graphicsPort];
        
        /* Get all the CGGlyphs together */
        NEW_ARRAY(CGGlyph, cgglyphs, glyphCount);
        for (NSUInteger j=0; j < glyphCount; j++) {
            cgglyphs[j] = glyphs[j].glyph;
        }
        
        NSUInteger runStart = 0;
        HFGlyphFontIndex runFontIndex = glyphs[0].fontIndex;
        CGFloat runAdvance = 0;
        for (NSUInteger i=1; i <= glyphCount; i++) {
            /* Check if this run is finished, or if we are using a substitution font */
            if (i == glyphCount || glyphs[i].fontIndex != runFontIndex || runFontIndex > 0) {
                /* Draw this run */
                NSFont *fontToUse = [self fontAtSubstitutionIndex:runFontIndex];
                [[fontToUse screenFont] set];
                CGContextSetTextPosition(ctx, point.x + runAdvance, point.y);
                
                if (runFontIndex > 0) {
                    /* A substitution font.  Here we should only have one glyph */
                    HFASSERT(i - runStart == 1);
                    /* Get the advance for this glyph. */
                    NSSize nativeAdvance;
                    NSGlyph nativeGlyph = cgglyphs[runStart];
                    [fontToUse getAdvancements:&nativeAdvance forGlyphs:&nativeGlyph count:1];
                    if (nativeAdvance.width > advances[runStart].width) {
                        /* This glyph is too wide!  We'll have to scale it.  Here we only scale horizontally. */
                        CGFloat horizontalScale = advances[runStart].width / nativeAdvance.width;
                        CGAffineTransform textCTM = CGContextGetTextMatrix(ctx);
                        textCTM.a *= horizontalScale;
                        CGContextSetTextMatrix(ctx, textCTM);
                        /* Note that we don't have to restore the text matrix, because the next call to set the font will overwrite it. */
                    }
                }
                
                /* Draw the glyphs */
                CGContextShowGlyphsWithAdvances(ctx, cgglyphs + runStart, advances + runStart, i - runStart);
                
                /* Record the new run */
                if (i < glyphCount) {                    
                    /* Sum the advances */
                    for (NSUInteger j = runStart; j < i; j++) {
                        runAdvance += advances[j].width;
                    }
                    
                    /* Record the new run start and index */
                    runStart = i;
                    runFontIndex = glyphs[i].fontIndex;
                    HFASSERT(runFontIndex != kHFGlyphFontIndexInvalid);
                }
            }
        }
    }
}


- (void)extractGlyphsForBytes:(const unsigned char *)bytes count:(NSUInteger)numBytes offsetIntoLine:(NSUInteger)offsetIntoLine intoArray:(struct HFGlyph_t *)glyphs advances:(CGSize *)advances resultingGlyphCount:(NSUInteger *)resultGlyphCount {
    USE(bytes);
    USE(numBytes);
    USE(offsetIntoLine);
    USE(glyphs);
    USE(advances);
    USE(resultGlyphCount);
    UNIMPLEMENTED_VOID();
}

- (void)extractGlyphsForBytes:(const unsigned char *)bytePtr range:(NSRange)byteRange intoArray:(struct HFGlyph_t *)glyphs advances:(CGSize *)advances withInclusionRanges:(NSArray *)restrictingToRanges initialTextOffset:(CGFloat *)initialTextOffset resultingGlyphCount:(NSUInteger *)resultingGlyphCount {
    NSParameterAssert(glyphs != NULL && advances != NULL && restrictingToRanges != nil && bytePtr != NULL);
    NSRange priorIntersectionRange = {NSUIntegerMax, NSUIntegerMax};
    NSUInteger glyphBufferIndex = 0;
    NSUInteger bytesPerLine = [self bytesPerLine];
    NSUInteger restrictionRangeCount = [restrictingToRanges count];
    for (NSUInteger rangeIndex = 0; rangeIndex < restrictionRangeCount; rangeIndex++) {
        NSRange inclusionRange = [restrictingToRanges[rangeIndex] rangeValue];
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
    
    NSUInteger lineStartIndex, bytesPerLine = [self bytesPerLine];
    NSData *dataObject = [self data];
    NSFont *fontObject = [[self font] screenFont];
    //const NSUInteger bytesPerChar = [self bytesPerCharacter];
    const NSUInteger byteCount = [dataObject length];
    
    const unsigned char * const bytePtr = [dataObject bytes];
    
    NSRect lineRectInBoundsSpace = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), lineHeight);
    lineRectInBoundsSpace.origin.y -= [self verticalOffset] * lineHeight;
    
    /* Start us off with the horizontal inset and move the baseline down by the ascender so our glyphs just graze the top of our view */
    textTransform.tx += [self horizontalContainerInset];
    textTransform.ty += [fontObject ascender] - lineHeight * [self verticalOffset];
    NSUInteger lineIndex = 0;
    const NSUInteger maxGlyphCount = [self maximumGlyphCountForByteCount:bytesPerLine];
    NEW_ARRAY(struct HFGlyph_t, glyphs, maxGlyphCount);
    NEW_ARRAY(CGSize, advances, maxGlyphCount);
    for (lineStartIndex = 0; lineStartIndex < byteCount; lineStartIndex += bytesPerLine) {
        if (lineStartIndex > 0) {
            textTransform.ty += lineHeight;
            lineRectInBoundsSpace.origin.y += lineHeight;
        }
        if (NSIntersectsRect(lineRectInBoundsSpace, clip)) {	    
            const NSUInteger bytesInThisLine = MIN(bytesPerLine, byteCount - lineStartIndex);
            
            /* Draw the backgrounds of any styles. */
            [self drawStyledBackgroundsForByteRange:NSMakeRange(lineStartIndex, bytesInThisLine) inRect:lineRectInBoundsSpace];
            
            NSUInteger byteIndexInLine = 0;
            CGFloat advanceIntoLine = 0;
            while (byteIndexInLine < bytesInThisLine) {
                const NSUInteger byteIndex = lineStartIndex + byteIndexInLine;
                HFTextVisualStyleRun *styleRun = [self styleRunForByteAtIndex:byteIndex];
                HFASSERT(styleRun != nil);
                HFASSERT(byteIndex >= [styleRun range].location);
                const NSUInteger bytesInThisRun = MIN(NSMaxRange([styleRun range]) - byteIndex, bytesInThisLine - byteIndexInLine);
                const NSRange characterRange = [self roundPartialByteRange:NSMakeRange(byteIndex, bytesInThisRun)];
                if (characterRange.length > 0) {
                    NSUInteger resultGlyphCount = 0;
                    CGFloat initialTextOffset = 0;
                    if (restrictingToRanges == nil) {
                        [self extractGlyphsForBytes:bytePtr + characterRange.location count:characterRange.length offsetIntoLine:byteIndexInLine intoArray:glyphs advances:advances resultingGlyphCount:&resultGlyphCount];
                    }
                    else {
                        [self extractGlyphsForBytes:bytePtr range:NSMakeRange(byteIndex, bytesInThisRun) intoArray:glyphs advances:advances withInclusionRanges:restrictingToRanges initialTextOffset:&initialTextOffset resultingGlyphCount:&resultGlyphCount];
                    }
                    HFASSERT(resultGlyphCount <= maxGlyphCount);
                    
#if ! NDEBUG
                    for (NSUInteger q=0; q < resultGlyphCount; q++) {
                        HFASSERT(glyphs[q].fontIndex != kHFGlyphFontIndexInvalid);
                    }
#endif
                    
                    if (resultGlyphCount > 0) {
                        textTransform.tx += initialTextOffset + advanceIntoLine;
                        CGContextSetTextMatrix(ctx, textTransform);
                        /* Draw them */
                        [self drawGlyphs:glyphs atPoint:NSMakePoint(textTransform.tx, textTransform.ty) withAdvances:advances withStyleRun:styleRun count:resultGlyphCount];
                        
                        /* Undo the work we did before so as not to screw up the next run */
                        textTransform.tx -= initialTextOffset + advanceIntoLine;
                        
                        /* Record how far into our line this made us move */
                        NSUInteger glyphIndex;
                        for (glyphIndex = 0; glyphIndex < resultGlyphCount; glyphIndex++) {
                            advanceIntoLine += advances[glyphIndex].width;
                        }
                    }
                }
                byteIndexInLine += bytesInThisRun;
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

- (void)setBookmarks:(NSDictionary *)bookmarks {
    if (! callouts) callouts = [[NSMutableDictionary alloc] init];

    /* Invalidate any bookmarks we're losing */
    NSArray *existingKeys = [callouts allKeys];
    FOREACH(NSNumber *, key, existingKeys) {
        if (! bookmarks[key]) {
            HFRepresenterTextViewCallout *callout = callouts[key];
            [self setNeedsDisplayInRect:[callout rect]];
            [callouts removeObjectForKey:key];
        }
    }
    
    /* Add any bookmarks we're missing */
    NSArray *newKeys = [bookmarks allKeys];
    FOREACH(NSNumber *, newKey, newKeys) {
        HFRepresenterTextViewCallout *callout = callouts[newKey];
        if (! callout) {
            NSUInteger bookmark = [newKey unsignedIntegerValue];
            callout = [[HFRepresenterTextViewCallout alloc] init];
            [callout setColor:[self colorForBookmark:bookmark]];
            [callout setLabel:[NSString stringWithFormat:@"%lu", [newKey unsignedLongValue]]];
            [callout setRepresentedObject:newKey];
            callouts[newKey] = callout;
            [callout release];
        }
        NSInteger byteOffset = [bookmarks[newKey] integerValue];
        [callout setByteOffset:byteOffset];
    }
    
    /* Layout. This also invalidates any that have changed */
    [HFRepresenterTextViewCallout layoutCallouts:[callouts allValues] inView:self];
}

- (BOOL)shouldDrawCallouts {
    return _hftvflags.drawCallouts;
}

- (void)setShouldDrawCallouts:(BOOL)val {
    _hftvflags.drawCallouts = val;
    [self setNeedsDisplay:YES];
}

- (void)drawBookmarksWithClip:(NSRect)clip {
    if([self shouldDrawCallouts]) {
        /* Figure out which callouts we're going to draw */
        NSRect allCalloutsRect = NSZeroRect;
        NSMutableArray *localCallouts = [[NSMutableArray alloc] initWithCapacity:[callouts count]];
        FOREACH(HFRepresenterTextViewCallout *, callout, [callouts objectEnumerator]) {
            NSRect calloutRect = [callout rect];
            if (NSIntersectsRect(clip, calloutRect)) {
                [localCallouts addObject:callout];
                allCalloutsRect = NSUnionRect(allCalloutsRect, calloutRect);
            }
        }
        allCalloutsRect = NSIntersectionRect(allCalloutsRect, clip);
        
        if ([localCallouts count]) {
            /* Draw shadows first */
            CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
            CGContextBeginTransparencyLayerWithRect(ctx, NSRectToCGRect(allCalloutsRect), NULL);
            FOREACH(HFRepresenterTextViewCallout *, callout, localCallouts) {
                [callout drawShadowWithClip:clip];
            }
            CGContextEndTransparencyLayer(ctx);
            
            FOREACH(HFRepresenterTextViewCallout *, newCallout, localCallouts) {
                // NSRect rect = [callout rect];
                // [[NSColor greenColor] set];
                // NSFrameRect(rect);
                [newCallout drawWithClip:clip];
            }
        }
        [localCallouts release];
    }
}

- (void)drawRect:(NSRect)clip {
    [[self backgroundColorForEmptySpace] set];
    NSRectFillUsingOperation(clip, NSCompositeSourceOver);
    BOOL antialias = [self shouldAntialias];
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    
    [[self.font screenFont] set];
    
    if ([self showsFocusRing]) {
        NSWindow *window = [self window];
        if (self == [window firstResponder] && [window isKeyWindow]) {
            [self drawFocusRingWithClip:clip];
        }
    }
    
    NSUInteger bytesPerLine = [self bytesPerLine];
    if (bytesPerLine == 0) return;
    NSUInteger byteCount = [_data length];
    
    [self _drawDefaultLineBackgrounds:clip withLineHeight:[self lineHeight] maxLines:ll2l(HFRoundUpToNextMultipleSaturate(byteCount, bytesPerLine) / bytesPerLine)];
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
    if ([self _effectiveBytesPerColumn] == 1) {
        [self drawVerticalGuideLines:clip];
    }
    
    [self drawCaretIfNecessaryWithClip:clip];
    
    [self drawBookmarksWithClip:clip];
}

- (NSRect)furthestRectOnEdge:(NSRectEdge)edge forRange:(NSRange)byteRange {
    HFASSERT(edge == NSMinXEdge || edge == NSMaxXEdge || edge == NSMinYEdge || edge == NSMaxYEdge);
    const NSUInteger bytesPerLine = [self bytesPerLine];
    CGFloat lineHeight = [self lineHeight];
    CGFloat vertOffset = [self verticalOffset];
    NSUInteger firstLine = byteRange.location / bytesPerLine, lastLine = (NSMaxRange(byteRange) - 1) / bytesPerLine;
    NSRect result = NSZeroRect;
    
    if (edge == NSMinYEdge || edge == NSMaxYEdge) {
        /* This is the top (MinY) or bottom (MaxY).  We only have to look at one line. */
        NSUInteger lineIndex = (edge == NSMinYEdge ? firstLine : lastLine);
        NSRange lineRange = NSMakeRange(lineIndex * bytesPerLine, bytesPerLine);
        NSRange intersection = NSIntersectionRange(lineRange, byteRange);
        HFASSERT(intersection.length > 0);
        CGFloat yOrigin = (lineIndex - vertOffset) * lineHeight;
        CGFloat xStart = [self originForCharacterAtByteIndex:intersection.location].x;
        CGFloat xEnd = [self originForCharacterAtByteIndex:NSMaxRange(intersection) - 1].x + [self advancePerCharacter];
        result = NSMakeRect(xStart, yOrigin, xEnd - xStart, 0);
    }
    else {
        if (firstLine == lastLine) {
            /* We only need to consider this one line */
            NSRange lineRange = NSMakeRange(firstLine * bytesPerLine, bytesPerLine);
            NSRange intersection = NSIntersectionRange(lineRange, byteRange);
            HFASSERT(intersection.length > 0);
            CGFloat yOrigin = (firstLine - vertOffset) * lineHeight;
            CGFloat xCoord;
            if (edge == NSMinXEdge) {
                xCoord = [self originForCharacterAtByteIndex:intersection.location].x;
            }
            else {
                xCoord = [self originForCharacterAtByteIndex:NSMaxRange(intersection) - 1].x + [self advancePerCharacter];
            }
            result = NSMakeRect(xCoord, yOrigin, 0, lineHeight);            
        }
        else {
            /* We have more than one line.  If we are asking for the left edge, sum up the left edge of every line but the first, and handle the first specially.  Likewise for the right edge (except handle the last specially) */
            BOOL includeFirstLine, includeLastLine;
            CGFloat xCoord;
            if (edge == NSMinXEdge) {
                /* Left edge, include the first line only if it starts at the beginning of the line or there's only one line */
                includeFirstLine = (byteRange.location % bytesPerLine == 0);
                includeLastLine = YES;
                xCoord = [self horizontalContainerInset];
            }
            else {
                /* Right edge, include the last line only if it starts at the beginning of the line or there's only one line */
                includeFirstLine = YES;
                includeLastLine = (NSMaxRange(byteRange) % bytesPerLine == 0);
                NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn];
                /* Don't add in space for the advance after the last column, hence subtract 1. */
                NSUInteger numColumns = (bytesPerColumn ? (bytesPerLine / bytesPerColumn - 1) : 0);
                xCoord = [self horizontalContainerInset] + ([self advancePerCharacter] * bytesPerLine / [self bytesPerCharacter]) + [self advanceBetweenColumns] * numColumns;
            }
            NSUInteger firstLineToInclude = (includeFirstLine ? firstLine : firstLine + 1), lastLineToInclude = (includeLastLine ? lastLine : lastLine - 1);
            result = NSMakeRect(xCoord, (firstLineToInclude - [self verticalOffset]) * lineHeight, 0, (lastLineToInclude - firstLineToInclude + 1) * lineHeight);
        }
    }
    return result;
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

- (CGFloat)advanceBetweenColumns {
    UNIMPLEMENTED();
}

- (CGFloat)advancePerCharacter {
    UNIMPLEMENTED();
}

- (CGFloat)advancePerColumn {
    NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn];
    if (bytesPerColumn == 0) {
        return 0;
    }
    else {
        return [self advancePerCharacter] * (bytesPerColumn / [self bytesPerCharacter]) + [self advanceBetweenColumns];
    }
}

- (CGFloat)totalAdvanceForBytesInRange:(NSRange)range {
    if (range.length == 0) return 0;
    NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn];
    HFASSERT(bytesPerColumn == 0 || [self bytesPerLine] % bytesPerColumn == 0);
    CGFloat result = (range.length * [self advancePerCharacter] / [self bytesPerCharacter]) ;
    if (bytesPerColumn > 0) {
        NSUInteger numColumnSpaces = NSMaxRange(range) / bytesPerColumn - range.location / bytesPerColumn; //note that integer division does not distribute
        result += numColumnSpaces * [self advanceBetweenColumns];
    }
    return result;
}

/* Returns the number of bytes in a character, e.g. if we are UTF-16 this would be 2. */
- (NSUInteger)bytesPerCharacter {
    return 1;
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    CGFloat availableSpace = (CGFloat)(viewWidth - 2. * [self horizontalContainerInset]);
    NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn], bytesPerCharacter = [self bytesPerCharacter];    
    if (bytesPerColumn == 0) {
        /* No columns */
        NSUInteger numChars = (NSUInteger)(availableSpace / [self advancePerCharacter]);
        /* Return it, except it's at least one character */
        return MAX(numChars, 1u) * bytesPerCharacter;
    }
    else {
        /* We have some columns */
        CGFloat advancePerColumn = [self advancePerColumn];
        //spaceRequiredForNColumns = N * (advancePerColumn) - spaceBetweenColumns
        CGFloat fractionalColumns = (availableSpace + [self advanceBetweenColumns]) / advancePerColumn;
        NSUInteger columnCount = (NSUInteger)fmax(1., HFFloor(fractionalColumns));
        return columnCount * bytesPerColumn;
    }
}


- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    HFASSERT(bytesPerLine > 0);
    NSUInteger bytesPerColumn = [self _effectiveBytesPerColumn];
    CGFloat result;
    if (bytesPerColumn == 0) {
        result = (CGFloat)((2. * [self horizontalContainerInset]) + [self advancePerCharacter] * (bytesPerLine / [self bytesPerCharacter]));
    }
    else {
        HFASSERT(bytesPerLine % bytesPerColumn == 0);
        result = (CGFloat)((2. * [self horizontalContainerInset]) + [self advancePerColumn] * (bytesPerLine / bytesPerColumn) - [self advanceBetweenColumns]);
    }
    return result;
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
    HFRegisterViewForWindowAppearanceChanges(self, @selector(_windowDidChangeKeyStatus:), ! _hftvflags.registeredForAppNotifications);
    _hftvflags.registeredForAppNotifications = YES;
    [super viewDidMoveToWindow];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    HFUnregisterViewForWindowAppearanceChanges(self, NO /* appToo */);
    [super viewWillMoveToWindow:newWindow];
}

/* Computes the character at the given index for selection, properly handling the case where the point is outside the bounds */
- (NSUInteger)characterAtPointForSelection:(NSPoint)point {
    NSPoint mungedPoint = point;
    // shift us right by half an advance so that we trigger at the midpoint of each character, rather than at the x origin
    mungedPoint.x += [self advancePerCharacter] / (CGFloat)2.;
    // make sure we're inside the bounds
    const NSRect bounds = [self bounds];
    mungedPoint.x = HFMax(NSMinX(bounds), mungedPoint.x);
    mungedPoint.x = HFMin(NSMaxX(bounds), mungedPoint.x);
    mungedPoint.y = HFMax(NSMinY(bounds), mungedPoint.y);
    mungedPoint.y = HFMin(NSMaxY(bounds), mungedPoint.y);
    return [self indexOfCharacterAtPoint:mungedPoint];
}

- (NSUInteger)maximumCharacterIndex {
    //returns the maximum character index that the selection may lie on.  It is one beyond the last byte index, to represent the cursor at the end of the document.
    return [[self data] length] / [self bytesPerCharacter];
}

- (void)mouseDown:(NSEvent *)event {
    HFASSERT(_hftvflags.withinMouseDown == 0);
    _hftvflags.withinMouseDown = 1;
    [self _forceCaretOnIfHasCaretTimer];
    NSPoint mouseDownLocation = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self characterAtPointForSelection:mouseDownLocation];
    
    characterIndex = MIN(characterIndex, [self maximumCharacterIndex]); //characterIndex may be one beyond the last index, to represent the cursor at the end of the document
    [[self representer] beginSelectionWithEvent:event forCharacterIndex:characterIndex];
    
    /* Drive the event loop in event tracking mode until we're done */
    HFASSERT(_hftvflags.receivedMouseUp == NO); //paranoia - detect any weird recursive invocations
    NSDate *endDate = [NSDate distantFuture];
    
    /* Start periodic events for autoscroll */
    [NSEvent startPeriodicEventsAfterDelay:0.1 withPeriod:0.05];
    
    NSPoint autoscrollLocation = mouseDownLocation;
    while (! _hftvflags.receivedMouseUp) {
        @autoreleasepool {
        NSEvent *ev = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask | NSPeriodicMask untilDate:endDate inMode:NSEventTrackingRunLoopMode dequeue:YES];
        
        if ([ev type] == NSPeriodic) {
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
                characterIndex = [self characterAtPointForSelection:autoscrollLocation];
                characterIndex = MIN(characterIndex, [self maximumCharacterIndex]);
                [[self representer] continueSelectionWithEvent:ev forCharacterIndex:characterIndex];
            }
        }
        else if ([ev type] == NSLeftMouseDragged) {
            autoscrollLocation = [self convertPoint:[ev locationInWindow] fromView:nil];
        }
        
        [NSApp sendEvent:ev];
        } // @autoreleasepool
    }
    
    [NSEvent stopPeriodicEvents];
    
    _hftvflags.receivedMouseUp = NO;
    _hftvflags.withinMouseDown = 0;
}

- (void)mouseDragged:(NSEvent *)event {
    if (! _hftvflags.withinMouseDown) return;
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self characterAtPointForSelection:location];
    characterIndex = MIN(characterIndex, [self maximumCharacterIndex]);
    [[self representer] continueSelectionWithEvent:event forCharacterIndex:characterIndex];    
}

- (void)mouseUp:(NSEvent *)event {
    if (! _hftvflags.withinMouseDown) return;
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self characterAtPointForSelection:location];
    characterIndex = MIN(characterIndex, [self maximumCharacterIndex]);
    [[self representer] endSelectionWithEvent:event forCharacterIndex:characterIndex];
    _hftvflags.receivedMouseUp = YES;
}

- (void)keyDown:(NSEvent *)event {
    HFASSERT(event != NULL);
    [self interpretKeyEvents:@[event]];
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
