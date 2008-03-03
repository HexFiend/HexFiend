//
//  HFTextRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>
#import <HexFiend/HFByteArray_ToString.h>

/* A representer that draws into a text view (e.g. the hex or ASCII view) */

@interface HFTextRepresenter : HFRepresenter {
    BOOL behavesAsTextField;
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
- (BOOL)pasteBytesFromPasteboard:(NSPasteboard *)pb;

// Must be implemented by subclasses
- (void)insertText:(NSString *)text;

- (void)setBehavesAsTextField:(BOOL)val;
- (BOOL)behavesAsTextField;

@end
