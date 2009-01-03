//
//  HFLineCountingView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFLineCountingView.h"

#define USE_TEXT_VIEW 0
#define TIME_LINE_NUMBERS 0

#define INVALID_LINE_COUNT NSUIntegerMax

#if TIME_LINE_NUMBERS
@interface HFTimingTextView : NSTextView
@end
@implementation HFTimingTextView
- (void)drawRect:(NSRect)rect {
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    [super drawRect:rect];
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    NSLog(@"TextView line number time: %f", endTime - startTime);
}
@end
#endif

@implementation HFLineCountingView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        layoutManager = [[NSLayoutManager alloc] init];
	textStorage = [[NSTextStorage alloc] init];
	[textStorage addLayoutManager:layoutManager];
	textContainer = [[NSTextContainer alloc] init];
        [textContainer setLineFragmentPadding:(CGFloat)5];
        [textContainer setContainerSize:NSMakeSize([self bounds].size.width, [textContainer containerSize].height)];
	[layoutManager addTextContainer:textContainer];
#if USE_TEXT_VIEW
        Class textViewClass;
#if TIME_LINE_NUMBERS
        textViewClass = [HFTimingTextView class];
#else
        textViewClass = [NSTextView class];
#endif
        textView = [[textViewClass alloc] initWithFrame:[self bounds]];
        [textView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [textView setEditable:NO];
        [textView setSelectable:NO];
        [textView setDrawsBackground:NO];
        [self addSubview:textView];
#endif
    }
    return self;
}

- (void)dealloc {
    [font release];
    [layoutManager release];
    [textStorage release];
    [super dealloc];
}

- (BOOL)isFlipped { return YES; }

- (void)drawGradientWithClip:(NSRect)clip {
    USE(clip);
    NSImage *image = HFImageNamed(@"HFMetalGradient");
    [image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:(CGFloat)1.];
}

- (void)drawDividerWithClip:(NSRect)clipRect {
    [[NSColor lightGrayColor] set];
    NSRect bounds = [self bounds];
    NSRect lineRect = bounds;
    lineRect.origin.x += lineRect.size.width - 2;
    lineRect.size.width = 1;
    NSRectFill(NSIntersectionRect(lineRect, clipRect));
    [[NSColor whiteColor] set];
    lineRect.origin.x += 1;
    NSRectFill(NSIntersectionRect(lineRect, clipRect));	
}

static inline int common_prefix_length(const char *a, const char *b) {
    int i;
    for (i=0; ; i++) {
        char ac = a[i];
        char bc = b[i];
        if (ac != bc || ac == 0 || bc == 0) break;
    }
    return i;
}

/* Drawing with NSLayoutManager is necessary because the 10_2 typesetting behavior used by the old string drawing does the wrong thing for fonts like Bitstream Vera Sans Mono.  Also it's an optimization for drawing the shadow. */
- (void)drawLineNumbersWithClipLayoutManagerPerLine:(NSRect)clipRect {
#if TIME_LINE_NUMBERS
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
#endif
    NSUInteger previousTextStorageCharacterCount = [textStorage length];
    
    CGFloat verticalOffset = ld2f(lineRangeToDraw.location - floorl(lineRangeToDraw.location));
    NSRect textRect = [self bounds];
    textRect.size.height = lineHeight;
    textRect.origin.y -= verticalOffset * lineHeight;
    unsigned long long lineIndex = HFFPToUL(floorl(lineRangeToDraw.location));
    unsigned long long lineValue = lineIndex * bytesPerLine;
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(lineRangeToDraw.length + lineRangeToDraw.location) - floorl(lineRangeToDraw.location)));
    char previousBuff[256];
    int previousStringLength = (int)previousTextStorageCharacterCount;
    BOOL conversionResult = [[textStorage string] getCString:previousBuff maxLength:sizeof previousBuff encoding:NSASCIIStringEncoding];
    HFASSERT(conversionResult);
    while (linesRemaining--) {
	if (NSIntersectsRect(textRect, clipRect)) {
	    NSString *replacementCharacters = nil;
            NSRange replacementRange;
            char buff[256];
            int newStringLength = snprintf(buff, sizeof buff, "%llu", lineValue);
            HFASSERT(newStringLength > 0);
            int prefixLength = common_prefix_length(previousBuff, buff);
            HFASSERT(prefixLength <= newStringLength);
            HFASSERT(prefixLength <= previousStringLength);
            replacementRange = NSMakeRange(prefixLength, previousStringLength - prefixLength);
            replacementCharacters = [[NSString alloc] initWithBytesNoCopy:buff + prefixLength length:newStringLength - prefixLength encoding:NSASCIIStringEncoding freeWhenDone:NO];
	    NSUInteger glyphCount;
	    [textStorage replaceCharactersInRange:replacementRange withString:replacementCharacters];
	    if (previousTextStorageCharacterCount == 0) {
		NSDictionary *atts = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8], NSForegroundColorAttributeName, nil];
		[textStorage setAttributes:atts range:NSMakeRange(0, newStringLength)];
                [atts release];
	    }
	    glyphCount = [layoutManager numberOfGlyphs];
	    if (glyphCount > 0) {
		CGFloat maxX = NSMaxX([layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphCount - 1 effectiveRange:NULL]);
		[layoutManager drawGlyphsForGlyphRange:NSMakeRange(0, glyphCount) atPoint:NSMakePoint(textRect.origin.x + textRect.size.width - maxX, textRect.origin.y)];
	    }
	    previousTextStorageCharacterCount = newStringLength;
	    [replacementCharacters release];
            memcpy(previousBuff, buff, newStringLength + 1);
            previousStringLength = newStringLength;
	}
	textRect.origin.y += lineHeight;
	lineIndex++;
	lineValue = HFSum(lineValue, bytesPerLine);
    }
