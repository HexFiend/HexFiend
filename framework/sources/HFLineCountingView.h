//
//  HFLineCountingView.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFLineCountingRepresenter.h>

@interface HFLineCountingView : NSView {
    NSDictionary *textAttributes;
}

@property (nullable, nonatomic, copy) NSFont *font;
@property (nonatomic) CGFloat lineHeight;
@property (nonatomic) HFFPRange lineRangeToDraw;
@property (nonatomic) NSUInteger bytesPerLine;
@property (nonatomic) HFLineNumberFormat lineNumberFormat;
@property (nullable, nonatomic, weak) HFLineCountingRepresenter *representer;

+ (NSUInteger)digitsRequiredToDisplayLineNumber:(unsigned long long)lineNumber inFormat:(HFLineNumberFormat)format;

@end
