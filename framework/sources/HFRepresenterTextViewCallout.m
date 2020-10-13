//
//  HFRepresenterTextViewCallout.m
//  HexFiend_2
//
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import "HFRepresenterTextViewCallout.h"
#import "HFRepresenterTextView.h"
#import <HexFiend/HFAssert.h>
#import <CoreText/CoreText.h>

static const CGFloat HFTeardropRadius = 12;
static const CGFloat HFTeadropTipScale = 2.5;

static const CGFloat HFShadowXOffset = -6;
static const CGFloat HFShadowYOffset = 0;
static const CGFloat HFShadowOffscreenHack = 3100;

static CGPoint rotatePoint(CGPoint center, CGPoint point, CGFloat percent) {
    CGFloat radians = percent * M_PI * 2;
    CGFloat x = point.x - center.x;
    CGFloat y = point.y - center.y;
    CGFloat newX = x * cos(radians) + y * sin(radians);
    CGFloat newY = x * -sin(radians) + y * cos(radians);
    return CGPointMake(center.x + newX, center.y + newY);
}

static CGPoint scalePoint(CGPoint center, CGPoint point, CGFloat percent) {
    CGFloat x = point.x - center.x;
    CGFloat y = point.y - center.y;
    CGFloat newX = x * percent;
    CGFloat newY = y * percent;
    return CGPointMake(center.x + newX, center.y + newY);
}

static
#if TARGET_OS_IPHONE
UIBezierPath
#else
NSBezierPath
#endif
*copyTeardropPath(void) {
    static
#if TARGET_OS_IPHONE
    UIBezierPath
#else
    NSBezierPath
#endif
    *sPath = nil;
    if (! sPath) {
        
        CGFloat radius = HFTeardropRadius;
        CGFloat rotation = 0;
        CGFloat droppiness = .15;
        CGFloat tipScale = HFTeadropTipScale;
        CGFloat tipLengthFromCenter = radius * tipScale;
        CGPoint bulbCenter = CGPointMake(-tipLengthFromCenter, 0);
        
        CGPoint triangleCenter = rotatePoint(bulbCenter, CGPointMake(bulbCenter.x + radius, bulbCenter.y), rotation);
        CGPoint dropCorner1 = rotatePoint(bulbCenter, triangleCenter, droppiness / 2);
        CGPoint dropCorner2 = rotatePoint(bulbCenter, triangleCenter, -droppiness / 2);
        CGPoint dropTip = scalePoint(bulbCenter, triangleCenter, tipScale);
        
        CGFloat startAngle = -rotation * 360 + droppiness * 180.;
        CGFloat endAngle = -rotation * 360 - droppiness * 180.;
#if TARGET_OS_IPHONE
        UIBezierPath *path = [UIBezierPath bezierPath];
        [path addArcWithCenter:bulbCenter radius:radius startAngle:startAngle endAngle:endAngle clockwise:NO];
#else
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path appendBezierPathWithArcWithCenter:bulbCenter radius:radius startAngle:startAngle endAngle:endAngle clockwise:NO];
#endif
        
        [path moveToPoint:dropCorner1];
#if TARGET_OS_IPHONE
        [path addLineToPoint:dropTip];
        [path addLineToPoint:dropCorner2];
#else
        [path lineToPoint:dropTip];
        [path lineToPoint:dropCorner2];
#endif
        [path closePath];
        
        sPath = path;
    }
    return sPath;
}


@implementation HFRepresenterTextViewCallout {
    CGFloat rotation;
    CGPoint tipOrigin;
    CGPoint pinStart;
    CGPoint pinEnd;
}

/* A helpful struct for representing a wedge (portion of a circle). Wedges are counterclockwise. */
typedef struct {
    double offset; // 0 <= offset < 1
    double length; // 0 <= length <= 1
} Wedge_t;


