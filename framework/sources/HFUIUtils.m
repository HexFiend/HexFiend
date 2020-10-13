#import <HexFiend/HFUIUtils.h>

NSUInteger HFLineHeightForFont(HFFont *font) {
#if TARGET_OS_IPHONE
    NSUInteger defaultLineHeight = (NSUInteger)ceil(font.lineHeight);
#else
    NSLayoutManager *manager = [[NSLayoutManager alloc] init];
    NSUInteger defaultLineHeight = (NSUInteger)ceil([manager defaultLineHeightForFont:font]);
#endif
    // Make sure there's an even number of spacing on top and bottom so
    // the font centers cleaner.
    if (((defaultLineHeight - (NSUInteger)ceil(font.ascender + fabs(font.descender))) % 2) != 0) {
        ++defaultLineHeight;
    }
    return defaultLineHeight;
}
