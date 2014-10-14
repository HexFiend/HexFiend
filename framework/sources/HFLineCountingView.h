//
//  HFLineCountingView.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFLineCountingRepresenter.h>

@interface HFLineCountingView : NSView {
    NSLayoutManager *layoutManager;
    NSTextStorage *textStorage;
    NSTextContainer *textContainer;
    NSDictionary *textAttributes;
    
    unsigned long long storedLineIndex;
    NSUInteger storedLineCount;
    BOOL useStringDrawingPath;
    BOOL registeredForAppNotifications;
}

@property (nonatomic, copy) NSFont *font;
@property (nonatomic) CGFloat lineHeight;
@property (nonatomic) HFFPRange lineRangeToDraw;
@property (nonatomic) NSUInteger bytesPerLine;
@property (nonatomic) HFLineNumberFormat lineNumberFormat;
@property (nonatomic, assign) HFLineCountingRepresenter *representer;

+ (NSUInteger)digitsRequiredToDisplayLineNumber:(unsigned long long)lineNumber inFormat:(HFLineNumberFormat)format;

@end
