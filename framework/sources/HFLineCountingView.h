//
//  HFLineCountingView.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFLineCountingRepresenter.h>

@interface HFLineCountingView : NSView {
    NSFont *font;
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

- (void)setFont:(NSFont *)val;
- (NSFont *)font;

- (void)setLineHeight:(CGFloat)height;
- (CGFloat)lineHeight;

- (void)setLineRangeToDraw:(HFFPRange)range;
- (HFFPRange)lineRangeToDraw;

- (void)setBytesPerLine:(NSUInteger)val;
- (NSUInteger)bytesPerLine;

- (void)setLineNumberFormat:(HFLineNumberFormat)format;
- (HFLineNumberFormat)lineNumberFormat;

- (void)setRepresenter:(HFLineCountingRepresenter *)rep;
- (HFLineCountingRepresenter *)representer;

+ (NSUInteger)digitsRequiredToDisplayLineNumber:(unsigned long long)lineNumber inFormat:(HFLineNumberFormat)format;

@end
