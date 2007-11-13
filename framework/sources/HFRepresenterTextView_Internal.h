#import <HexFiend/HFRepresenterTextView.h>

#define GLYPH_BUFFER_SIZE 16

@interface HFRepresenterTextView (HFInternal)

- (void)_drawLineBackgrounds:(NSRect)clip withLineHeight:(CGFloat)lineHeight maxLines:(NSUInteger)maxLines;
- (NSUInteger)_glyphsForString:(NSString *)string withGeneratingTextView:(NSTextView *)textView glyphs:(CGGlyph *)glyphs;

@end
