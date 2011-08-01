//
//  HFRepresenterTextViewCallout.m
//  HexFiend_2
//
//  Created by Peter Ammon on 7/31/11.
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import "HFRepresenterTextViewCallout.h"
#import "HFRepresenterTextView.h"

static const CGFloat HFTeardropRadius = 12;
static const CGFloat HFTeadropTipScale = 2.5;

static NSPoint rotatePoint(NSPoint center, NSPoint point, CGFloat percent) {
    CGFloat radians = percent * M_PI * 2;
    CGFloat x = point.x - center.x;
    CGFloat y = point.y - center.y;
    CGFloat newX = x * cos(radians) + y * sin(radians);
    CGFloat newY = x * -sin(radians) + y * cos(radians);
    return NSMakePoint(center.x + newX, center.y + newY);
}

static NSPoint scalePoint(NSPoint center, NSPoint point, CGFloat percent) {
    CGFloat x = point.x - center.x;
    CGFloat y = point.y - center.y;
    CGFloat newX = x * percent;
    CGFloat newY = y * percent;
    return NSMakePoint(center.x + newX, center.y + newY);
}

static NSBezierPath *copyTeardropPath(void) {
    static NSBezierPath *sPath = nil;
    if (! sPath) {
        
        CGFloat radius = HFTeardropRadius;
        CGFloat rotation = 0;
        CGFloat droppiness = .15;
        CGFloat tipScale = HFTeadropTipScale;
        CGFloat tipLengthFromCenter = radius * tipScale;
        NSPoint bulbCenter = NSMakePoint(-tipLengthFromCenter, 0);
        
        NSPoint triangleCenter = rotatePoint(bulbCenter, NSMakePoint(bulbCenter.x + radius, bulbCenter.y), rotation);
        NSPoint dropCorner1 = rotatePoint(bulbCenter, triangleCenter, droppiness / 2);
        NSPoint dropCorner2 = rotatePoint(bulbCenter, triangleCenter, -droppiness / 2);
        NSPoint dropTip = scalePoint(bulbCenter, triangleCenter, tipScale);
        
        NSBezierPath *path = [[NSBezierPath alloc] init];
        [path appendBezierPathWithArcWithCenter:bulbCenter radius:radius startAngle:-rotation * 360 + droppiness * 180. endAngle:-rotation * 360 - droppiness * 180. clockwise:NO];
        
        [path moveToPoint:dropCorner1];
        [path lineToPoint:dropTip];
        [path lineToPoint:dropCorner2];
        [path closePath];
        
        sPath = path;
    }
    return [sPath retain];
}


@implementation HFRepresenterTextViewCallout

@synthesize byteOffset = location, representedObject = representedObject, color = color, label = label;

