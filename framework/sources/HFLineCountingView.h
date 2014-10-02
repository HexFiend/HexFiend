//
//  HFLineCountingView.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFLineCountingRepresenter.h>

@interface HFLineCountingView : NSView {
    CGFloat lineHeight;
    HFFPRange lineRangeToDraw;
    NSLayoutManager *layoutManager;
    NSTextStorage *textStorage;
    NSTextContainer *textContainer;
    NSDictionary *textAttributes;
    HFLineCountingRepresenter *representer; //not retained
    
    NSUInteger bytesPerLine;
    unsigned long long storedLineIndex;
    NSUInteger storedLineCount;
    HFLineNumberFormat lineNumberFormat;
    BOOL useStringDrawingPath;
    BOOL registeredForAppNotifications;
}

@property (nonatomic, copy) NSFont *font;
@property (nonatomic) CGFloat lineHeight;
@property (nonatomic) HFFPRange lineRangeToDraw;
@property (nonatomic) NSUInteger bytesPerLine;
@property (nonatomic) HFLineNumberFormat lineNumberFormat;
@property (nonatomic, strong) HFLineCountingRepresenter *representer;

+ (NSUInteger)digitsRequiredToDisplayLineNumber:(unsigned long long)lineNumber inFormat:(HFLineNumberFormat)format;

@end