static inline double normalizeAngle(double x) {
    /* Convert an angle to the range [0, 1). We typically only generate angles that are off by a full rotation, so a loop isn't too bad. */
    while (x >= 1.) x -= 1.;
    while (x < 0.) x += 1.;
    return x;
}

static inline double distanceCCW(double a, double b) { return normalizeAngle(b-a); }

static inline double wedgeMax(Wedge_t wedge) {
    return normalizeAngle(wedge.offset + wedge.length);
}

/* Computes the smallest wedge containing the two given wedges. Compute the wedge from the min of one to the furthest part of the other, and pick the smaller. */
static Wedge_t wedgeUnion(Wedge_t wedge1, Wedge_t wedge2) {
    // empty wedges don't participate
    if (wedge1.length <= 0) return wedge2;
    if (wedge2.length <= 0) return wedge1;
    
    Wedge_t union1 = wedge1;
    union1.length = fmin(1., fmax(union1.length, distanceCCW(union1.offset, wedge2.offset) + wedge2.length));
    
    Wedge_t union2 = wedge2;
    union2.length = fmin(1., fmax(union2.length, distanceCCW(union2.offset, wedge1.offset) + wedge1.length));
    
    Wedge_t result = (union1.length <= union2.length ? union1 : union2);
    HFASSERT(result.length <= 1);
    return result;
}

- (NSComparisonResult)compare:(HFRepresenterTextViewCallout *)callout {
    return [_representedObject compare:callout.representedObject];
}

static Wedge_t computeForbiddenAngle(double distanceFromEdge, double angleToEdge) {
    Wedge_t newForbiddenAngle;
    
    /* This is how far it is to the center of our teardrop */
    const double teardropLength = HFTeardropRadius * HFTeadropTipScale;
    
    if (distanceFromEdge <= 0) {
        /* We're above or below. */
        if (-distanceFromEdge >= (teardropLength + HFTeardropRadius)) {
            /* We're so far above or below we won't be visible at all. No hope. */
            newForbiddenAngle = (Wedge_t){.offset = 0, .length = 1};
        } else { 
            /* We're either above or below the bounds, but there's a hope we can be visible */
            
            double invertedAngleToEdge = normalizeAngle(angleToEdge + .5);
            double requiredAngle;
            if (-distanceFromEdge >= teardropLength) {
                // We're too far north or south that all we can do is point in the right direction
                requiredAngle = 0;
            } else {
                // By confining ourselves to required angles, we can make ourselves visible
                requiredAngle = acos(-distanceFromEdge / teardropLength) / (2 * M_PI);
            }
            // Require at least a small spread
            requiredAngle = fmax(requiredAngle, .04);
            
            double requiredMin = invertedAngleToEdge - requiredAngle;
            double requiredMax = invertedAngleToEdge + requiredAngle;
            
            newForbiddenAngle = (Wedge_t){.offset = requiredMax, .length = distanceCCW(requiredMax, requiredMin) };
        }
    } else if (distanceFromEdge < teardropLength) {
        // We're onscreen, but some angle will be forbidden
        double forbiddenAngle = acos(distanceFromEdge / teardropLength) / (2 * M_PI);
        
        // This is a wedge out of the top (or bottom)
        newForbiddenAngle = (Wedge_t){.offset = angleToEdge - forbiddenAngle, .length = 2 * forbiddenAngle};
    } else {
        /* Nothing prohibited at all */
        newForbiddenAngle = (Wedge_t){0, 0};
    }
    return newForbiddenAngle;
}


static double distanceMod1(double a, double b) {
    /* Assuming 0 <= a, b < 1, returns the distance between a and b, mod 1 */
    if (a > b) {
        return fmin(a-b, b-a+1);
    } else {
        return fmin(b-a, a-b+1);
    }
}

