//
//  DiffTextViewContainer.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/13/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "DiffTextViewContainer.h"

/* DiffTextViewContainer exists to draw a border and to lay out views with a fixed space between them. */
@implementation DiffTextViewContainer

- (void)awakeFromNib {
    interviewDistance = NSMinX([rightView frame]) - NSMaxX([leftView frame]);
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    USE(oldSize);
    const NSRect bounds = [self bounds];
    
    /* Each subview gets of the available space. */
    CGFloat subviewWidth = HFMax(0, (NSWidth([self bounds]) - interviewDistance) / 2);
    
    /* Round up, in device space */
    subviewWidth = HFCeil([self convertSizeToBase:NSMakeSize(subviewWidth, 0)].width);
    subviewWidth = [self convertSizeFromBase:NSMakeSize(subviewWidth, 0)].width;
    
    NSRect subviewFrame = NSMakeRect(NSMinX(bounds), NSMinY(bounds), subviewWidth, NSHeight(bounds));
    [leftView setFrame:subviewFrame];
    subviewFrame.origin.x = NSMaxX(bounds) - subviewWidth;
    [rightView setFrame:subviewFrame];
}

- (void)willRemoveSubview:(NSView *)subview {
    /* Clean up our (non-retained) leftView and rightView */
    if (subview == leftView) leftView = nil;
    if (subview == rightView) rightView = nil;
    [super willRemoveSubview:subview];
}

- (void)drawRect:(NSRect)dirtyRect {
    /* Paranoia */
    if (! leftView || ! rightView) return;
    
    CGFloat lineWidth = 1;
    NSRect bounds = [self bounds], lines[2], lineRect = bounds;
    NSRect leftViewFrame = [leftView frame], rightViewFrame = [rightView frame];
    lineRect.size.width = lineWidth;
    NSUInteger idx = 0;
    
    /* Construct the edge line rects */
    lineRect.origin.x = NSMaxX(leftViewFrame);
    if (NSIntersectsRect(lineRect, dirtyRect)) lines[idx++] = lineRect;

    lineRect.origin.x = NSMinX(rightViewFrame) - lineWidth;
    if (NSIntersectsRect(lineRect, dirtyRect)) lines[idx++] = lineRect;
    
    /* Draw them */
    if (idx > 0) {
	const CGFloat edgeColor = (CGFloat).745;
        const CGFloat grays[2] = {edgeColor, edgeColor};
        NSRectFillListWithGrays(lines, grays, idx);
    }
}

@end
