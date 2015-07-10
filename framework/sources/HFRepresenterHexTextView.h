//
//  HFRepresenterHexTextView.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView.h>


@interface HFRepresenterHexTextView : HFRepresenterTextView {
    CGGlyph glyphTable[17];
    CGFloat glyphAdvancement;
    CGFloat spaceAdvancement;
    
    BOOL hidesNullBytes;
}

@property(nonatomic) BOOL hidesNullBytes;

@end
