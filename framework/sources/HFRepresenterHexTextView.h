//
//  HFRepresenterHexTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView.h>


@interface HFRepresenterHexTextView : HFRepresenterTextView {
    CGGlyph glyphTable[16];
    CGGlyph ligatureTable[256];
    CGFloat glyphAdvancement;
    CGFloat spaceAdvancement;
}

@end