#if TIME_LINE_NUMBERS
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    NSLog(@"Line number time: %f", endTime - startTime);
#endif
}

- (void)drawLineNumbersWithClipStringDrawing:(NSRect)clipRect {
    CGFloat verticalOffset = ld2f(lineRangeToDraw.location - floorl(lineRangeToDraw.location));
    NSRect textRect = [self bounds];
    textRect.size.height = lineHeight;
    textRect.size.width -= 5;
    textRect.origin.y -= verticalOffset * lineHeight + 1;
    unsigned long long lineIndex = HFFPToUL(floorl(lineRangeToDraw.location));
    unsigned long long lineValue = lineIndex * bytesPerLine;
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(lineRangeToDraw.length + lineRangeToDraw.location) - floorl(lineRangeToDraw.location)));
    if (! textAttributes) {
        NSMutableParagraphStyle *mutableStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [mutableStyle setAlignment:NSRightTextAlignment];
        NSParagraphStyle *paragraphStyle = [mutableStyle copy];
        [mutableStyle release];
        textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8], NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
        [paragraphStyle release];
    }
    while (linesRemaining--) {
	if (NSIntersectsRect(textRect, clipRect)) {
            char buff[256];
            int newStringLength = snprintf(buff, sizeof buff, "%llu", lineValue);
            HFASSERT(newStringLength > 0);
	    NSString *string = [[NSString alloc] initWithBytesNoCopy:buff length:newStringLength encoding:NSASCIIStringEncoding freeWhenDone:NO];
            [string drawInRect:textRect withAttributes:textAttributes];
            [string release];
	}
	textRect.origin.y += lineHeight;
	lineIndex++;
	lineValue = HFSum(lineValue, bytesPerLine);
    }
}

- (NSUInteger)characterCountForLineRange:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax);
    NSUInteger lineCount = ll2l(range.length);
    const NSUInteger stride = bytesPerLine;
    unsigned long long lineValue = HFProductULL(range.location, bytesPerLine);
    NSUInteger characterCount = lineCount /* newlines */;
    while (lineCount--) {
        characterCount += HFCountDigitsBase10(lineValue);
        lineValue += stride;
    }
    return characterCount;
}

- (NSString *)createLineStringForRange:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax);
    NSUInteger lineCount = ll2l(range.length);
    const NSUInteger stride = bytesPerLine;
    unsigned long long lineValue = HFProductULL(range.location, bytesPerLine);
    NSUInteger characterCount = [self characterCountForLineRange:range];
    char *buffer = check_malloc(characterCount);
    NSUInteger bufferIndex = 0;
    
    while (lineCount--) {
        int charCount = sprintf(buffer + bufferIndex, "%llu", lineValue);
        HFASSERT(charCount > 0);
        bufferIndex += charCount;
        buffer[bufferIndex++] = '\n';   
        lineValue += stride;
    }
    HFASSERT(bufferIndex == characterCount);
    
    NSString *string = [[NSString alloc] initWithBytesNoCopy:(void *)buffer length:bufferIndex encoding:NSASCIIStringEncoding freeWhenDone:YES];
    return string;
}

