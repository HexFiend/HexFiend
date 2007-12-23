//
//  HFLineCountingView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFLineCountingView.h"


@implementation HFLineCountingView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)drawRect:(NSRect)clipRect {
    USE(clipRect);
//    [[NSColor colorWithCalibratedWhite:(CGFloat).9 alpha:(CGFloat)1.] set];
//    NSRectFill(rect);
    NSImage *image = HFImageNamed(@"HFMetalGradient");

    [image setScalesWhenResized:YES];
    [image drawInRect:[self bounds] fromRect:NSZeroRect operation:NSCompositeCopy fraction:(CGFloat)1.];  
//    [[NSColor colorWithCalibratedWhite:.90 alpha:1.] set];
//    NSRectFill(clipRect);
    
    [[NSColor lightGrayColor] set];
    NSRect bounds = [self bounds];
    NSRect lineRect = bounds;
    lineRect.origin.x += lineRect.size.width - 2;
    lineRect.size.width = 1;
    NSRectFill(NSIntersectionRect(lineRect, clipRect));
    [[NSColor whiteColor] set];
    lineRect.origin.x += 1;
    NSRectFill(NSIntersectionRect(lineRect, clipRect));    
    
    if (font) {
        NSMutableParagraphStyle* style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [style setAlignment:NSRightTextAlignment];
        NSDictionary* atts = [NSDictionary dictionaryWithObjectsAndKeys:
            font, NSFontAttributeName,
            [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8], NSForegroundColorAttributeName,
            style, NSParagraphStyleAttributeName,
            nil];
        NSDictionary* atts2 = [NSDictionary dictionaryWithObjectsAndKeys:
            font, NSFontAttributeName,
            [NSColor colorWithCalibratedWhite:(CGFloat).9 alpha:(CGFloat)1.], NSForegroundColorAttributeName,
            style, NSParagraphStyleAttributeName,
            nil];
        
        CGFloat verticalOffset = ld2f(lineRangeToDraw.location - floorl(lineRangeToDraw.location));
        
        NSRect textRect = [self bounds];
        textRect.size.width -= (CGFloat)5.;
        textRect.size.height = lineHeight;
        textRect.origin.y -= verticalOffset * lineHeight;
        
        unsigned long long lineIndex = HFFPToUL(floorl(lineRangeToDraw.location));
        NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(lineRangeToDraw.length + lineRangeToDraw.location) - floorl(lineRangeToDraw.location)));
        while (linesRemaining--) {
            NSString *string = [NSString stringWithFormat:@"%llu", lineIndex * bytesPerLine];
            [string drawInRect:NSOffsetRect(textRect, 0, 1) withAttributes:atts2];
            [string drawInRect:textRect withAttributes:atts];
            textRect.origin.y += lineHeight;
            lineIndex++;
        }
    }
}

- (void)setLineRangeToDraw:(HFFPRange)range {
    if (! HFFPRangeEqualsRange(range, lineRangeToDraw)) {
        lineRangeToDraw = range;
        [self setNeedsDisplay:YES];
    }
}

- (HFFPRange)lineRangeToDraw {
    return lineRangeToDraw;
}

- (void)setBytesPerLine:(NSUInteger)val {
    if (bytesPerLine != val) {
        bytesPerLine = val;
        [self setNeedsDisplay:YES];
    }
}

- (NSUInteger)bytesPerLine {
    return bytesPerLine;
}

- (void)dealloc {
    [font release];
    [super dealloc];
}

- (void)setFont:(NSFont *)val {
    if (val != font) {
        [font release];
        font = [val retain];
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

@end
