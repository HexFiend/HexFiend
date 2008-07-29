//
//  HFLineCountingView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/26/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFLineCountingView : NSView {
    NSFont *font;
    CGFloat lineHeight;
    HFFPRange lineRangeToDraw;
    NSLayoutManager *layoutManager;
    NSTextStorage *textStorage;
    NSTextContainer *textContainer;
    NSDictionary *textAttributes;
    NSTextView *textView;
    
    NSUInteger bytesPerLine;
    unsigned long long storedLineIndex;
    NSUInteger storedLineCount;
    
    BOOL useStringDrawingPath;
}

- (void)setFont:(NSFont *)val;
- (NSFont *)font;

- (void)setLineHeight:(CGFloat)height;
- (CGFloat)lineHeight;

- (void)setLineRangeToDraw:(HFFPRange)range;
- (HFFPRange)lineRangeToDraw;

- (void)setBytesPerLine:(NSUInteger)val;
- (NSUInteger)bytesPerLine;

@end
