//
//  HFRepresenterTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView_Internal.h>
#import <HexFiend/HFTextRepresenter.h>

static const NSTimeInterval HFCaretBlinkFrequency = 0.56;

@implementation HFRepresenterTextView

/* Returns the glyphs for the given string, using the given text view, and generating the glyphs if the glyphs parameter is not NULL */
- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingTextView:(NSTextView *)textView glyphs:(CGGlyph *)glyphs {
    NSUInteger glyphIndex, glyphCount;
    HFASSERT(string != NULL);
    HFASSERT(textView != NULL);
    NSGlyph nsglyphs[GLYPH_BUFFER_SIZE];
    [textView setString:string];
    [textView setNeedsDisplay:YES]; //ligature generation doesn't seem to happen without this, for some reason.  This seems very fragile!  We should find a better way to get this ligature information!!
    glyphCount = [[textView layoutManager] getGlyphs:nsglyphs range:NSMakeRange(0, GLYPH_BUFFER_SIZE)];
    if (glyphs != NULL) {
        /* Convert from unsigned int NSGlyphs to unsigned short CGGlyphs */
        for (glyphIndex = 0; glyphIndex < glyphCount; glyphIndex++) {
            HFASSERT(nsglyphs[glyphIndex] <= USHRT_MAX);
            glyphs[glyphIndex] = (CGGlyph)nsglyphs[glyphIndex];
        }
    }
    return glyphCount;
}

- (BOOL)_shouldHaveCaretTimer {
    NSWindow *window = [self window];
    if (window == NULL) return NO;
    if (! [window isKeyWindow]) return NO;
    if (self != [window firstResponder]) return NO;
    if (! _hftvflags.editable) return NO;
    NSArray *ranges = [[self representer] displayedSelectedContentsRanges];
    if ([ranges count] != 1) return NO;
    NSRange range = [[ranges objectAtIndex:0] rangeValue];
    if (range.length != 0) return NO;
    return YES;
}

- (NSPoint)originForCharacterAtIndex:(NSUInteger)index {
    NSPoint result;
    NSUInteger bytesPerLine = [self bytesPerLine];
    result.y = (index / bytesPerLine) * [self lineHeight];
    result.x = [self horizontalContainerInset] + (index % bytesPerLine) * ([self advancePerByte] + [self spaceBetweenBytes]);
    return result;
}

- (NSUInteger)indexOfCharacterAtPoint:(NSPoint)point {
    NSUInteger bytesPerLine = [self bytesPerLine];
    CGFloat floatRow = (CGFloat)floor(point.y / [self lineHeight]);
    CGFloat floatColumn = (CGFloat)round((point.x - [self horizontalContainerInset]) / ([self advancePerByte] + [self spaceBetweenBytes]));
    floatColumn = (CGFloat)fmax(floatColumn, 0); //to handle the case of dragging within the container inset
    HFASSERT(floatRow >= 0 && floatRow <= NSUIntegerMax);
    HFASSERT(floatColumn >= 0 && floatColumn <= NSUIntegerMax);
    NSUInteger row = (NSUInteger)floatRow;
    NSUInteger column = (NSUInteger)floatColumn;
    return row * bytesPerLine + column;
}

