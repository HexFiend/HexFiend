//
//  DiffTextViewContainer.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "DiffTextViewContainer.h"
#import <HexFiend/HexFiend.h>

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

    /* Compute byte granularity */
    NSUInteger granularity = 1;
    for(HFRepresenter *rep in [leftView layoutRepresenter].representers) {
        granularity = HFLeastCommonMultiple(granularity, [rep byteGranularity]);
    }
    for(HFRepresenter *rep2 in [rightView layoutRepresenter].representers) {
        granularity = HFLeastCommonMultiple(granularity, [rep2 byteGranularity]);
    }
    
    /* Do a binary search to find the maximum number of granules that can fit */
    NSUInteger maxKnownGood = 0, minKnownBad = (NSUIntegerMax - 1) / granularity;
    while (maxKnownGood + 1 < minKnownBad) {
        NSUInteger proposedNumGranules = maxKnownGood + (minKnownBad - maxKnownGood)/2;
        NSUInteger proposedBytesPerLine = proposedNumGranules * granularity;
        CGFloat requiredSpace = [leftLayout minimumViewWidthForBytesPerLine:proposedBytesPerLine] + [rightLayout minimumViewWidthForBytesPerLine:proposedBytesPerLine];
        if (requiredSpace > availableTextViewSpace) minKnownBad = proposedNumGranules;
        else maxKnownGood = proposedNumGranules;
    }

    /* Compute BPL */
    NSUInteger bpl = MAX(maxKnownGood, 1u) * granularity;
    
    /* Return what we've discovered */
    *leftWidth = [leftLayout minimumViewWidthForBytesPerLine:bpl] + textViewToLayoutView;
    *rightWidth = [rightLayout minimumViewWidthForBytesPerLine:bpl] + textViewToLayoutView;
}

- (void)OLDgetLeftLayoutWidth:(CGFloat *)leftWidth rightLayoutWidth:(CGFloat *)rightWidth forProposedWidth:(CGFloat)viewWidth {
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

- (BOOL)isOpaque {
    return YES;
}

- (NSRect)interviewRect {
    NSRect result = NSZeroRect;
    if (leftView && rightView) {
        NSRect leftViewFrame = [leftView frame], rightViewFrame = [rightView frame], bounds = [self bounds];
        result = NSMakeRect(NSMaxX(leftViewFrame), bounds.origin.y, NSMinX(rightViewFrame) - NSMaxX(leftViewFrame), bounds.size.height);
    }
    return result;
}

- (void)drawRect:(NSRect)dirtyRect {
    /* Paranoia */
    if (! leftView || ! rightView) return;
    
    const BOOL darkMode = HFDarkModeEnabled();
    
    if (darkMode) {
        [[NSColor colorWithCalibratedWhite:.36 alpha:1.] set];
    } else {
        [[NSColor colorWithCalibratedWhite:.64 alpha:1.] set];
    }
    NSRectFillUsingOperation(dirtyRect, NSCompositingOperationSourceOver);
    
    CGContextRef ctx = HFGraphicsGetCurrentContext();
    CGFloat lineWidth = 1;
    NSRect bounds = [self bounds], lineRect = bounds;
    NSRect middleFrame = [self interviewRect];
    
    /* Draw shadows */
    if (!darkMode) {
        NSWindow *window = [self window];
        BOOL drawActive = (window == nil || [window isMainWindow] || [window isKeyWindow]);
        
        CGFloat shadowWidth = 6;
        HFDrawShadow(ctx, middleFrame, shadowWidth, NSMinXEdge, drawActive, dirtyRect);
        HFDrawShadow(ctx, middleFrame, shadowWidth, NSMaxXEdge, drawActive, dirtyRect);
    }
    
    /* Draw the edge line rects */
    NSColor *dividerColor = [NSColor darkGrayColor];
    if (darkMode) {
        if (@available(macOS 10.14, *)) {
            dividerColor = [NSColor separatorColor];
        }
    }
    [dividerColor set];
    lineRect.size.width = lineWidth;
    lineRect.origin.x = NSMinX(middleFrame);
    if (NSIntersectsRect(lineRect, dirtyRect)) NSRectFill(lineRect);
    
    lineRect.origin.x = NSMaxX(middleFrame) - lineWidth;
    if (NSIntersectsRect(lineRect, dirtyRect)) NSRectFill(lineRect);
}


- (void)windowDidChangeKeyStatus:(NSNotification *)note {
    USE(note);
    [self setNeedsDisplayInRect:[self interviewRect]];
}

- (void)viewDidMoveToWindow {
    HFRegisterViewForWindowAppearanceChanges(self, @selector(windowDidChangeKeyStatus:), !registeredForAppNotifications);
    registeredForAppNotifications = YES;
    [super viewDidMoveToWindow];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow {
    HFUnregisterViewForWindowAppearanceChanges(self, NO);
    [super viewWillMoveToWindow:newWindow];
}

- (void)dealloc {
    HFUnregisterViewForWindowAppearanceChanges(self, registeredForAppNotifications);
}

@end