- (id)init {
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc {
    [representedObject release];
    [color release];
    [label release];
    [super dealloc];
}

- (NSComparisonResult)compare:(HFRepresenterTextViewCallout *)callout {
    return [representedObject compare:[callout representedObject]];
}

+ (void)layoutCallouts:(NSArray *)callouts inView:(HFRepresenterTextView *)textView {
    
    // Keep track of how many drops are at a given location
    NSCountedSet *dropsPerByteLoc = [[NSCountedSet alloc] init];
    
    NSArray *sortedCallouts = [callouts sortedArrayUsingSelector:@selector(compare:)];
    FOREACH(HFRepresenterTextViewCallout *, callout, sortedCallouts) {
        NSUInteger byteLoc = [callout byteOffset];
        NSNumber *byteLocObj = [NSNumber numberWithUnsignedInteger:byteLoc];
        
        const NSUInteger collisions = [dropsPerByteLoc countForObject:byteLocObj];
        if (collisions > 8) continue; //don't try to show too much
        // Remember this byteLocObj for future collisions
        [dropsPerByteLoc addObject:byteLocObj];
        
        // Compute how much to rotate (as a percentage of a full rotation) based on collisions
        CGFloat rotation = .125;
        
        // Change rotation by collision count like so: 0->0, 1->-.125, 2->.125, 3->-.25, 4->.25...
        CGFloat additionalRotation = ((collisions + 1)/2) * rotation;
        if (collisions & 1) additionalRotation = -additionalRotation;
        rotation += additionalRotation;
        
        // a rotation of 0 corresponds to the tip pointing right
        
        NSPoint characterOrigin = [textView originForCharacterAtByteIndex:byteLoc];
        
        // move us slightly towards the character
        NSPoint teardropTipOrigin = NSMakePoint(characterOrigin.x + 1, characterOrigin.y + floor([textView lineHeight] / 8.));
        
        // store it
        callout->rotation = rotation;
        callout->tipOrigin = teardropTipOrigin;
        
    }
}

- (CGAffineTransform)teardropTransform {
    CGAffineTransform trans = CGAffineTransformMakeTranslation(tipOrigin.x, tipOrigin.y);
    trans = CGAffineTransformRotate(trans, rotation * M_PI * 2);
    return trans;
}

- (NSRect)teardropBaseRect {
    NSSize teardropSize = NSMakeSize(HFTeardropRadius * (1 + HFTeadropTipScale), HFTeardropRadius*2);
    NSRect result = NSMakeRect(-teardropSize.width, -teardropSize.height/2, teardropSize.width, teardropSize.height);
    return result;
}

- (void)drawWithClip:(NSRect)clip {
    
#define PERSPECTIVE_SHADOW 1
    
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    // Here's the font we'll use
    CTFontRef ctfont = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 1., NULL);
    if (ctfont) {
        
        // Set the CG font
        CGFontRef cgfont = ctfont ? CTFontCopyGraphicsFont(ctfont, NULL) : NULL;
        CGContextSetFont(ctx, cgfont);
        CGFontRelease(cgfont);
        
#if PERSPECTIVE_SHADOW
        
        CGFloat shadowXOffset = -6;
        CGFloat shadowYOffset = 0;
        CGFloat offscreenOffset = NSWidth(clip) + 100;
        
        // Figure out how much movement the shadow offset produces
        CGFloat shadowTranslationDistance = hypot(shadowXOffset, shadowYOffset);
#endif
        
        // Get characters
        NSUInteger labelLength = MIN([label length], kHFRepresenterTextViewCalloutMaxGlyphCount);
        UniChar calloutUniLabel[kHFRepresenterTextViewCalloutMaxGlyphCount];
        [label getCharacters:calloutUniLabel range:NSMakeRange(0, labelLength)];
        
        // Get our glyphs and advances
        CGGlyph glyphs[kHFRepresenterTextViewCalloutMaxGlyphCount];
        CGSize advances[kHFRepresenterTextViewCalloutMaxGlyphCount];
        CTFontGetGlyphsForCharacters(ctfont, calloutUniLabel, glyphs, labelLength);
        CTFontGetAdvancesForGlyphs(ctfont, kCTFontHorizontalOrientation, glyphs, advances, labelLength);

        // Count our glyphs. Note: this won't work with any label containing spaces, etc.
        NSUInteger glyphCount;
        for (glyphCount = 0; glyphCount < labelLength; glyphCount++) {
            if (glyphs[glyphCount] == 0) break;
        }
        
        // Get the teardrop
        NSBezierPath *teardrop = copyTeardropPath();
        
        // Set our color.
        [color set];
        
        CGContextSaveGState(ctx);
        CGAffineTransform transform = CGAffineTransformIdentity;
        CGContextBeginTransparencyLayer(ctx, NULL);
                        
#if PERSPECTIVE_SHADOW
        
        // Set the shadow
        NSShadow *shadow = [[NSShadow alloc] init];
        [shadow setShadowBlurRadius:5.];
        [shadow setShadowOffset:NSMakeSize(shadowXOffset - offscreenOffset, shadowYOffset)];
        [shadow setShadowColor:[NSColor colorWithDeviceWhite:0. alpha:.5]];
        [shadow set];
        [shadow release];
        
        // Draw the shadow first and separately
        transform = CGAffineTransformTranslate(transform, tipOrigin.x + offscreenOffset - shadowXOffset, tipOrigin.y - shadowYOffset);
        transform = CGAffineTransformRotate(transform, rotation * M_PI * 2 - atan2(shadowTranslationDistance, 2*HFTeardropRadius /* bulbHeight */));
        
        CGContextConcatCTM(ctx, transform);
        [teardrop fill];
        
        // Clear the shadow
        CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
        
        // Set up the transform so applying it will invert what we've done
        transform = CGAffineTransformInvert(transform);
#endif
        
        // Rotate and translate in preparation for drawing the teardrop
        transform = CGAffineTransformConcat([self teardropTransform], transform);
        CGContextConcatCTM(ctx, transform);
        
        // Draw the teardrop
        [teardrop fill];
        [teardrop release];
        
        // Draw the text with white and alpha.  Use blend mode copy so that we clip out the shadow, and when the transparency layer is ended we'll composite over the text.
        CGFloat textScale = (glyphCount == 1 ? 24 : 20);
        
        // we are flipped by default, so invert the rotation's sign to get the text direction
        const CGFloat textDirection = (rotation >= -.25 && rotation <= .25) ? -1 : 1;
        CGContextSetTextDrawingMode(ctx, kCGTextClip);
        CGAffineTransform textMatrix = CGAffineTransformMakeScale(-copysign(textScale, textDirection), copysign(textScale, textDirection)); //roughly the font size we want
        
        
        CGPoint positions[kHFRepresenterTextViewCalloutMaxGlyphCount];
        CGFloat totalAdvance = 0;
        for (NSUInteger i=0; i < glyphCount; i++) {
            // make sure to provide negative advances if necessary
            positions[i].x = copysign(totalAdvance, -textDirection);
            positions[i].y = 0;
            CGFloat advance = advances[i].width;
            // Workaround 5834794
            advance *= textScale;
            // Tighten up the advances a little
            advance *= .85;
            totalAdvance += advance;
        }
        
        
        // Compute the vertical offset
        CGFloat textYOffset = (glyphCount == 1 ? 4 : 5);                
        // LOL
        if ([label isEqualToString:@"6"] || [label isEqualToString:@"7"] == 7) textYOffset -= 1;
        
        
        // Apply this text matrix
        NSRect bulbRect = [self teardropBaseRect];
        textMatrix.tx = NSMinX(bulbRect) + HFTeardropRadius + copysign(totalAdvance/2, textDirection);
        
        if (textDirection < 0) {
            textMatrix.ty = NSMaxY(bulbRect) - textYOffset;
        } else {
            textMatrix.ty = NSMinY(bulbRect) + textYOffset;
        }
        
        CGContextSetTextMatrix(ctx, textMatrix);
        
        // Draw
        CGContextShowGlyphsAtPositions(ctx, glyphs, positions, glyphCount);
        
        CGContextSetBlendMode(ctx, kCGBlendModeCopy);
        CGContextSetGrayFillColor(ctx, 1., .75); //faint white fill
        CGContextFillRect(ctx, NSRectToCGRect(NSInsetRect(bulbRect, -20, -20)));
        
        // Done drawing, so composite
        CGContextEndTransparencyLayer(ctx);            
        CGContextRestoreGState(ctx); // this also restores the clip, which is important
        
#if 0
        // Lastly, draw the pin
        NSPoint pinStart = NSMakePoint(characterOrigin.x + .25, characterOrigin.y);
        NSPoint pinEnd = NSMakePoint(pinStart.x, pinStart.y + [self lineHeight]);
        [NSBezierPath setDefaultLineWidth:1.25];
        [NSBezierPath strokeLineFromPoint:pinStart toPoint:pinEnd];                               
#endif
    }
    CFRelease(ctfont);
}

