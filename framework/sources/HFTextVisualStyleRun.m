//
//  HFTextVisualStyleRun.m
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "HFTextVisualStyleRun.h"


@implementation HFTextVisualStyleRun

- (instancetype)init {
    self = [super init];
    _scale = 1.;
    _shouldDraw = YES;
    return self;
}

- (void)dealloc {
    [_foregroundColor release];
    [_backgroundColor release];
    [_bookmarkStarts release];
    [_bookmarkExtents release];
    [super dealloc];
}

- (void)set {
    [_foregroundColor set];
    if (_scale != (CGFloat)1.0) {
        CGContextRef ctx = [[NSGraphicsContext currentContext] graphicsPort];
        CGAffineTransform tm = CGContextGetTextMatrix(ctx);
        /* Huge hack - adjust downward a little bit if we are scaling */
        tm = CGAffineTransformTranslate(tm, 0, -.25 * (_scale - 1));
        tm = CGAffineTransformScale(tm, _scale, _scale);
        CGContextSetTextMatrix(ctx, tm);
    }
}

static inline NSUInteger flip(NSUInteger x) {
    return _Generic(x, unsigned: NSSwapInt, unsigned long: NSSwapLong, unsigned long long: NSSwapLongLong)(x);
}
static inline NSUInteger rol(NSUInteger x, unsigned char r) {
    r %= sizeof(NSUInteger)*8;
    return (x << r) | (x << (sizeof(NSUInteger)*8 - r));
}
- (NSUInteger)hash {
    NSUInteger A = 0;
    // All these hashes tend to have only low bits, except the double which has only high bits.
#define Q(x, r) rol(x, sizeof(NSUInteger)*r/6)
    A ^= flip([_foregroundColor hash] ^ Q([_backgroundColor hash], 2)); // skew high
    A ^= Q(_range.length ^ flip(_range.location), 2); // skew low
    A ^= flip([_bookmarkStarts hash]) ^ Q([_bookmarkEnds hash], 3) ^ Q([_bookmarkExtents hash], 4); // skew high
    A ^= _shouldDraw ? 0 : (NSUInteger)-1;
    A ^= *(NSUInteger*)&_scale; // skew high
    return A;
#undef Q
}

- (BOOL)isEqual:(HFTextVisualStyleRun *)run {
    if(![run isKindOfClass:[self class]]) return NO;
    /* Check each field for equality. */
    if(!NSEqualRanges(_range, run->_range)) return NO;
    if(_scale != run->_scale) return NO;
    if(_shouldDraw != run->_shouldDraw) return NO;
    if(!!_foregroundColor != !!run->_foregroundColor) return NO;
    if(!!_backgroundColor != !!run->_backgroundColor) return NO;
    if(!!_bookmarkStarts  != !!run->_bookmarkStarts)  return NO;
    if(!!_bookmarkExtents != !!run->_bookmarkExtents) return NO;
    if(!!_bookmarkEnds    != !!run->_bookmarkEnds)    return NO;
    if(![_foregroundColor isEqual: run->_foregroundColor]) return NO;
    if(![_backgroundColor isEqual: run->_backgroundColor]) return NO;
    if(![_bookmarkStarts  isEqual: run->_bookmarkStarts])  return NO;
    if(![_bookmarkExtents isEqual: run->_bookmarkExtents]) return NO;
    if(![_bookmarkEnds    isEqual: run->_bookmarkEnds])    return NO;
    return YES;
}

@end
