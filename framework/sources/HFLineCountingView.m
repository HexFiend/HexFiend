//
//  HFLineCountingView.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFLineCountingView.h>
#import <HexFiend/HFLineCountingRepresenter.h>
#import <HexFiend/HFFunctions.h>

#define INVALID_LINE_COUNT NSUIntegerMax

@implementation HFLineCountingView

- (void)dealloc {
    HFUnregisterViewForWindowAppearanceChanges(self, registeredForAppNotifications);
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:_font forKey:@"HFFont"];
    [coder encodeDouble:_lineHeight forKey:@"HFLineHeight"];
    [coder encodeObject:_representer forKey:@"HFRepresenter"];
    [coder encodeInt64:_bytesPerLine forKey:@"HFBytesPerLine"];
    [coder encodeInt64:_lineNumberFormat forKey:@"HFLineNumberFormat"];
    [coder encodeBool:useStringDrawingPath forKey:@"HFUseStringDrawingPath"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    _font = [coder decodeObjectForKey:@"HFFont"];
    _lineHeight = (CGFloat)[coder decodeDoubleForKey:@"HFLineHeight"];
    _representer = [coder decodeObjectForKey:@"HFRepresenter"];
    _bytesPerLine = (NSUInteger)[coder decodeInt64ForKey:@"HFBytesPerLine"];
    _lineNumberFormat = (NSUInteger)[coder decodeInt64ForKey:@"HFLineNumberFormat"];
    useStringDrawingPath = [coder decodeBoolForKey:@"HFUseStringDrawingPath"];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)getLineNumberFormatString:(char *)outString length:(NSUInteger)length {
    HFLineNumberFormat format = self.lineNumberFormat;
    if (format == HFLineNumberFormatDecimal) {
        strlcpy(outString, "%llu", length);
    }
    else if (format == HFLineNumberFormatHexadecimal) {
        // we want a format string like %08llX
        snprintf(outString, length, "%%0%lullX", (unsigned long)self.representer.digitCount);
    }
    else {
        strlcpy(outString, "", length);
    }
}

- (void)windowDidChangeKeyStatus:(NSNotification *)note {
    USE(note);
    [self setNeedsDisplay:YES];
}

- (void)viewDidMoveToWindow {
    HFRegisterViewForWindowAppearanceChanges(self, @selector(windowDidChangeKeyStatus:), !registeredForAppNotifications);
    registeredForAppNotifications = YES;
    [super viewDidMoveToWindow];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    HFUnregisterViewForWindowAppearanceChanges(self, NO);
    [super viewWillMoveToWindow:newWindow];
}

- (NSColor *)borderColor {
    if (HFDarkModeEnabled()) {
        if (@available(macOS 10.14, *)) {
            return [NSColor separatorColor];
        }
    }
    return [NSColor darkGrayColor];
}

- (NSColor *)backgroundColor {
    if (HFDarkModeEnabled()) {
        return [NSColor colorWithCalibratedWhite:0.13 alpha:1];
    }
    return [NSColor colorWithCalibratedWhite:0.87 alpha:1];
}

- (void)drawGradientWithClip:(NSRect)clip {
    [self.backgroundColor set];
    NSRectFillUsingOperation(clip, NSCompositeSourceOver);
    
    NSInteger shadowEdge = _representer.interiorShadowEdge;
    
    if (shadowEdge >= 0) {
        const CGFloat shadowWidth = 6;
        NSWindow *window = self.window;
        BOOL drawActive = (window == nil || [window isKeyWindow] || [window isMainWindow]);
        HFDrawShadow(HFGraphicsGetCurrentContext(), self.bounds, shadowWidth, shadowEdge, drawActive, clip);
    }
}

