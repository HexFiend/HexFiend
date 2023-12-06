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

- (CGFloat)textViewToLayoutView
{
    HFLayoutRepresenter *leftLayout = [leftView layoutRepresenter];
    CGFloat textViewToLayoutView = [leftView bounds].size.width - [[leftLayout view] frame].size.width; //we assume this is the same between both text views
    return textViewToLayoutView;
}

- (void)getLeftLayoutWidth:(CGFloat *)leftWidth rightLayoutWidth:(CGFloat *)rightWidth forProposedWidth:(CGFloat)viewWidth {
    /* Compute how much space we can allocate to each text view */
    HFLayoutRepresenter *leftLayout = [leftView layoutRepresenter];
    HFLayoutRepresenter *rightLayout = [rightView layoutRepresenter];
    const CGFloat textViewToLayoutView = [self textViewToLayoutView];
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

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    HFLayoutRepresenter *leftLayout = [leftView layoutRepresenter];
    HFLayoutRepresenter *rightLayout = [rightView layoutRepresenter];
    const CGFloat textViewToLayoutView = [self textViewToLayoutView];
    CGFloat leftWidth = [leftLayout minimumViewWidthForBytesPerLine:bytesPerLine] + textViewToLayoutView;
    CGFloat rightWidth = [rightLayout minimumViewWidthForBytesPerLine:bytesPerLine] + textViewToLayoutView;
    return leftWidth + interviewDistance + rightWidth;
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

- (void)drawRect:(NSRect)__unused dirtyRect {
    NSRect clipRect = self.bounds;
    /* Paranoia */
    if (! leftView || ! rightView) return;
    
    const BOOL darkMode = HFDarkModeEnabled();
    
    if (darkMode) {
        [[NSColor colorWithCalibratedWhite:.36 alpha:1.] set];
    } else {
        [[NSColor colorWithCalibratedWhite:.64 alpha:1.] set];
    }
    NSRectFillUsingOperation(clipRect, NSCompositingOperationSourceOver);
    
    CGContextRef ctx = HFGraphicsGetCurrentContext();
    CGFloat lineWidth = 1;
    NSRect bounds = [self bounds], lineRect = bounds;
    NSRect middleFrame = [self interviewRect];
    
    /* Draw shadows */
    if (!darkMode) {
        NSWindow *window = [self window];
        BOOL drawActive = (window == nil || [window isMainWindow] || [window isKeyWindow]);
        
        CGFloat shadowWidth = 6;
        HFDrawShadow(ctx, middleFrame, shadowWidth, NSMinXEdge, drawActive, clipRect);
        HFDrawShadow(ctx, middleFrame, shadowWidth, NSMaxXEdge, drawActive, clipRect);
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
    if (NSIntersectsRect(lineRect, clipRect)) NSRectFill(lineRect);
    
    lineRect.origin.x = NSMaxX(middleFrame) - lineWidth;
    if (NSIntersectsRect(lineRect, clipRect)) NSRectFill(lineRect);
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