- (void)updateLayoutManagerWithLineIndex:(unsigned long long)startingLineIndex lineCount:(NSUInteger)linesRemaining {
    const BOOL debug = NO;
    [textStorage beginEditing];
    
    if (storedLineCount == INVALID_LINE_COUNT) {
        /* This usually indicates that our bytes per line changed, and we need to just recalculate everything */
        NSString *string = [self createLineStringForRange:HFRangeMake(startingLineIndex, linesRemaining)];
        [textStorage replaceCharactersInRange:NSMakeRange(0, [textStorage length]) withString:string];
        [string release];
        
    }
    else {
        HFRange leftRangeToReplace, rightRangeToReplace;
        HFRange leftRangeToStore, rightRangeToStore;

        HFRange oldRange = HFRangeMake(storedLineIndex, storedLineCount);
        HFRange newRange = HFRangeMake(startingLineIndex, linesRemaining);
        HFRange rangeToPreserve = HFIntersectionRange(oldRange, newRange);
        
        if (rangeToPreserve.length == 0) {
            leftRangeToReplace = oldRange;
            leftRangeToStore = newRange;
            rightRangeToReplace = HFZeroRange;
            rightRangeToStore = HFZeroRange;
        }
        else {
            if (debug) NSLog(@"Preserving %llu", rangeToPreserve.length);
            HFASSERT(HFRangeIsSubrangeOfRange(rangeToPreserve, newRange));
            HFASSERT(HFRangeIsSubrangeOfRange(rangeToPreserve, oldRange));
            const unsigned long long maxPreserve = HFMaxRange(rangeToPreserve);
            leftRangeToReplace = HFRangeMake(oldRange.location, rangeToPreserve.location - oldRange.location);
            leftRangeToStore = HFRangeMake(newRange.location, rangeToPreserve.location - newRange.location);
            rightRangeToReplace = HFRangeMake(maxPreserve, HFMaxRange(oldRange) - maxPreserve);
            rightRangeToStore = HFRangeMake(maxPreserve, HFMaxRange(newRange) - maxPreserve);
        }
        
        if (debug) NSLog(@"Changing %@ -> %@", HFRangeToString(oldRange), HFRangeToString(newRange));
        if (debug) NSLog(@"LEFT: %@ -> %@", HFRangeToString(leftRangeToReplace), HFRangeToString(leftRangeToStore));
        if (debug) NSLog(@"RIGHT: %@ -> %@", HFRangeToString(rightRangeToReplace), HFRangeToString(rightRangeToStore));
    
        HFASSERT(leftRangeToReplace.length == 0 || HFRangeIsSubrangeOfRange(leftRangeToReplace, oldRange));
        HFASSERT(rightRangeToReplace.length == 0 || HFRangeIsSubrangeOfRange(rightRangeToReplace, oldRange));
        
        if (leftRangeToReplace.length > 0 || leftRangeToStore.length > 0) {
            NSUInteger charactersToDelete = [self characterCountForLineRange:leftRangeToReplace];
            NSRange rangeToDelete = NSMakeRange(0, charactersToDelete);
            if (leftRangeToStore.length == 0) {
                [textStorage deleteCharactersInRange:rangeToDelete];
                if (debug) NSLog(@"Left deleting text range %@", NSStringFromRange(rangeToDelete));
            }
            else {
                NSString *leftRangeString = [self createLineStringForRange:leftRangeToStore];
                [textStorage replaceCharactersInRange:rangeToDelete withString:leftRangeString];
                if (debug) NSLog(@"Replacing text range %@ with %@", NSStringFromRange(rangeToDelete), leftRangeString);
                [leftRangeString release];
            }
        }
        
        if (rightRangeToReplace.length > 0 || rightRangeToStore.length > 0) {
            NSUInteger charactersToDelete = [self characterCountForLineRange:rightRangeToReplace];
            NSUInteger stringLength = [textStorage length];
            HFASSERT(charactersToDelete <= stringLength);
            NSRange rangeToDelete = NSMakeRange(stringLength - charactersToDelete, charactersToDelete);
            if (rightRangeToStore.length == 0) {
                [textStorage deleteCharactersInRange:rangeToDelete];
                if (debug) NSLog(@"Right deleting text range %@", NSStringFromRange(rangeToDelete));
            }
            else {
                NSString *rightRangeString = [self createLineStringForRange:rightRangeToStore];
                [textStorage replaceCharactersInRange:rangeToDelete withString:rightRangeString];
                if (debug) NSLog(@"Replacing text range %@ with %@ (for range %@)", NSStringFromRange(rangeToDelete), rightRangeString, HFRangeToString(rightRangeToStore));
                [rightRangeString release];
            }
        }
    }
        
    if (! textAttributes) {
        NSMutableParagraphStyle *mutableStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [mutableStyle setAlignment:NSRightTextAlignment];
        NSParagraphStyle *paragraphStyle = [mutableStyle copy];
        [mutableStyle release];
        textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8], NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
        [paragraphStyle release];
        [textStorage setAttributes:textAttributes range:NSMakeRange(0, [textStorage length])];
    }
    
    [textStorage endEditing];
    