- (void)drawDividerWithClip:(NSRect)clipRect {
    USE(clipRect);
    
    NSInteger edges = _representer.borderedEdges;
    NSRect bounds = self.bounds;
    
    
    // -1 means to draw no edges
    if (edges == -1) {
        edges = 0;
    }
    
    [self.borderColor set];
    
    if ((edges & (1 << NSMinXEdge)) > 0) {
        NSRect lineRect = bounds;
        lineRect.size.width = 1;
        lineRect.origin.x = 0;
        if (NSIntersectsRect(lineRect, clipRect)) {
            NSRectFillUsingOperation(lineRect, NSCompositeSourceOver);
        }
    }
    
    if ((edges & (1 << NSMaxXEdge)) > 0) {
        NSRect lineRect = bounds;
        lineRect.size.width = 1;
        lineRect.origin.x = NSMaxX(bounds) - lineRect.size.width;
        if (NSIntersectsRect(lineRect, clipRect)) {
            NSRectFillUsingOperation(lineRect, NSCompositeSourceOver);
        }
    }
    
    if ((edges & (1 << NSMinYEdge)) > 0) {
        NSRect lineRect = bounds;
        lineRect.size.height = 1;
        lineRect.origin.y = 0;
        if (NSIntersectsRect(lineRect, clipRect)) {
            NSRectFillUsingOperation(lineRect, NSCompositeSourceOver);
        }
    }
    
    if ((edges & (1 << NSMaxYEdge)) > 0) {
        NSRect lineRect = bounds;
        lineRect.size.height = 1;
        lineRect.origin.y = NSMaxY(bounds) - lineRect.size.height;
        if (NSIntersectsRect(lineRect, clipRect)) {
            NSRectFillUsingOperation(lineRect, NSCompositeSourceOver);
        }
    }
    
    
    // Backwards compatibility to always draw a border on the edge with the interior shadow
    
    NSRect lineRect = bounds;
    lineRect.size.width = 1;
    NSInteger shadowEdge = _representer.interiorShadowEdge;
    if (shadowEdge == NSMaxXEdge) {
        lineRect.origin.x = NSMaxX(bounds) - lineRect.size.width;
    } else if (shadowEdge == NSMinXEdge) {
        lineRect.origin.x = NSMinX(bounds);
    } else {
        lineRect = NSZeroRect;
    }
    
    if (NSIntersectsRect(lineRect, clipRect)) {
        NSRectFillUsingOperation(lineRect, NSCompositeSourceOver);
    }
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

- (NSColor *)foregroundColor {
    if (@available(macOS 10.10, *)) {
        return [NSColor secondaryLabelColor];
    } else {
        return [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8];
    }
}

- (void)drawLineNumbersWithClipStringDrawing:(NSRect)clipRect {
    CGFloat verticalOffset = ld2f(_lineRangeToDraw.location - floorl(_lineRangeToDraw.location));
    NSRect textRect = self.bounds;
    textRect.size.height = _lineHeight;
    textRect.size.width -= 5;
    textRect.origin.y -= verticalOffset * _lineHeight + 1;
    unsigned long long lineIndex = HFFPToUL(floorl(_lineRangeToDraw.location));
    unsigned long long lineValue = lineIndex * _bytesPerLine;
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(_lineRangeToDraw.length + _lineRangeToDraw.location) - floorl(_lineRangeToDraw.location)));
    if (! textAttributes) {
        NSMutableParagraphStyle *mutableStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [mutableStyle setAlignment:NSRightTextAlignment];
        NSParagraphStyle *paragraphStyle = [mutableStyle copy];
        textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:_font, NSFontAttributeName, [self foregroundColor], NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
    }
    
    char formatString[64];
    [self getLineNumberFormatString:formatString length:sizeof formatString];
    
    while (linesRemaining--) {
        if (NSIntersectsRect(textRect, clipRect)) {
            char buff[256];
            int newStringLength = snprintf(buff, sizeof buff, formatString, lineValue);
            HFASSERT(newStringLength > 0);
            NSString *string = [[NSString alloc] initWithBytesNoCopy:buff length:newStringLength encoding:NSASCIIStringEncoding freeWhenDone:NO];
            [string drawInRect:textRect withAttributes:textAttributes];
        }
        textRect.origin.y += _lineHeight;
        lineIndex++;
        if (linesRemaining > 0) lineValue = HFSum(lineValue, _bytesPerLine); //we could do this unconditionally, but then we risk overflow
    }
}

- (NSUInteger)characterCountForLineRange:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax);
    NSUInteger characterCount;
    
    NSUInteger lineCount = ll2l(range.length);
    const NSUInteger stride = _bytesPerLine;
    HFLineCountingRepresenter *rep = self.representer;
    HFLineNumberFormat format = self.lineNumberFormat;
    if (format == HFLineNumberFormatDecimal) {
        unsigned long long lineValue = HFProductULL(range.location, _bytesPerLine);
        characterCount = lineCount /* newlines */;
        while (lineCount--) {
            characterCount += HFCountDigitsBase10(lineValue);
            lineValue += stride;
        }
    }
    else if (format == HFLineNumberFormatHexadecimal) {
        characterCount = ([rep digitCount] + 1) * lineCount; // +1 for newlines
    }
    else {
        characterCount = -1;
    }
    return characterCount;
}

- (NSString *)newLineStringForRange:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax);
    if(range.length == 0)
        return [[NSString alloc] init]; // Placate the analyzer.
    
    NSUInteger lineCount = ll2l(range.length);
    const NSUInteger stride = _bytesPerLine;
    unsigned long long lineValue = HFProductULL(range.location, _bytesPerLine);
    NSUInteger characterCount = [self characterCountForLineRange:range];
    char *buffer = check_malloc(characterCount);
    NSUInteger bufferIndex = 0;
    
    char formatString[64];
    [self getLineNumberFormatString:formatString length:sizeof formatString];
    
    while (lineCount--) {
        int charCount = sprintf(buffer + bufferIndex, formatString, lineValue);
        HFASSERT(charCount > 0);
        bufferIndex += charCount;
        buffer[bufferIndex++] = '\n';   
        lineValue += stride;
    }
    HFASSERT(bufferIndex == characterCount);
    
    NSString *string = [[NSString alloc] initWithBytesNoCopy:(void *)buffer length:bufferIndex encoding:NSASCIIStringEncoding freeWhenDone:YES];
    return string;
}

