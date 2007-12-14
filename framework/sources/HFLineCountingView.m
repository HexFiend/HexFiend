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

- (void)drawRect:(NSRect)rect {
    [[NSColor colorWithCalibratedWhite:(CGFloat).9 alpha:(CGFloat)1.] set];
    NSRectFill(rect);
    
    if (font) {
        NSMutableParagraphStyle* style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
        [style setAlignment:NSRightTextAlignment];
        NSDictionary* atts = [NSDictionary dictionaryWithObjectsAndKeys:
            font, NSFontAttributeName,
            [NSColor darkGrayColor], NSForegroundColorAttributeName,
            style, NSParagraphStyleAttributeName,
            nil];
        
        NSRect textRect = [self bounds];
        textRect.size.width -= (CGFloat)2.;
        textRect.size.height = lineHeight;
        
        unsigned long long lineIndex = lineRangeToDraw.location;
        NSUInteger linesRemaining = ll2l(lineRangeToDraw.length);
        while (linesRemaining--) {
            NSString *string = [NSString stringWithFormat:@"%llu", lineIndex * bytesPerLine];
            [string drawInRect:textRect withAttributes:atts];
            textRect.origin.y += lineHeight;
            lineIndex++;
        }
    }
}

- (void)setLineRangeToDraw:(HFRange)range {
    if (! HFRangeEqualsRange(range, lineRangeToDraw)) {
        lineRangeToDraw = range;
        [self setNeedsDisplay:YES];
    }
}

- (HFRange)lineRangeToDraw {
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
