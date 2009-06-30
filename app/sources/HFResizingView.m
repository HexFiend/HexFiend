//
//  HFResizingView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/1/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFResizingView.h"


@implementation HFResizingView

- (void)awakeFromNib {
    if (! hasAwokenFromNib) {
        hasAwokenFromNib = YES;
        defaultSize = [self frame].size;
        viewsToInitialFrames = (__strong CFMutableDictionaryRef)CFMakeCollectable(CFDictionaryCreateMutable(NULL, 0, NULL, &kCFTypeDictionaryValueCallBacks));
        
        FOREACH(NSView *, subview, [self subviews]) {
            CFDictionarySetValue(viewsToInitialFrames, subview, [NSValue valueWithRect:[subview frame]]);
        }
    }
}

- (void)dealloc {
    CFRelease(viewsToInitialFrames);
    [super dealloc];
}

typedef struct { CGFloat offset; CGFloat length; } Position_t;

static Position_t computePosition(id view, CGFloat startOffset, CGFloat startWidth, CGFloat startSpace, CGFloat newSpace, BOOL minIsFlexible, BOOL widthIsFlexible, BOOL maxIsFlexible) {
    USE(view);
    Position_t result;
    const CGFloat endOffset = startSpace - startWidth - startOffset;
    if (! widthIsFlexible) {
        result.length = startWidth;
        /* If the width is not flexible, pin in the non-flexible dimension; or if both are flexible, divide the space between them according to their original proportion */
        if (! maxIsFlexible) {
            result.offset = newSpace - startWidth - endOffset;
        }
        else if (maxIsFlexible && ! minIsFlexible) {
            result.offset = startOffset;
        }
        else if (maxIsFlexible && minIsFlexible) {
            CGFloat minContribution = startOffset / startSpace;
            CGFloat maxContribution = endOffset / startSpace;
            result.offset = HFRound(newSpace * minContribution / (minContribution + maxContribution)); //should pixel align here
        }
        else {
            /* Shouldn't be able to get here */
            [NSException raise:NSInternalInconsistencyException format:@"Unknown autoresizing mask"];
        }
    }
    else {
        /* widthIsFlexible */
        if (minIsFlexible && maxIsFlexible) {
            result.offset = HFRound(newSpace * startOffset / startSpace);
            result.length = HFRound(newSpace * startWidth / startSpace);
        }
        else if (minIsFlexible) {
            CGFloat remainingSpace = newSpace - endOffset;
            result.offset = HFRound(remainingSpace * startOffset / (startOffset + startWidth));
            result.length = remainingSpace - result.offset;
        }
        else if (maxIsFlexible) {
            CGFloat remainingSpace = newSpace - startOffset;
            result.offset = startOffset;
            result.length = HFRound(remainingSpace * startWidth / (endOffset + startWidth));   
        }
        else {
            result.offset = startOffset;
            result.length = newSpace - startOffset - endOffset;
        }
    }
    
    return result;
}

- (void)resizeView:(NSView *)view withOriginalFrame:(NSRect)originalFrame intoBounds:(NSRect)bounds {
    NSUInteger mask = [view autoresizingMask];
    Position_t horizontal = computePosition(view, originalFrame.origin.x, NSWidth(originalFrame), defaultSize.width, bounds.size.width, !!(mask & NSViewMinXMargin), !!(mask & NSViewWidthSizable), !!(mask & NSViewMaxXMargin));
    Position_t vertical = computePosition(view, originalFrame.origin.y, NSHeight(originalFrame), defaultSize.height, bounds.size.height, !!(mask & NSViewMinYMargin), !!(mask & NSViewHeightSizable), !!(mask & NSViewMaxYMargin));
    
    NSRect newRect;
    newRect.origin.x = horizontal.offset + bounds.origin.x;
    newRect.origin.y = vertical.offset + bounds.origin.y;
    newRect.size.width = horizontal.length;
    newRect.size.height = vertical.length;
    [view setFrame:newRect];
}

- (void)resizeSubviewsWithOldSize:(NSSize)size {
    USE(size);
    NSRect bounds = [self bounds];
    if (viewsToInitialFrames) {
        FOREACH(NSView *, view, [self subviews]) {
            NSValue *originalFrameValue = (NSValue *)CFDictionaryGetValue(viewsToInitialFrames, view);
            if (originalFrameValue) 
                [self resizeView:view withOriginalFrame:[originalFrameValue rectValue] intoBounds:bounds];
        }
    }
}


@end