- (void)drawLineNumbersWithClipSingleStringDrawing:(NSRect)clipRect {
    USE(clipRect);
    unsigned long long lineIndex = HFFPToUL(floorl(_lineRangeToDraw.location));
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(_lineRangeToDraw.length + _lineRangeToDraw.location) - floorl(_lineRangeToDraw.location)));
    
    CGFloat linesToVerticallyOffset = ld2f(_lineRangeToDraw.location - floorl(_lineRangeToDraw.location));
    CGFloat verticalOffset = linesToVerticallyOffset * _lineHeight + 1;
    NSRect textRect = self.bounds;
    textRect.size.width -= 5;
    textRect.origin.y -= verticalOffset;
    textRect.size.height += verticalOffset + _lineHeight;
    
    if (! textAttributes) {
        NSMutableParagraphStyle *mutableStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [mutableStyle setAlignment:NSRightTextAlignment];
        [mutableStyle setMinimumLineHeight:_lineHeight];
        [mutableStyle setMaximumLineHeight:_lineHeight];
        NSParagraphStyle *paragraphStyle = [mutableStyle copy];
        textAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:_font, NSFontAttributeName, [self foregroundColor], NSForegroundColorAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil];
    }
    
    NSString *string = [self newLineStringForRange:HFRangeMake(lineIndex, linesRemaining)];
    [string drawInRect:textRect withAttributes:textAttributes];
}

- (void)drawLineNumbersWithClip:(NSRect)clipRect {
    NSInteger drawingMode = (useStringDrawingPath ? 1 : 3);
    switch (drawingMode) {
        // Drawing can't be done right if fonts are wider than expected, but all
        // of these have rather nasty behavior in that case. I've commented what
        // that behavior is; the comment is hypothetical 'could' if it shouldn't
        // actually be a problem in practice.
        // TODO: Make a drawing mode that is "Fonts could get clipped if too wide"
        //       because that seems like better behavior than any of these.
        case 1:
            // Last characters could get omitted (*not* clipped) if too wide.
            // Also, most fonts have bottoms clipped (very unsigntly).
            [self drawLineNumbersWithClipStringDrawing:clipRect];
            break;
        case 3:
            // Fonts could wrap if too wide (breaks numbering).
            // *Note that that this is the only mode that generally works.*
            [self drawLineNumbersWithClipSingleStringDrawing:clipRect];
            break;
    }
}

- (void)drawRect:(NSRect)clipRect {
    [self drawGradientWithClip:clipRect];
    [self drawDividerWithClip:clipRect];
    [self drawLineNumbersWithClip:clipRect];
}

- (void)setLineRangeToDraw:(HFFPRange)range {
    if (! HFFPRangeEqualsRange(range, _lineRangeToDraw)) {
        _lineRangeToDraw = range;
        [self setNeedsDisplay:YES];
    }
}

- (void)setBytesPerLine:(NSUInteger)val {
    if (_bytesPerLine != val) {
        _bytesPerLine = val;
        [self setNeedsDisplay:YES];
    }
}

- (void)setLineNumberFormat:(HFLineNumberFormat)format {
    if (format != _lineNumberFormat) {
        _lineNumberFormat = format;
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)canUseStringDrawingPathForFont:(NSFont *)testFont {
    NSString *name = [testFont fontName];
    // No, Menlo does not work here.
    return [name isEqualToString:@"Monaco"] || [name isEqualToString:@"Courier"] || [name isEqualToString:@"Consolas"];
}

- (void)setFont:(NSFont *)val {
    if (val != _font) {
        _font = [val copy];
        textAttributes = nil;
        useStringDrawingPath = [self canUseStringDrawingPathForFont:_font];
        [self setNeedsDisplay:YES];
    }
}

- (void)setLineHeight:(CGFloat)height {
    if (_lineHeight != height) {
        _lineHeight = height;
        [self setNeedsDisplay:YES];
    }
}

- (void)mouseDown:(NSEvent *)event {
    USE(event);
    [_representer cycleLineNumberFormat];
}

- (void)scrollWheel:(NSEvent *)scrollEvent {
    [_representer.controller scrollWithScrollEvent:scrollEvent];
}

+ (NSUInteger)digitsRequiredToDisplayLineNumber:(unsigned long long)lineNumber inFormat:(HFLineNumberFormat)format {
    switch (format) {
        case HFLineNumberFormatDecimal: return HFCountDigitsBase10(lineNumber);
        case HFLineNumberFormatHexadecimal: return HFCountDigitsBase16(lineNumber);
        default: return 0;
    }
}

@end
