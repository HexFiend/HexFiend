#import <HexFiend/HFRepresenterTextView.h>

NS_ASSUME_NONNULL_BEGIN

#define GLYPH_BUFFER_SIZE 16u

@interface HFRepresenterTextView (HFInternal)

- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingLayoutManager:(NSLayoutManager *)textView glyphs:(nullable CGGlyph *)glyphs;
- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingTextView:(NSTextView *)textView glyphs:(nullable CGGlyph *)glyphs;
- (NSUInteger)_getGlyphs:(CGGlyph *)glyphs forString:(NSString *)string font:(NSFont *)font; //uses CoreText.  Here glyphs must have space for [string length] glyphs.

@end

NS_ASSUME_NONNULL_END