#if ! NDEBUG
    NSString *comparisonString = [self createLineStringForRange:HFRangeMake(startingLineIndex, linesRemaining)];
    if (! [comparisonString isEqualToString:[textStorage string]]) {
        NSLog(@"Not equal!");
        NSLog(@"Expected:\n%@", comparisonString);
        NSLog(@"Actual:\n%@", [textStorage string]);
    }
    HFASSERT([comparisonString isEqualToString:[textStorage string]]);
    [comparisonString release];
#endif
    
    storedLineIndex = startingLineIndex;
    storedLineCount = linesRemaining;
}

- (void)updateTextView {
    unsigned long long lineIndex = HFFPToUL(floorl(lineRangeToDraw.location));
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(lineRangeToDraw.length + lineRangeToDraw.location) - floorl(lineRangeToDraw.location)));
    
    NSString *string = [self createLineStringForRange:HFRangeMake(lineIndex, linesRemaining)];
    [textView setString:string];
    [string release];
}

- (void)updateTextViewAttributes {
    NSMutableParagraphStyle *mutableStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [mutableStyle setAlignment:NSRightTextAlignment];
    NSParagraphStyle *paragraphStyle = [mutableStyle copy];
    [mutableStyle release];
    NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8], NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
    [paragraphStyle release];
    [textView setTypingAttributes:attributes];
    NSTextStorage *storage = [textView textStorage];
    [storage setAttributes:attributes range:NSMakeRange(0, [storage length])];
    [attributes release];
}

- (void)drawLineNumbersWithClipSingleStringDrawing:(NSRect)clipRect {
    unsigned long long lineIndex = HFFPToUL(floorl(lineRangeToDraw.location));
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(lineRangeToDraw.length + lineRangeToDraw.location) - floorl(lineRangeToDraw.location)));

    CGFloat linesToVerticallyOffset = ld2f(lineRangeToDraw.location - floorl(lineRangeToDraw.location));
    CGFloat verticalOffset = linesToVerticallyOffset * lineHeight + 1;
    NSRect textRect = [self bounds];
    textRect.size.width -= 5;
    textRect.origin.y -= verticalOffset;
    textRect.size.height += verticalOffset;
    
    if (! textAttributes) {
        NSMutableParagraphStyle *mutableStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [mutableStyle setAlignment:NSRightTextAlignment];
        [mutableStyle setMinimumLineHeight:lineHeight];
        [mutableStyle setMaximumLineHeight:lineHeight];
        NSParagraphStyle *paragraphStyle = [mutableStyle copy];
        [mutableStyle release];
        textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8], NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
        [paragraphStyle release];
    }    
    
    
    NSString *string = [self createLineStringForRange:HFRangeMake(lineIndex, linesRemaining)];
    [string drawInRect:textRect withAttributes:textAttributes];
    [string release];
}

- (void)drawLineNumbersWithClipSingleStringCellDrawing:(NSRect)clipRect {
    const CGFloat cellTextContainerPadding = 2.f;
    unsigned long long lineIndex = HFFPToUL(floorl(lineRangeToDraw.location));
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(lineRangeToDraw.length + lineRangeToDraw.location) - floorl(lineRangeToDraw.location)));
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    
    CGFloat linesToVerticallyOffset = ld2f(lineRangeToDraw.location - floorl(lineRangeToDraw.location));
    CGFloat verticalOffset = linesToVerticallyOffset * lineHeight + 1;
    NSLog(@"Vertical offset: %f", verticalOffset);
    NSRect textRect = [self bounds];
    textRect.size.width -= 5;
    textRect.origin.y -= verticalOffset;
    textRect.origin.x += cellTextContainerPadding;
    textRect.size.height += verticalOffset;
    
    if (! textAttributes) {
        NSMutableParagraphStyle *mutableStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [mutableStyle setAlignment:NSRightTextAlignment];
        [mutableStyle setMinimumLineHeight:lineHeight];
        [mutableStyle setMaximumLineHeight:lineHeight];
        NSParagraphStyle *paragraphStyle = [mutableStyle copy];
        [mutableStyle release];
        textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8], NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
        [paragraphStyle release];
    }
    
    NSString *string = [self createLineStringForRange:HFRangeMake(lineIndex, linesRemaining)];
    NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:string attributes:textAttributes];
    [string release];
    NSCell *cell = [[NSCell alloc] initTextCell:@""];
    [cell setAttributedStringValue:attributedString];
    [cell drawWithFrame:textRect inView:nil];
    [[NSColor purpleColor] set];
    NSFrameRect(textRect);
    [cell release];
    [attributedString release];
}

