//
//  HFHexGlyphTable.m
//  HexFiend_2
//
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "HFHexGlyphTable.h"
#import <HexFiend/HFAssert.h>
#import <CoreText/CoreText.h>

@implementation HFHexGlyphTable {
    CGGlyph _table[17];
    CGFloat _advancement;
}

- (instancetype)initWithFont:(HFFont *)font {
    self = [super init];
    [self generateGlyphTableForFont:font];
    return self;
}

- (void)generateGlyphTableForFont:(HFFont *)_font {
    const size_t numGlyphs = sizeof(_table) / sizeof(_table[0]);
    const UniChar hexchars[numGlyphs] = {'0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F',' '/* Plus a space char at the end for null bytes. */};
    HFFont *font = _font;
    
    CTFontRef ctfont = (__bridge CTFontRef)font;
    bool t = CTFontGetGlyphsForCharacters(ctfont, hexchars, _table, numGlyphs);
    HFASSERT(t); // We don't take kindly to strange fonts around here.
    
    CGSize advances[numGlyphs];
    CTFontGetAdvancesForGlyphs(ctfont, kCTFontOrientationHorizontal, _table, advances, numGlyphs);
    
    CGFloat maxAdv = 0.0;
    for (size_t i = 0; i < numGlyphs; i++) {
        maxAdv = HFMax(maxAdv, advances[i].width);
    }
    maxAdv = (CGFloat)round(maxAdv); // mimics what -[NSFont advancementForGlyph:] returns
    
    _advancement = maxAdv;
}

- (CGFloat)advancement {
    return _advancement;
}

- (const CGGlyph *)table {
    return _table;
}

@end
