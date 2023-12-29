//
//  HFLineCountingView.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFLineCountingView.h>
#import <HexFiend/HFLineCountingRepresenter.h>
#import <HexFiend/HFTextRepresenter_Internal.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

#define INVALID_LINE_COUNT NSUIntegerMax

static const CGFloat kShadowWidth = 6;

@implementation HFLineCountingView

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:_font forKey:@"HFFont"];
    [coder encodeDouble:_lineHeight forKey:@"HFLineHeight"];
    [coder encodeObject:_representer forKey:@"HFRepresenter"];
    [coder encodeInt64:_bytesPerLine forKey:@"HFBytesPerLine"];
    [coder encodeInt64:_lineNumberFormat forKey:@"HFLineNumberFormat"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    _font = [coder decodeObjectForKey:@"HFFont"];
    _lineHeight = (CGFloat)[coder decodeDoubleForKey:@"HFLineHeight"];
    _representer = [coder decodeObjectForKey:@"HFRepresenter"];
    _bytesPerLine = (NSUInteger)[coder decodeInt64ForKey:@"HFBytesPerLine"];
    _lineNumberFormat = (NSUInteger)[coder decodeInt64ForKey:@"HFLineNumberFormat"];
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

- (NSColor *)borderColor {
    if (@available(macOS 10.14, *)) {
        return [NSColor separatorColor];
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
    NSRectFillUsingOperation(clip, NSCompositingOperationSourceOver);
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
            NSRectFillUsingOperation(lineRect, NSCompositingOperationSourceOver);
        }
    }
    
    if ((edges & (1 << NSMaxXEdge)) > 0) {
        NSRect lineRect = bounds;
        lineRect.size.width = 1;
        lineRect.origin.x = NSMaxX(bounds) - lineRect.size.width;
        if (NSIntersectsRect(lineRect, clipRect)) {
            NSRectFillUsingOperation(lineRect, NSCompositingOperationSourceOver);
        }
    }
    
    if ((edges & (1 << NSMinYEdge)) > 0) {
        NSRect lineRect = bounds;
        lineRect.size.height = 1;
        lineRect.origin.y = 0;
        if (NSIntersectsRect(lineRect, clipRect)) {
            NSRectFillUsingOperation(lineRect, NSCompositingOperationSourceOver);
        }
    }
    
    if ((edges & (1 << NSMaxYEdge)) > 0) {
        NSRect lineRect = bounds;
        lineRect.size.height = 1;
        lineRect.origin.y = NSMaxY(bounds) - lineRect.size.height;
        if (NSIntersectsRect(lineRect, clipRect)) {
            NSRectFillUsingOperation(lineRect, NSCompositingOperationSourceOver);
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
        NSRectFillUsingOperation(lineRect, NSCompositingOperationSourceOver);
    }
}

- (NSColor *)foregroundColor {
    return [NSColor secondaryLabelColor];
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

- (void)drawLineNumbersWithClipSingleStringDrawing {
    unsigned long long lineIndex = HFFPToUL(floorl(_lineRangeToDraw.location));
    NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(_lineRangeToDraw.length + _lineRangeToDraw.location) - floorl(_lineRangeToDraw.location)));
    
    CGFloat verticalOffset = [HFTextRepresenter verticalOffsetForLineRange:_lineRangeToDraw];
    NSRect textRect = self.bounds;
    textRect.size.width -= (kShadowWidth - 1);
    textRect.origin.y -= (verticalOffset * _lineHeight);
    textRect.size.height += (verticalOffset * _lineHeight) + _lineHeight;
    
    if (! textAttributes) {
        NSMutableParagraphStyle *mutableStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [mutableStyle setAlignment:NSTextAlignmentRight];
        [mutableStyle setMinimumLineHeight:_lineHeight];
        [mutableStyle setMaximumLineHeight:_lineHeight];
        NSParagraphStyle *paragraphStyle = [mutableStyle copy];
        textAttributes = @{
           NSFontAttributeName: _font,
           NSForegroundColorAttributeName: [self foregroundColor],
           NSParagraphStyleAttributeName: paragraphStyle,
        };
    }
    
    NSString *string = [self newLineStringForRange:HFRangeMake(lineIndex, linesRemaining)];
    [string drawInRect:textRect withAttributes:textAttributes];
}

- (void)drawRect:(NSRect)__unused dirtyRect {
    NSRect clipRect = self.bounds;
    [self drawGradientWithClip:clipRect];
    [self drawDividerWithClip:clipRect];
    [self drawLineNumbersWithClipSingleStringDrawing];
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

- (void)setFont:(NSFont *)val {
    if (val != _font) {
        _font = [val copy];
        textAttributes = nil;
        [self setNeedsDisplay:YES];
    }
}

- (void)setLineHeight:(CGFloat)height {
    if (_lineHeight != height) {
        _lineHeight = height;
        textAttributes = nil;
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