- (void)drawLineNumbersWithClipFullLayoutManager:(NSRect)clipRect {
    unsigned long long lineIndex = HFFPToUL(floorl(lineRangeToDraw.location));
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(lineRangeToDraw.length + lineRangeToDraw.location) - floorl(lineRangeToDraw.location)));
    if (lineIndex != storedLineIndex || linesRemaining != storedLineCount) {
        [self updateLayoutManagerWithLineIndex:lineIndex lineCount:linesRemaining];
    }
    
    CGFloat verticalOffset = ld2f(lineRangeToDraw.location - floorl(lineRangeToDraw.location));
    
    NSPoint textPoint = [self bounds].origin;
    textPoint.y -= verticalOffset * lineHeight;
    [layoutManager drawGlyphsForGlyphRange:NSMakeRange(0, [layoutManager numberOfGlyphs]) atPoint:textPoint];
}

- (void)drawLineNumbersWithClip:(NSRect)clipRect {
#if TIME_LINE_NUMBERS
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
#endif
    const NSInteger drawingMode = (useStringDrawingPath ? 1 : 2);
    switch (drawingMode) {
        case 0:
            [self drawLineNumbersWithClipLayoutManagerPerLine:clipRect];
            break;
        case 1:
            [self drawLineNumbersWithClipStringDrawing:clipRect];
            break;
        case 2:
            [self drawLineNumbersWithClipFullLayoutManager:clipRect];
            break;
        case 3:
            [self drawLineNumbersWithClipSingleStringDrawing:clipRect];
            break;
        case 4:
            [self drawLineNumbersWithClipSingleStringCellDrawing:clipRect];
            break;
    }
#if TIME_LINE_NUMBERS
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    NSLog(@"Line number time: %f", endTime - startTime);
#endif
    
}

- (void)drawRect:(NSRect)clipRect {
    [self drawGradientWithClip:clipRect];
    [self drawDividerWithClip:clipRect];
#if ! USE_TEXT_VIEW
    [self drawLineNumbersWithClip:clipRect];
#endif
}

- (void)setLineRangeToDraw:(HFFPRange)range {
    if (! HFFPRangeEqualsRange(range, lineRangeToDraw)) {
        lineRangeToDraw = range;
#if USE_TEXT_VIEW
        [self updateTextView];
#endif
        [self setNeedsDisplay:YES];
    }
}

- (HFFPRange)lineRangeToDraw {
    return lineRangeToDraw;
}

- (void)setBytesPerLine:(NSUInteger)val {
    if (bytesPerLine != val) {
        bytesPerLine = val;
        storedLineCount = INVALID_LINE_COUNT;
        [self setNeedsDisplay:YES];
    }
}

- (NSUInteger)bytesPerLine {
    return bytesPerLine;
}

- (BOOL)canUseStringDrawingPathForFont:(NSFont *)testFont {
    NSString *name = [testFont fontName];
    return [name isEqualToString:@"Monaco"] || [name isEqualToString:@"Courier"];
}

- (void)setFont:(NSFont *)val {
    if (val != font) {
        [font release];
        font = [val retain];
	[textStorage deleteCharactersInRange:NSMakeRange(0, [textStorage length])]; //delete the characters so we know to set the font next time we render
        [textAttributes release];
        textAttributes = nil;
        storedLineCount = INVALID_LINE_COUNT;
        useStringDrawingPath = [self canUseStringDrawingPathForFont:font];
#if USE_TEXT_VIEW
        [self updateTextViewAttributes];
#endif
        [self setNeedsDisplay:YES];
    }
}

- (NSFont *)font {
    return font;
}

- (void)setLineHeight:(CGFloat)height {
    if (lineHeight != height) {
        lineHeight = height;
        [self setNeedsDisplay:YES];
    }
}

- (CGFloat)lineHeight {
    return lineHeight;
}

- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    [textContainer setContainerSize:NSMakeSize([self bounds].size.width, [textContainer containerSize].height)];
}

- (void)mouseDown:(NSEvent *)event {
    [representer cycleLineNumberFormat];
}

- (void)setRepresenter:(HFLineCountingRepresenter *)rep {
    representer = rep;
}

- (HFLineCountingRepresenter *)representer {
    return representer;
}

@end
