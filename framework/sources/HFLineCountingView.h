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
    HFRange lineRangeToDraw;
    NSUInteger bytesPerLine;
}

- (void)setFont:(NSFont *)val;
- (NSFont *)font;

- (void)setLineHeight:(CGFloat)height;
- (CGFloat)lineHeight;

- (void)setLineRangeToDraw:(HFRange)range;
- (HFRange)lineRangeToDraw;

- (void)setBytesPerLine:(NSUInteger)val;
- (NSUInteger)bytesPerLine;

@end
