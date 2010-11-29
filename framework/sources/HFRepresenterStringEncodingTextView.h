//
//  HFRepresenterStringEncodingTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView.h>

@interface HFRepresenterStringEncodingTextView : HFRepresenterTextView {
    union {
        struct HFGlyph_t glyphTable8Bit[256];
        struct HFGlyph_t *glyphBuckets16Bit[256];
    } glyphTable;
    NSMutableArray *fonts;
    BOOL usingBuckets;
    unsigned char bytesPerChar;
    struct HFGlyph_t replacementGlyph;
    CGFloat glyphAdvancement;
    NSStringEncoding encoding;
}

/* Set and get the NSStringEncoding that is used */
- (void)setEncoding:(NSStringEncoding)val;
- (NSStringEncoding)encoding;

@end
