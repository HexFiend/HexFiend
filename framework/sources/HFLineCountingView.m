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
        layoutManager = [[NSLayoutManager alloc] init];
		textStorage = [[NSTextStorage alloc] init];
		[textStorage addLayoutManager:layoutManager];
		NSTextContainer *container = [[NSTextContainer alloc] init];
		[layoutManager addTextContainer:container];
		[container release];
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

/* Drawing with NSLayoutManager is necessary because the 10_2 typesetting behavior used by the old string drawing does the wrong thing for fonts like Bitstream Vera Sans Mono.  Also it's an optimization for drawing the shadow. */
- (void)drawLineNumbersWithClip:(NSRect)clipRect {
	USE(clipRect);
	NSUInteger previousTextStorageCharacterCount = [textStorage length];
	
	CGFloat verticalOffset = ld2f(lineRangeToDraw.location - floorl(lineRangeToDraw.location));
	NSRect textRect = [self bounds];
	textRect.size.height = lineHeight;
	textRect.origin.y -= verticalOffset * lineHeight;
	unsigned long long lineIndex = HFFPToUL(floorl(lineRangeToDraw.location));
	unsigned long long lineValue = lineIndex * bytesPerLine;
	NSUInteger linesRemaining = ll2l(HFFPToUL(ceill(lineRangeToDraw.length + lineRangeToDraw.location) - floorl(lineRangeToDraw.location)));
	while (linesRemaining--) {
		if (NSIntersectsRect(textRect, clipRect)) {
			NSString *string = [[NSString alloc] initWithFormat:@"%llu", lineValue];
			NSUInteger newStringLength = [string length];
			NSUInteger glyphCount;
			[textStorage replaceCharactersInRange:NSMakeRange(0, previousTextStorageCharacterCount) withString:string];
			if (previousTextStorageCharacterCount == 0) {
				NSDictionary *atts = [[NSDictionary alloc] initWithObjectsAndKeys:font, NSFontAttributeName, [NSColor colorWithCalibratedWhite:(CGFloat).1 alpha:(CGFloat).8], NSForegroundColorAttributeName, nil];
				[textStorage setAttributes:atts range:NSMakeRange(0, newStringLength)];
			}
			glyphCount = [layoutManager numberOfGlyphs];
			if (glyphCount > 0) {
				CGFloat maxX = NSMaxX([layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphCount - 1 effectiveRange:NULL]);
				[layoutManager drawGlyphsForGlyphRange:NSMakeRange(0, glyphCount) atPoint:NSMakePoint(textRect.origin.x + textRect.size.width - maxX, textRect.origin.y)];
			}
			previousTextStorageCharacterCount = newStringLength;
			[string release];
		}
		textRect.origin.y += lineHeight;
		lineIndex++;
		lineValue = HFSum(lineValue, bytesPerLine);
	}
}

- (void)drawRect:(NSRect)clipRect {
	[self drawGradientWithClip:clipRect];
	[self drawDividerWithClip:clipRect];
	[self drawLineNumbersWithClip:clipRect];
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

- (void)setFont:(NSFont *)val {
    if (val != font) {
        [font release];
        font = [val retain];
		[textStorage deleteCharactersInRange:NSMakeRange(0, [textStorage length])]; //delete the characters so we know to set the font next time we render
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
