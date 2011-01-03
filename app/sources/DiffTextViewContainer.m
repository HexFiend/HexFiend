//
//  DiffTextViewContainer.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/13/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "DiffTextViewContainer.h"
#import <HexFiend/HFTextView.h>

/* DiffTextViewContainer exists to draw a border and to lay out views with a fixed space between them. */
@implementation DiffTextViewContainer

- (void)awakeFromNib {
    interviewDistance = NSMinX([rightView frame]) - NSMaxX([leftView frame]);
}

- (void)getLeftLayoutWidth:(CGFloat *)leftWidth rightLayoutWidth:(CGFloat *)rightWidth forProposedWidth:(CGFloat)viewWidth {
    /* Compute how much space we can allocate to each text view */
    HFLayoutRepresenter *leftLayout = [leftView layoutRepresenter], *rightLayout = [rightView layoutRepresenter];
    CGFloat textViewToLayoutView = [leftView bounds].size.width - [[leftLayout view] frame].size.width; //we assume this is the same between both text views
    const CGFloat availableTextViewSpace = viewWidth - interviewDistance - 2 * textViewToLayoutView;
    
    /* Start by dividing the space evenly, then iterate on finding the max bytes per line until we don't see any more changes */
    CGFloat leftLayoutViewSpace = HFFloor(availableTextViewSpace / 2);
    CGFloat rightLayoutViewSpace = availableTextViewSpace - leftLayoutViewSpace;
    
    /* Compute the BPLs for these view spaces */
    NSUInteger leftBytesPerLine = [leftLayout maximumBytesPerLineForLayoutInProposedWidth:leftLayoutViewSpace];
    NSUInteger rightBytesPerLine = [rightLayout maximumBytesPerLineForLayoutInProposedWidth:rightLayoutViewSpace];
    
    /* Compute how much space these BPLs would actually require */
    leftLayoutViewSpace = [leftLayout minimumViewWidthForBytesPerLine:leftBytesPerLine];
    rightLayoutViewSpace = [rightLayout minimumViewWidthForBytesPerLine:rightBytesPerLine];
    
    /* If the BPLs are the same, then there's no hope of fitting more in.  If they're not the same, there may be hope.  See how much unused space we have and assign it to the side that we want to get bigger. */
    CGFloat slackSpace = HFMax(availableTextViewSpace - leftLayoutViewSpace - rightLayoutViewSpace, 0.);
    if (rightBytesPerLine < leftBytesPerLine) {
	rightLayoutViewSpace += slackSpace;
	rightBytesPerLine = [rightLayout maximumBytesPerLineForLayoutInProposedWidth:rightLayoutViewSpace];
	rightLayoutViewSpace = [rightLayout minimumViewWidthForBytesPerLine:rightBytesPerLine];
    } else if (leftBytesPerLine < rightBytesPerLine) {
	leftLayoutViewSpace += slackSpace;
	leftBytesPerLine = [leftLayout maximumBytesPerLineForLayoutInProposedWidth:leftLayoutViewSpace];
	leftLayoutViewSpace = [leftLayout minimumViewWidthForBytesPerLine:leftBytesPerLine];	    
    }
    
    /* If they're still not the same, then use the smaller of the two */
    if (rightBytesPerLine > leftBytesPerLine) {
	rightBytesPerLine = leftBytesPerLine;
	rightLayoutViewSpace = [rightLayout minimumViewWidthForBytesPerLine:rightBytesPerLine];
    } else if (leftBytesPerLine > rightBytesPerLine) {
	leftBytesPerLine = rightBytesPerLine;
	leftLayoutViewSpace = [leftLayout minimumViewWidthForBytesPerLine:leftBytesPerLine];
    }

    /* Done, return the stuff */
    HFASSERT(leftBytesPerLine == rightBytesPerLine);
    *leftWidth = leftLayoutViewSpace + textViewToLayoutView;
    *rightWidth = rightLayoutViewSpace + textViewToLayoutView;
}

- (NSSize)minimumFrameSizeForProposedSize:(NSSize)frameSize {
    NSSize result;
    CGFloat leftWidth, rightWidth;
    [self getLeftLayoutWidth:&leftWidth rightLayoutWidth:&rightWidth forProposedWidth:frameSize.width];
    result.width = leftWidth + rightWidth + interviewDistance;
    result.height = frameSize.height;
    return result;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    USE(oldSize);
    const NSRect bounds = [self bounds];
    NSRect subviewFrame = bounds;
    
    /* Figure out the widths for our two views */
    CGFloat leftWidth, rightWidth;
    [self getLeftLayoutWidth:&leftWidth rightLayoutWidth:&rightWidth forProposedWidth:NSWidth(bounds)];
    
    /* Lay them out */
    subviewFrame.origin.x = NSMinX(bounds);
    subviewFrame.size.width = leftWidth;
    [leftView setFrame:subviewFrame];
    
    subviewFrame.origin.x = NSMaxX(bounds) - rightWidth;
    subviewFrame.size.width = rightWidth;
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
