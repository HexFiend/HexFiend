//
//  HFTextVisualStyleRun.m
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "HFTextVisualStyleRun.h"


@implementation HFTextVisualStyleRun

- (id)init {
    self = [super init];
    scale = 1.;
    shouldDraw = YES;
    return self;
}

- (void)dealloc {
    [foregroundColor release];
    [backgroundColor release];
    [bookmarkStarts release];
    [bookmarkExtents release];
    [super dealloc];
}

- (NSColor *)foregroundColor {
    return [[foregroundColor retain] autorelease]; 
}

- (void)setForegroundColor:(NSColor *)theForegroundColor {
    if (foregroundColor != theForegroundColor) {
        [foregroundColor release];
        foregroundColor = [theForegroundColor retain];
    }
}

- (NSColor *)backgroundColor {
    return [[backgroundColor retain] autorelease]; 
}

- (void)setBackgroundColor:(NSColor *)theBackgroundColor {
    if (backgroundColor != theBackgroundColor) {
        [backgroundColor release];
        backgroundColor = [theBackgroundColor retain];
    }
}

- (BOOL)shouldDraw {
    return shouldDraw;
}

- (void)setShouldDraw:(BOOL)val {
    shouldDraw = val;
}

- (CGFloat)scale {
    return scale;
}

- (void)setScale:(CGFloat)val {
    scale = val;
}

- (NSIndexSet *)bookmarkExtents {
    return bookmarkExtents;
}

- (void)setBookmarkExtents:(NSIndexSet *)val {
    if (bookmarkExtents != val) {
	[bookmarkExtents release];
	bookmarkExtents = [val copy];
    }
}

- (NSIndexSet *)bookmarkStarts {
    return bookmarkStarts;
}

- (void)setBookmarkStarts:(NSIndexSet *)val {
    if (bookmarkStarts != val) {
	[bookmarkStarts release];
	bookmarkStarts = [val copy];
    }
}

- (NSIndexSet *)bookmarkEnds {
    return bookmarkEnds;
}

- (void)setBookmarkEnds:(NSIndexSet *)ends {
    if (bookmarkEnds != ends) {
	[bookmarkEnds release];
	bookmarkEnds = [ends copy];
    }
}


- (NSRange)range {
    return range;
}

- (void)setRange:(NSRange)theRange {
    range = theRange;
}

- (void)set {
    [foregroundColor set];
    if (scale != (CGFloat)1.0) {
        CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
        CGAffineTransform tm = CGContextGetTextMatrix(ctx);
        /* Huge hack - adjust downward a little bit if we are scaling */
        tm = CGAffineTransformTranslate(tm, 0, -.25 * (scale - 1));
        tm = CGAffineTransformScale(tm, scale, scale);
        CGContextSetTextMatrix(ctx, tm);
    }
}

- (NSUInteger)hash {
    //simple
    return [foregroundColor hash] ^ [backgroundColor hash] ^ range.length ^ range.location ^ shouldDraw ^ [bookmarkStarts hash] ^ [bookmarkEnds hash] ^ [bookmarkExtents hash];
}

// return whether two objects are equal, properly handling NULL
static BOOL objectsAreEqual(id a, id b) {
    if (a == b) return YES; //identical objects are equal
    if (!a || !b) return NO; //if exactly one is NULL we're not equal.  They're not both NULL beacuse then a==b would have passed.
    return [a isEqual:b];
    
}

- (BOOL)isEqual:(HFTextVisualStyleRun *)run {
    /* Check each field for equality. */
    if (! NSEqualRanges(range, run->range)) return NO;
    if (scale != run->scale) return NO;
    if (shouldDraw != run->shouldDraw) return NO;
    if (! [run isKindOfClass:[HFTextVisualStyleRun class]]) return NO;
    if (! objectsAreEqual(foregroundColor, run->foregroundColor)) return NO;
    if (! objectsAreEqual(backgroundColor, run->backgroundColor)) return NO;
    if (! objectsAreEqual(bookmarkStarts, run->bookmarkStarts)) return NO;
    if (! objectsAreEqual(bookmarkExtents, run->bookmarkExtents)) return NO;
    if (! objectsAreEqual(bookmarkEnds, run->bookmarkEnds)) return NO;
    return YES;
}

@end
