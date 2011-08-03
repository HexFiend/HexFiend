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

static const CGFloat HFShadowXOffset = -6;
static const CGFloat HFShadowYOffset = 0;
static const CGFloat HFShadowOffscreenHack = 3100;

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

@synthesize byteOffset = byteOffset, representedObject = representedObject, color = color, label = label;

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

static double normalizeAngle(double x) {
    /* Convert an angle to the range [0, 1). We typically only generate angles that are off by a full rotation, so a loop isn't too bad. */
    while (x >= 1) x -= 1.;
    while (x < 0) x += 1.;
    return x;
}

+ (void)layoutCallouts:(NSArray *)callouts inView:(HFRepresenterTextView *)textView {
    
    // Keep track of how many drops are at a given location
    NSCountedSet *dropsPerByteLoc = [[NSCountedSet alloc] init];
    
    const CGFloat lineHeight = [textView lineHeight];
    const NSRect bounds = [textView bounds];
    
    NSMutableArray *remainingCallouts = [[callouts mutableCopy] autorelease];
    [remainingCallouts sortUsingSelector:@selector(compare:)];
    
    while ([remainingCallouts count] > 0) {
        /* Get the next callout to lay out */
        const NSInteger byteLoc = [[remainingCallouts objectAtIndex:0] byteOffset];
        
        /* Get all the callouts that share that byteLoc */
        NSMutableArray *sharedCallouts = [NSMutableArray array];
        FOREACH(HFRepresenterTextViewCallout *, testCallout, remainingCallouts) {
            if ([testCallout byteOffset] == byteLoc) {
                [sharedCallouts addObject:testCallout];
            }
        }
        
        /* We expect to get at least one */
        const NSUInteger calloutCount = [sharedCallouts count];
        HFASSERT(calloutCount > 0);
        
        /* Get the character origin */
        const NSPoint characterOrigin = [textView originForCharacterAtByteIndex:byteLoc];
        
        /* This is how far it is to the center of our teardrop */
        const double teardropLength = HFTeardropRadius * HFTeadropTipScale;

        /* We're going to figure out the min and max angles */
        double prohibitedMinAngle = 0, prohibitedMaxAngle = 0;
        
        // Figure out which quadrant we're in
        BOOL isNearerTop = (characterOrigin.y < NSMidY(bounds));
        BOOL isNearerLeft = (characterOrigin.x < NSMidX(bounds));

        // Compute how far we are from the top (or bottom)
        double verticalDistance = (isNearerTop ? characterOrigin.y - NSMinY(bounds) : NSMaxY(bounds) - characterOrigin.y);
        if (verticalDistance <= 0) {
            /* We're either above or below the bounds */
            prohibitedMinAngle = (isNearerTop ? 0. : .5);
            prohibitedMaxAngle = (isNearerTop ? .5 : 1.);
        } else if (verticalDistance < teardropLength) {
            // Some angle will be forbidden
            double forbiddenAngle = acos(verticalDistance / teardropLength) / (2 * M_PI);
            
            // This is a wedge out of the top (or bottom)
            double topOrBottom = (isNearerTop ? .25 : .75);
            prohibitedMinAngle = topOrBottom - forbiddenAngle;
            prohibitedMaxAngle = topOrBottom + forbiddenAngle;
        }
        HFASSERT(prohibitedMaxAngle >= prohibitedMinAngle);
        
        /* How much will each callout rotate? No more than 1/8th. */
        double prohibitedAmount = prohibitedMaxAngle - prohibitedMinAngle;
        double changeInRotationPerCallout = fmin(.125, (1. - prohibitedAmount) / calloutCount);
        double totalConsumedAmount = changeInRotationPerCallout * calloutCount;
        
        /* We would like to center around .125. */
        const double goalCenter = .125;
        
        /* We're going to pretend to work on a line segment that extends from the max prohibited angle all the way back to min */
        double segmentLength = 1. - prohibitedAmount;
        double goalSegmentCenter = normalizeAngle(goalCenter - prohibitedMaxAngle); //may exceed segmentLength!
                
        /* Now center us on the goal. If the consumed max exceeds the segment length, move us left. If the consumed segment is less than zero, move us right */
        double consumedSegmentCenter = goalSegmentCenter;
        
        /* We only need to worry about wrapping around if we have some prohibited angle */
        if (prohibitedAmount > 0.) {
            consumedSegmentCenter -= fmax(0, consumedSegmentCenter + totalConsumedAmount/2 - segmentLength);
            consumedSegmentCenter -= fmin(0, consumedSegmentCenter - totalConsumedAmount/2);
        }
        
        /* Now convert this back to an angle */
        double consumedAngleCenter = normalizeAngle(prohibitedMaxAngle + consumedSegmentCenter);
        
        /* Distribute the callouts about this center */
        NSInteger i;
        for (i=0; i < (NSInteger)calloutCount; i++) {
            HFRepresenterTextViewCallout *callout = [sharedCallouts objectAtIndex:i];
            double seq = (i+1)/2; //0, 1, -1, 2, -2...
            if ((i & 1) == 0) seq = -seq;
            
            //if we've got an even number of callouts, we want -.5, .5, -1.5, 1.5...
            if (! (calloutCount & 1)) seq -= .5;
            
            callout->rotation = normalizeAngle(consumedAngleCenter + seq * changeInRotationPerCallout);
        }
                
        // move us slightly towards the character
        NSPoint teardropTipOrigin = NSMakePoint(characterOrigin.x + 1, characterOrigin.y + floor(lineHeight / 8.));
        
        // make the pin
        NSPoint pinStart, pinEnd;
        pinStart = NSMakePoint(characterOrigin.x + .25, characterOrigin.y);
        pinEnd = NSMakePoint(pinStart.x, pinStart.y + lineHeight);
        
        // store it all
        FOREACH(HFRepresenterTextViewCallout *, callout, sharedCallouts) {
            callout->tipOrigin = teardropTipOrigin;
            callout->pinStart = pinStart;
            callout->pinEnd = pinEnd;
            
            // Only the first gets a pin
            pinStart = pinEnd = NSZeroPoint;
        }

        
        /* We're done laying out these callouts */
        [remainingCallouts removeObjectsInArray:sharedCallouts];
    }
    
    [dropsPerByteLoc release];
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

- (CGAffineTransform)shadowTransform {
    CGFloat shadowXOffset = HFShadowXOffset;
    CGFloat shadowYOffset = HFShadowYOffset;
    CGFloat offscreenOffset = HFShadowOffscreenHack;
    
    // Figure out how much movement the shadow offset produces
    CGFloat shadowTranslationDistance = hypot(shadowXOffset, shadowYOffset);
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, tipOrigin.x + offscreenOffset - shadowXOffset, tipOrigin.y - shadowYOffset);
    transform = CGAffineTransformRotate(transform, rotation * M_PI * 2 - atan2(shadowTranslationDistance, 2*HFTeardropRadius /* bulbHeight */));
    return transform;
}