- (NSRect)caretRect {
    NSArray *ranges = [[self representer] displayedSelectedContentsRanges];
    HFASSERT([ranges count] == 1);
    NSRange range = [[ranges objectAtIndex:0] rangeValue];
    HFASSERT(range.length == 0);
    
    NSPoint caretBaseline = [self originForCharacterAtIndex:range.location];
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

- (void)_updateCaretTimer {
    BOOL hasCaretTimer = !! caretTimer;
    BOOL shouldHaveCaretTimer = [self _shouldHaveCaretTimer];
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

- (void)updateSelectedRanges {
    [self _updateCaretTimer];
    [self _forceCaretOnIfHasCaretTimer];
    [self setNeedsDisplay:YES]; /* redraw us for the selection changes */
}

- (void)drawCaretIfNecessaryWithClip:(NSRect)clipRect {
    NSRect caretRect = NSIntersectionRect(caretRectToDraw, clipRect);
    if (! NSIsEmptyRect(caretRect)) {
        [[NSColor blackColor] set];
        NSRectFill(caretRect);
        lastDrawnCaretRect = caretRect;
    }
}

- (BOOL)shouldHaveForegroundHighlightColor {
    NSWindow *window = [self window];
    if (window == nil) return YES;
    if (! [window isKeyWindow]) return NO;
    if (self != [window firstResponder]) return NO;
    return YES;
}

- (void)drawSelectionIfNecessaryWithClip:(NSRect)clipRect {
    NSArray *ranges = [[self representer] displayedSelectedContentsRanges];
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
                NSPoint startPoint = [self originForCharacterAtIndex:characterIndex];
                NSPoint endPoint = [self originForCharacterAtIndex:endCharacterForThisLineOfRange];
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

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)becomeFirstResponder {
    BOOL result = [super becomeFirstResponder];
    [self _updateCaretTimer];
    return result;
}

- (BOOL)resignFirstResponder {
    BOOL result = [super resignFirstResponder];
    [self _updateCaretTimer];
    return result;
}

- initWithRepresenter:(HFTextRepresenter *)rep {
    [super initWithFrame:NSMakeRect(0, 0, 1, 1)];
    horizontalContainerInset = 4;
    representer = rep;
    _hftvflags.editable = YES;
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
        NSLog(@"Set font to %@ (%f)", font, defaultLineHeight);
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
        if (data) {
            NSUInteger oldLength = [data length];
            NSUInteger newLength = [val length];
            const unsigned char *oldBytes = (const unsigned char *)[data bytes];
            const unsigned char *newBytes = (const unsigned char *)[val bytes];
            NSUInteger firstDifferingIndex = HFIndexOfFirstByteThatDiffers(oldBytes, oldLength, newBytes, newLength);
            if (firstDifferingIndex == NSNotFound) {
                /* Nothing to do!  Data is identical! */
            }
            else {
                NSUInteger line = firstDifferingIndex / [self bytesPerLine];
                if (line <= 1) {
                    /* No point in invalidating a region - we'll invalidate everything */
                    [self setNeedsDisplay:YES];
                }
                else {
                    CGFloat yOrigin = (line - 1) * [self lineHeight];
                    NSRect bounds = [self bounds];
                    NSRect dirtyRect = NSMakeRect(0, yOrigin, NSWidth(bounds), NSHeight(bounds) - yOrigin);
                    [self setNeedsDisplayInRect:dirtyRect];
                }
            }
        }
        [data release];
        data = [val copy];
        [self _updateCaretTimer];
    }
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
    NSWindow *window = [self window];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    if (window) {
        NSLog(@"Removing for %p", window);
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
    return [[NSColor controlAlternatingRowBackgroundColors] objectAtIndex:0];
}

- (NSColor *)backgroundColorForLine:(NSUInteger)line {
    NSArray *colors = [NSColor controlAlternatingRowBackgroundColors];
    NSUInteger colorCount = [colors count];
    NSUInteger colorIndex = line % colorCount;
    if (colorIndex == 0) return nil; //will be drawn by empty space
    else return [colors objectAtIndex:colorIndex]; 
}

- (NSUInteger)bytesPerLine {
    return [[self representer] bytesPerLine];
}


- (void)_drawLineBackgrounds:(NSRect)clip withLineHeight:(CGFloat)lineHeight maxLines:(NSUInteger)maxLines {
    NSRect bounds = [self bounds];
    NSUInteger lineIndex;
    NSRect lineRect = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), lineHeight);
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
    CGFloat spaceAdvancement = [self spaceBetweenBytes];
    CGFloat advanceAmount = ([self advancePerByte] + spaceAdvancement) * bytesBetweenVerticalGuides;
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

- (void)drawTextWithClip:(NSRect)clip {
    USE(clip);
    UNIMPLEMENTED_VOID();
}

- (void)drawRect:(NSRect)clip {
    [[self backgroundColorForEmptySpace] set];
    NSRectFill(clip);
    
    NSRect bounds = [self bounds];
    CGFloat lineHeight = [self lineHeight];

    NSUInteger bytesPerLine = [self bytesPerLine];
    if (bytesPerLine == 0) return;
    NSUInteger byteCount = [data length];
    [[font screenFont] set];
    
    [self _drawLineBackgrounds:clip withLineHeight:[self lineHeight] maxLines:MIN((byteCount + bytesPerLine - 1) / bytesPerLine, (NSUInteger)ceil(NSHeight(bounds) / lineHeight))];
    [self drawSelectionIfNecessaryWithClip:clip];

    NSColor *textColor = [NSColor blackColor];
    [textColor set];
    [self drawTextWithClip:clip];
    
    [self drawVerticalGuideLines:clip];
    [self drawCaretIfNecessaryWithClip:clip];
}

- (NSUInteger)availableLineCount {
    CGFloat result = (CGFloat)ceil(NSHeight([self bounds]) / [self lineHeight]);
    HFASSERT(result >= 0.);
    HFASSERT(result <= NSUIntegerMax);
    return (NSUInteger)result;
}

- (NSUInteger)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
    CGFloat result = (CGFloat)ceil(viewHeight / [self lineHeight]);
    HFASSERT(result >= 0.);
    HFASSERT(result <= NSUIntegerMax);
    return (NSUInteger)result;
}

