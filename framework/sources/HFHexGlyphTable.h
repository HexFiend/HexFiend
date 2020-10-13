//
//  HFHexGlyphTable.h
//  HexFiend_2
//
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFunctions.h>

@interface HFHexGlyphTable : NSObject

- (instancetype)initWithFont:(HFFont *)font;

@property (readonly) CGFloat advancement;
@property (readonly) const CGGlyph *table;

@end