- (NSRect)rect {
    // return the transformed teardrop rect
    return CGRectApplyAffineTransform([self teardropBaseRect], [self teardropTransform]);
}

#if 0
+ (void)layoutCalloutsOLD:(NSArray *)callouts inView:(HFRepresenterTextView *)textView {
    // Keep track of how many drops are at a given location
    NSCountedSet *dropsPerByteLoc = [[NSCountedSet alloc] init];
    
    // Figure out how tall our bulb is
    const NSRect bulbRect = [teardrop bounds];
    const NSSize bulbSize = bulbRect.size;
    
    const CGFloat radius = HFTeardropRadius;
    
    NSArray *sortedCallouts = [callouts sortedArrayUsingSelector:@selector(compare:)];
    FOREACH(HFRepresenterTextViewCallout *, callout, sortedCallouts) {
        
        NSUInteger byteLoc = [callout byteOffset];
        NSNumber *byteLocObj = [NSNumber numberWithUnsignedInt:byteLoc];
        
        const NSUInteger collisions = [dropsPerByteLoc countForObject:byteLocObj];
        if (collisions > 8) continue; //don't try to show too much
        // Remember this byteLocObj for future collisions
        [dropsPerByteLoc addObject:byteLocObj];
        
        
        NSUInteger bookmarkNum = [bookmarkNameObj integerValue];
        NSUInteger bookmarkLen = HFCountDigitsBase10(bookmarkNum);
        if (bookmarkLen < 1 || bookmarkLen > MAX_BOOKMARK_DIGIT_COUNT) continue; //erp
        
        
        CGContextSaveGState(ctx);
        const NSUInteger byteLoc = [byteLocObj unsignedLongValue];
        NSPoint characterOrigin = [self originForCharacterAtByteIndex:byteLoc];
        
        // Compute how much to rotate (as a percentage of a full rotation) based on collisions
        CGFloat rotation = .125;
        
        // Change rotation by collision count like so: 0->0, 1->-.125, 2->.125, 3->-.25, 4->.25...
        CGFloat additionalRotation = ((collisions + 1)/2) * rotation;
        if (collisions & 1) additionalRotation = -additionalRotation;
        rotation += additionalRotation;
        
        CGAffineTransform transform = CGAffineTransformIdentity;
        
        // move us slightly towards the character
        NSPoint teardropTipOrigin = NSMakePoint(characterOrigin.x + 1, characterOrigin.y + floor([self lineHeight] / 8.));
        
        CGContextBeginTransparencyLayer(ctx, NULL);            
        
        // Set the shadow
        [shadow set];            
        
#if PERSPECTIVE_SHADOW
        
        // Draw the shadow first and separately
        transform = CGAffineTransformTranslate(transform, teardropTipOrigin.x + offscreenOffset - shadowXOffset, teardropTipOrigin.y - shadowYOffset);
        transform = CGAffineTransformRotate(transform, rotation * M_PI * 2 - atan2(shadowTranslationDistance, bulbSize.height));
        
        CGContextConcatCTM(ctx, transform);
        [teardrop fill];
        
        // Clear the shadow
        CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
        
        // Set up the transform so applying it will invert what we've done
        transform = CGAffineTransformInvert(transform);
#endif
        
        // Rotate and translate in preparation for drawing the teardrop
        transform = CGAffineTransformTranslate(transform, teardropTipOrigin.x, teardropTipOrigin.y);
        transform = CGAffineTransformRotate(transform, rotation * M_PI * 2);
        CGContextConcatCTM(ctx, transform);
        
        // Draw the teardrop
        [teardrop fill];
        
        // Draw the text with white and alpha.  Use blend mode copy so that we clip out the shadow, and when the transparency layer is ended we'll composite over the text.
        CGFloat textScale = (bookmarkLen == 1 ? 24 : 20);
        
        // we are flipped by default, so invert the rotation's sign to get the text direction
        const CGFloat textDirection = (rotation >= -.25 && rotation <= .25) ? -1 : 1;
        CGContextSetTextDrawingMode(ctx, kCGTextClip);
        CGAffineTransform textMatrix = CGAffineTransformMakeScale(-copysign(textScale, textDirection), copysign(textScale, textDirection)); //roughly the font size we want
        
        CGPoint positions[MAX_BOOKMARK_DIGIT_COUNT];
        CGFloat totalAdvance = 0;
        for (NSUInteger i=0; i < bookmarkLen; i++) {
            positions[i].x = totalAdvance;
            positions[i].y = 0;
            CGFloat advance = advances[i].width;
            // Workaround 5834794
            advance *= textScale;
            // Tighten up the advances a little
            advance *= .85;
            totalAdvance += advance;
        }
        
        // Compute the vertical offset
        CGFloat textYOffset = (bookmarkLen == 1 ? 4 : 5);                
        // LOL
        if (bookmarkNum == 6 || bookmarkNum == 7) textYOffset -= 1;
        
        
        // Apply this text matrix 
        textMatrix.tx = NSMinX(bulbRect) + radius + copysign(totalAdvance/2, textDirection);
        
        if (textDirection < 0) {
            textMatrix.ty = NSMaxY(bulbRect) - textYOffset;
        } else {
            textMatrix.ty = NSMinY(bulbRect) + textYOffset;
        }
        
        CGContextSetTextMatrix(ctx, textMatrix);
        
        // Draw
        CGContextShowGlyphsAtPositions(ctx, glyphs, positions, bookmarkLen);
        
        CGContextSetBlendMode(ctx, kCGBlendModeCopy);
        CGContextSetGrayFillColor(ctx, 1., .75); //faint white fill
        CGContextFillRect(ctx, NSRectToCGRect(NSInsetRect(bulbRect, -20, -20)));
        
        // Done drawing, so composite
        CGContextEndTransparencyLayer(ctx);            
        CGContextRestoreGState(ctx); // this also restores the clip, which is important
        
        // Lastly, draw the pin
        NSPoint pinStart = NSMakePoint(characterOrigin.x + .25, characterOrigin.y);
        NSPoint pinEnd = NSMakePoint(pinStart.x, pinStart.y + [self lineHeight]);
        [NSBezierPath setDefaultLineWidth:1.25];
        [NSBezierPath strokeLineFromPoint:pinStart toPoint:pinEnd];                               
    }
    
}
#endif

@end
