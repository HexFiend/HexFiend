#import <HexFiend/HFRepresenterTextView.h>

#define GLYPH_BUFFER_SIZE 16

@interface HFRepresenterTextView (HFInternal)

- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingLayoutManager:(NSLayoutManager *)textView glyphs:(CGGlyph *)glyphs;
- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingTextView:(NSTextView *)textView glyphs:(CGGlyph *)glyphs;
- (NSUInteger)_glyphsForString:(NSString *)string glyphs:(CGGlyph *)glyphs; //uses CoreText.  Here glyphs must have space for [string length] glyphs.

@end
