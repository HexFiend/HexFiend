//
//  HFRepresenterStringEncodingTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/11/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView.h>


@interface HFRepresenterStringEncodingTextView : HFRepresenterTextView {
    CGGlyph glyphTable[256];
    CGGlyph replacementGlyph;
    CGFloat glyphAdvancement;
    NSStringEncoding encoding;
}

/* Set and get the NSStringEncoding that is used */
- (void)setEncoding:(NSStringEncoding)val;
- (NSStringEncoding)encoding;

@end
