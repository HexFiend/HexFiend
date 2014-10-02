#import <HexFiend/HFRepresenterTextView.h>

#define GLYPH_BUFFER_SIZE 16u

@interface HFRepresenterTextView (HFInternal)

- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingLayoutManager:(NSLayoutManager *)textView glyphs:(CGGlyph *)glyphs;
- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingTextView:(NSTextView *)textView glyphs:(CGGlyph *)glyphs;
- (NSUInteger)_getGlyphs:(CGGlyph *)glyphs forString:(NSString *)string font:(NSFont *)font; //uses CoreText.  Here glyphs must have space for [string length] glyphs.

@end
