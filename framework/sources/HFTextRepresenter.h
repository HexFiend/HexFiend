//
//  HFTextRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>
#import <HexFiend/HFByteArray.h>

/* A representer that draws into a text view (e.g. the hex or ASCII view) */

@interface HFTextRepresenter : HFRepresenter {
    BOOL behavesAsTextField;
    NSArray *rowBackgroundColors;
}

// HFTextRepresenter forwards these messages to its HFRepresenterTextView
- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth;
- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine;

- (NSArray *)displayedSelectedContentsRanges; //returns an array of NSValues representing the selected ranges (as NSRanges) clipped to the displayed range.

- (void)beginSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;
- (void)continueSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;
- (void)endSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;

// Copy/Paste methods
- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb;
- (void)cutSelectedBytesToPasteboard:(NSPasteboard *)pb;
- (BOOL)canPasteFromPasteboard:(NSPasteboard *)pb;
- (BOOL)canCut;
- (BOOL)pasteBytesFromPasteboard:(NSPasteboard *)pb;

// Must be implemented by subclasses
- (void)insertText:(NSString *)text;

// Must be implemented by subclasses.  Return NSData representing the string value.
- (NSData *)dataFromPasteboardString:(NSString *)string;

// Value between [0, 1]
- (double)selectionPulseAmount;

- (void)scrollWheel:(NSEvent *)event;

- (void)selectAll:(id)sender;

// Determines the per-row background colors.  Defaults to -[NSControl controlAlternatingRowBackgroundColors]
- (NSArray *)rowBackgroundColors;
- (void)setRowBackgroundColors:(NSArray *)colors;

- (void)setBehavesAsTextField:(BOOL)val;
- (BOOL)behavesAsTextField;

@end