+ (void)layoutCallouts:(NSArray *)callouts inView:(HFRepresenterTextView *)textView {
    
    const CGFloat lineHeight = [textView lineHeight];
    const CGRect bounds = [textView bounds];
    
    NSMutableArray *remainingCallouts = [callouts mutableCopy];
    [remainingCallouts sortUsingSelector:@selector(compare:)];
    
    while ([remainingCallouts count] > 0) {
        /* Get the next callout to lay out */
        const NSInteger byteLoc = [remainingCallouts[0] byteOffset];
        
        /* Get all the callouts that share that byteLoc */
        NSMutableArray *sharedCallouts = [NSMutableArray array];
        for(HFRepresenterTextViewCallout *testCallout in remainingCallouts) {
            if ([testCallout byteOffset] == byteLoc) {
                [sharedCallouts addObject:testCallout];
            }
        }
        
        /* We expect to get at least one */
        const NSUInteger calloutCount = [sharedCallouts count];
        HFASSERT(calloutCount > 0);
        
        /* Get the character origin */
        const CGPoint characterOrigin = [textView originForCharacterAtByteIndex:byteLoc];
        
        Wedge_t forbiddenAngle = {0, 0};
        
        // Compute how far we are from the top (or bottom)
        BOOL isNearerTop = (characterOrigin.y < CGRectGetMidY(bounds));
        double verticalDistance = (isNearerTop ? characterOrigin.y - CGRectGetMinY(bounds) : CGRectGetMaxY(bounds) - characterOrigin.y);
        forbiddenAngle = wedgeUnion(forbiddenAngle, computeForbiddenAngle(verticalDistance, (isNearerTop ? .25 : .75)));
        
        // Compute how far we are from the left (or right)
        BOOL isNearerLeft = (characterOrigin.x < CGRectGetMidX(bounds));
        double horizontalDistance = (isNearerLeft ? characterOrigin.x - CGRectGetMinX(bounds) : CGRectGetMaxX(bounds) - characterOrigin.x);
        forbiddenAngle = wedgeUnion(forbiddenAngle, computeForbiddenAngle(horizontalDistance, (isNearerLeft ? .5 : 0.)));
        
        
        /* How much will each callout rotate? No more than 1/8th. */
        HFASSERT(forbiddenAngle.length <= 1);
        double changeInRotationPerCallout = fmin(.125, (1. - forbiddenAngle.length) / calloutCount);
        double totalConsumedAmount = changeInRotationPerCallout * calloutCount;
        
        /* We would like to center around .375. */
        const double goalCenter = .375;
        
        /* We're going to pretend to work on a line segment that extends from the max prohibited angle all the way back to min */
        double segmentLength = 1. - forbiddenAngle.length;
        double goalSegmentCenter = normalizeAngle(goalCenter - wedgeMax(forbiddenAngle)); //may exceed segmentLength!
                
        /* Now center us on the goal, or as close as we can get. */
        double consumedSegmentCenter;
        
        /* We only need to worry about wrapping around if we have some prohibited angle */
        if (forbiddenAngle.length <= 0) { //never expect < 0, but be paranoid
            consumedSegmentCenter = goalSegmentCenter;
        } else {
            
            /* The consumed segment center is confined to the segment range [amount/2, length - amount/2] */
            double consumedSegmentCenterMin = totalConsumedAmount/2;
            double consumedSegmentCenterMax = segmentLength - totalConsumedAmount/2;
            if (goalSegmentCenter >= consumedSegmentCenterMin && goalSegmentCenter < consumedSegmentCenterMax) {
                /* We can hit our goal */
                consumedSegmentCenter = goalSegmentCenter;
            } else {
                /* Pick either the min or max location, depending on which one gets us closer to the goal segment center mod 1. */
                if (distanceMod1(goalSegmentCenter, consumedSegmentCenterMin) <= distanceMod1(goalSegmentCenter, consumedSegmentCenterMax)) {
                    consumedSegmentCenter = consumedSegmentCenterMin;
                } else {
                    consumedSegmentCenter = consumedSegmentCenterMax;
                }
                
            }
        }
        
        /* Now convert this back to an angle */
        double consumedAngleCenter = normalizeAngle(wedgeMax(forbiddenAngle) + consumedSegmentCenter);
        
        // move us slightly towards the character
        CGPoint teardropTipOrigin = CGPointMake(characterOrigin.x + 1, characterOrigin.y + floor(lineHeight / 8.));
        
        // make the pin
        CGPoint pinStart, pinEnd;
        pinStart = CGPointMake(characterOrigin.x + .25, characterOrigin.y);
        pinEnd = CGPointMake(pinStart.x, pinStart.y + lineHeight);
        
        // store it all, invalidating as necessary
        NSInteger i = 0;
        for(HFRepresenterTextViewCallout *callout in sharedCallouts) {
            
            /* Compute the rotation */
            double seq = (i+1)/2; //0, 1, -1, 2, -2...
            if ((i & 1) == 0) seq = -seq;
            //if we've got an even number of callouts, we want -.5, .5, -1.5, 1.5...
            if (! (calloutCount & 1)) seq -= .5;
            // compute the angle of rotation
            double angle = consumedAngleCenter + seq * changeInRotationPerCallout;
            // our notion of rotation has 0 meaning pointing right and going counterclockwise, but callouts with 0 pointing left and going clockwise, so convert
            angle = normalizeAngle(.5 - angle);

            
            CGRect beforeRect = [callout rect];
            
            callout->rotation = angle;
            callout->tipOrigin = teardropTipOrigin;
            callout->pinStart = pinStart;
            callout->pinEnd = pinEnd;
            
            // Only the first gets a pin
            pinStart = pinEnd = CGPointZero;
            
            CGRect afterRect = [callout rect];
            
            if (! CGRectEqualToRect(beforeRect, afterRect)) {
                [textView setNeedsDisplayInRect:beforeRect];
                [textView setNeedsDisplayInRect:afterRect];
            }
            
            i++;
        }

        
        /* We're done laying out these callouts */
        [remainingCallouts removeObjectsInArray:sharedCallouts];
    }
}