- (void)drawShadowWithClip:(NSRect)clip {
    USE(clip);
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    
    // Set the shadow. Note that these shadows are pretty unphysical for high rotations.
    NSShadow *shadow = [[NSShadow alloc] init];
    [shadow setShadowBlurRadius:5.];
    [shadow setShadowOffset:NSMakeSize(HFShadowXOffset - HFShadowOffscreenHack, HFShadowYOffset)];
    [shadow setShadowColor:[NSColor colorWithDeviceWhite:0. alpha:.5]];
    [shadow set];
    [shadow release];
    
    // Draw the shadow first and separately
    CGAffineTransform transform = [self shadowTransform];
    CGContextConcatCTM(ctx, transform);
    
    NSBezierPath *teardrop = copyTeardropPath();
    [teardrop fill];
    [teardrop release];
    
    // Clear the shadow
    CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
    
    // Undo the transform
    CGContextConcatCTM(ctx, CGAffineTransformInvert(transform));
}

- (void)drawWithClip:(NSRect)clip {
    USE(clip);
    CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
    // Here's the font we'll use
    CTFontRef ctfont = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 1., NULL);
    if (ctfont) {
        
        // Set the CG font
        CGFontRef cgfont = ctfont ? CTFontCopyGraphicsFont(ctfont, NULL) : NULL;
        CGContextSetFont(ctx, cgfont);
        CGFontRelease(cgfont);
            
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
                
        // Set our color.
        [color set];
        
        CGContextSaveGState(ctx);
        CGContextBeginTransparencyLayer(ctx, NULL);

        // Rotate and translate in preparation for drawing the teardrop
        CGContextConcatCTM(ctx, [self teardropTransform]);
        
        // Draw the teardrop
        NSBezierPath *teardrop = copyTeardropPath();
        [teardrop fill];
        [teardrop release];
        
        // Draw the text with white and alpha.  Use blend mode copy so that we clip out the shadow, and when the transparency layer is ended we'll composite over the text.
        CGFloat textScale = (glyphCount == 1 ? 24 : 20);
        
        // we are flipped by default, so invert the rotation's sign to get the text direction
        const CGFloat textDirection = (rotation <= .25 || rotation >= .75) ? -1 : 1;
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
        
        // Draw
        CGContextSetTextMatrix(ctx, textMatrix);
        CGContextShowGlyphsAtPositions(ctx, glyphs, positions, glyphCount);
        
        CGContextSetBlendMode(ctx, kCGBlendModeCopy);
        CGContextSetGrayFillColor(ctx, 1., .75); //faint white fill
        CGContextFillRect(ctx, NSRectToCGRect(NSInsetRect(bulbRect, -20, -20)));
        
        // Done drawing, so composite
        CGContextEndTransparencyLayer(ctx);            
        CGContextRestoreGState(ctx); // this also restores the clip, which is important
        
        // Lastly, draw the pin
        if (! NSEqualPoints(pinStart, pinEnd)) {
            [NSBezierPath setDefaultLineWidth:1.25];
            [NSBezierPath strokeLineFromPoint:pinStart toPoint:pinEnd];
        }
    }
    CFRelease(ctfont);
}

- (NSRect)rect {
    // get the transformed teardrop rect
    NSRect result = NSRectFromCGRect(CGRectApplyAffineTransform(NSRectToCGRect([self teardropBaseRect]), [self teardropTransform]));
    
    // outset a bit for the shadow
    result = NSInsetRect(result, -8, -8);
    return result;
}

@end
