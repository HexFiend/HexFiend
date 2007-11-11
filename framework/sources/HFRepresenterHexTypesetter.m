//
//  HFRepresenterTypesetter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/10/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenterHexTypesetter.h>


@implementation HFRepresenterHexTypesetter

+ hexTypesetter {
    static HFRepresenterHexTypesetter *result;
    if (! result) result = [[self alloc] init];
    return result;
}

- (void)layoutGlyphsInLayoutManager:(NSLayoutManager *)layoutManager startingAtGlyphIndex:(NSUInteger)startGlyphIndex maxNumberOfLineFragments:(NSUInteger)maxNumLines nextGlyphIndex:(NSUInteger *)nextGlyph {
    NSLog(@"%s", _cmd);
}

- (void)willSetLineFragmentRect:(NSRectPointer)lineRect forGlyphRange:(NSRange)glyphRange usedRect:(NSRectPointer)usedRect baselineOffset:(CGFloat *)baselineOffset {
    NSLog(@"%s", _cmd);
 //   [super willSetLineFragmentRect:lineRect forGlyphRange:glyphRange usedRect:usedRect baselineOffset:baselineOffset];
}

@end