- (void)setFrameSize:(NSSize)size {
    NSUInteger currentBytesPerLine = [self bytesPerLine];
    NSUInteger currentLineCount = [self maximumAvailableLinesForViewHeight:NSHeight([self bounds])];
    [super setFrameSize:size];
    NSUInteger newBytesPerLine = [self maximumBytesPerLineForViewWidth:size.width];
    NSUInteger newLineCount = [self maximumAvailableLinesForViewHeight:NSHeight([self bounds])];
    HFControllerPropertyBits bits = 0;
    if (newBytesPerLine != currentBytesPerLine) bits |= (HFControllerBytesPerLine | HFControllerDisplayedRange);
    if (newLineCount != currentLineCount) bits |= HFControllerDisplayedRange;
    if (bits) [[self representer] viewChangedProperties:bits];
}

- (CGFloat)advancePerByte {
    UNIMPLEMENTED();
}

- (CGFloat)spaceBetweenBytes {
    UNIMPLEMENTED();
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    CGFloat availableSpace = (CGFloat)(viewWidth - 2. * [self horizontalContainerInset]);
    CGFloat spaceBetweenBytes = [self spaceBetweenBytes];
    CGFloat advancePerByte = [self advancePerByte];
    //spaceRequiredForNBytes = N * (advancePerByte + spaceBetweenBytes) - spaceBetweenBytes
    CGFloat fractionalBytesPerLine = (availableSpace + spaceBetweenBytes) / (advancePerByte + spaceBetweenBytes);
    return (NSUInteger)fmax(1., floor(fractionalBytesPerLine));
}


- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    HFASSERT(bytesPerLine > 0);
    CGFloat spaceBetweenBytes = [self spaceBetweenBytes];
    CGFloat advancePerByte = [self advancePerByte];
    return (CGFloat)(2. * [self horizontalContainerInset] + bytesPerLine * (advancePerByte + spaceBetweenBytes) - spaceBetweenBytes);
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

- (void)_windowDidChangeKeyStatus:(NSNotification *)note {
    USE(note);
    [self _updateCaretTimer];
    if ([[note name] isEqualToString:NSWindowDidBecomeKeyNotification]) {
        [self _forceCaretOnIfHasCaretTimer];
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

/* When dragging the mouse outside the view's bounds, we want the "closest point" behavior */
- (NSPoint)pointInBoundsClosestToPoint:(NSPoint)point {
    NSRect bounds = [self bounds];
    point.x = HFMax(NSMinX(bounds), point.x);
    point.x = HFMin(NSMaxX(bounds), point.x);
    point.y = HFMax(NSMinY(bounds), point.y);
    point.y = HFMin(NSMaxY(bounds), point.y);
    return point;
}

- (void)mouseDown:(NSEvent *)event {
    [self _forceCaretOnIfHasCaretTimer];
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self indexOfCharacterAtPoint:[self pointInBoundsClosestToPoint:location]];
    characterIndex = MIN(characterIndex, [[self data] length]); //characterIndex may be one beyond the last index, to represent the cursor at the end of the document
    [[self representer] beginSelectionWithEvent:event forCharacterIndex:characterIndex];
    
    /* Drive the event loop in event tracking mode until we're done */
    HFASSERT(_hftvflags.receivedMouseUp == NO); //paranoia - detect any weird recursive invocations
    NSDate *endDate = [NSDate distantFuture];
    while (! _hftvflags.receivedMouseUp) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        NSEvent *event = [NSApp nextEventMatchingMask: NSLeftMouseUpMask | NSLeftMouseDraggedMask untilDate:endDate inMode:NSEventTrackingRunLoopMode dequeue:YES];
        [NSApp sendEvent:event]; 
        [pool drain];
    }
    _hftvflags.receivedMouseUp = NO;
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self indexOfCharacterAtPoint:[self pointInBoundsClosestToPoint:location]];
    characterIndex = MIN(characterIndex, [[self data] length]);
    [[self representer] continueSelectionWithEvent:event forCharacterIndex:characterIndex];    
}

- (void)mouseUp:(NSEvent *)event {
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    NSUInteger characterIndex = [self indexOfCharacterAtPoint:[self pointInBoundsClosestToPoint:location]];
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
    if ([string isKindOfClass:[NSAttributedString class]]) string = [string string];
    [[self representer] insertText:string];
}

- (void)doCommandBySelector:(SEL)sel {
    NSLog(@"%s%s", _cmd, sel);
    [super doCommandBySelector:sel];
}

- (IBAction)selectAll:sender {
    [[self representer] selectAll:sender];
}

@end