- (CGAffineTransform)teardropTransform {
    CGAffineTransform trans = CGAffineTransformMakeTranslation(tipOrigin.x, tipOrigin.y);
    trans = CGAffineTransformRotate(trans, rotation * M_PI * 2);
    return trans;
}

- (CGRect)teardropBaseRect {
    CGSize teardropSize = CGSizeMake(HFTeardropRadius * (1 + HFTeadropTipScale), HFTeardropRadius*2);
    CGRect result = CGRectMake(-teardropSize.width, -teardropSize.height/2, teardropSize.width, teardropSize.height);
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

- (void)drawShadowWithClip:(CGRect)clip context:(CGContextRef)ctx {
    USE(clip);
    
    // Set the shadow. Note that these shadows are pretty unphysical for high rotations.
    CGSize offset = CGSizeMake(HFShadowXOffset - HFShadowOffscreenHack, HFShadowYOffset);
#if TARGET_OS_IPHONE
    CGColorRef color = [UIColor colorWithWhite:0. alpha:.5].CGColor;
#else
    CGColorRef color = [NSColor colorWithCalibratedWhite:0. alpha:.5].CGColor;
#endif
    CGContextSetShadowWithColor(ctx, offset, 5., color);
    
    // Draw the shadow first and separately
    CGAffineTransform transform = [self shadowTransform];
    CGContextConcatCTM(ctx, transform);
    
    [copyTeardropPath() fill];
    
    // Clear the shadow
    CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
    
    // Undo the transform
    CGContextConcatCTM(ctx, CGAffineTransformInvert(transform));
}

- (void)drawWithClip:(CGRect)clip context:(CGContextRef)ctx {
    USE(clip);
    // Here's the font we'll use
    CTFontRef ctfont = CTFontCreateWithName(CFSTR("Helvetica-Bold"), 1., NULL);
    if (ctfont) {
#if !TARGET_OS_IPHONE
        // Set the font
        [(__bridge NSFont *)ctfont set];
#endif
            
        // Get characters
        NSUInteger labelLength = MIN([_label length], kHFRepresenterTextViewCalloutMaxGlyphCount);
        UniChar calloutUniLabel[kHFRepresenterTextViewCalloutMaxGlyphCount];
        [_label getCharacters:calloutUniLabel range:NSMakeRange(0, labelLength)];
        
        // Get our glyphs and advances
        CGGlyph glyphs[kHFRepresenterTextViewCalloutMaxGlyphCount];
        CGSize advances[kHFRepresenterTextViewCalloutMaxGlyphCount];
        CTFontGetGlyphsForCharacters(ctfont, calloutUniLabel, glyphs, labelLength);
        CTFontGetAdvancesForGlyphs(ctfont, kCTFontOrientationHorizontal, glyphs, advances, labelLength);

        // Count our glyphs. Note: this won't work with any label containing spaces, etc.
        NSUInteger glyphCount;
        for (glyphCount = 0; glyphCount < labelLength; glyphCount++) {
            if (glyphs[glyphCount] == 0) break;
        }
                
        // Set our color.
        [_color set];
        
        // Draw the pin first
        if (! CGPointEqualToPoint(pinStart, pinEnd)) {
#if !TARGET_OS_IPHONE
            [NSBezierPath setDefaultLineWidth:1.25];
            [NSBezierPath strokeLineFromPoint:pinStart toPoint:pinEnd];
#endif
        }
        
        CGContextSaveGState(ctx);
        CGContextBeginTransparencyLayerWithRect(ctx, [self rect], NULL);

        // Rotate and translate in preparation for drawing the teardrop
        CGContextConcatCTM(ctx, [self teardropTransform]);
        
        // Draw the teardrop
        [copyTeardropPath() fill];
        
        // Draw the text with white and alpha.  Use blend mode copy so that we clip out the shadow, and when the transparency layer is ended we'll composite over the text.
        CGFloat textScale = (glyphCount == 1 ? 24 : 20);
        
        // we are flipped by default, so invert the rotation's sign to get the text direction. Use a little slop so we don't get jitter.
        const CGFloat textDirection = (rotation <= .27 || rotation >= .73) ? -1 : 1;
        
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
        if ([_label isEqualToString:@"6"]) textYOffset -= 1;
        
        
        // Apply this text matrix
        CGRect bulbRect = [self teardropBaseRect];
        CGAffineTransform textMatrix = CGAffineTransformMakeScale(-copysign(textScale, textDirection), copysign(textScale, textDirection)); //roughly the font size we want
        textMatrix.tx = CGRectGetMinX(bulbRect) + HFTeardropRadius + copysign(totalAdvance/2, textDirection);
        

        if (textDirection < 0) {
            textMatrix.ty = CGRectGetMaxY(bulbRect) - textYOffset;
        } else {
            textMatrix.ty = CGRectGetMinY(bulbRect) + textYOffset;
        }
        
        // Draw
        CGContextSetTextMatrix(ctx, textMatrix);
        CGContextSetTextDrawingMode(ctx, kCGTextClip);
        CGContextShowGlyphsAtPositions(ctx, glyphs, positions, glyphCount);
        
        CGContextSetBlendMode(ctx, kCGBlendModeCopy);
        CGContextSetGrayFillColor(ctx, 1., .66); //faint white fill
        CGContextFillRect(ctx, CGRectInset(bulbRect, -20, -20));
        
        // Done drawing, so composite
        CGContextEndTransparencyLayer(ctx);
        CGContextRestoreGState(ctx); // this also restores the clip, which is important
        
        // Done with the font
        CFRelease(ctfont);
    }
}

- (CGRect)rect {
    // get the transformed teardrop rect
    CGRect result = CGRectApplyAffineTransform([self teardropBaseRect], [self teardropTransform]);
    
    // outset a bit for the shadow
    result = CGRectInset(result, -8, -8);
    return result;
}

@end
