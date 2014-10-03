//
//  HFRepresenterLayoutView.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFLayoutRepresenter.h>

@interface HFRepresenterLayoutViewInfo : NSObject {
@public
    HFRepresenter *rep;
    NSView *view;
    NSPoint layoutPosition;
    NSRect frame;
    NSUInteger autoresizingMask;
}

@end

@implementation HFRepresenterLayoutViewInfo

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ : %@>", view, NSStringFromRect(frame)];
}

@end

@implementation HFLayoutRepresenter

static NSInteger sortByLayoutPosition(id a, id b, void *self) {
    USE(self);
    NSPoint pointA = [a layoutPosition];
    NSPoint pointB = [b layoutPosition];
    if (pointA.y < pointB.y) return -1;
    else if (pointA.y > pointB.y) return 1;
    else if (pointA.x < pointB.x) return -1;
    else if (pointA.x > pointB.x) return 1;
    else return 0;
}

- (NSArray *)arraysOfLayoutInfos {
    if (! representers) return nil;
    
    NSMutableArray *result = [NSMutableArray array];
    NSArray *reps = [representers sortedArrayUsingFunction:sortByLayoutPosition context:self];
    NSMutableArray *currentReps = [NSMutableArray array];
    CGFloat currentRepY = - CGFLOAT_MAX;
    FOREACH(HFRepresenter*, rep, reps) {
        HFRepresenterLayoutViewInfo *info = [[HFRepresenterLayoutViewInfo alloc] init];
        info->rep = rep;
        info->view = [rep view];
        info->frame = [info->view frame];
        info->layoutPosition = [rep layoutPosition];
        info->autoresizingMask = [info->view autoresizingMask];
        if (info->layoutPosition.y != currentRepY && [currentReps count] > 0) {
            [result addObject:[[currentReps copy] autorelease]];
            [currentReps removeAllObjects];
        }
        currentRepY = info->layoutPosition.y;
        [currentReps addObject:info];
        [info release];
    }
    if ([currentReps count]) [result addObject:[[currentReps copy] autorelease]];
    return result;
}

- (NSRect)boundsRectForLayout {
    NSRect result = [[self view] bounds];
    /* Sometimes when we are not yet in a window, we get wonky bounds, so be paranoid. */
    if (result.size.width < 0 || result.size.height < 0) result = NSZeroRect;
    return result;
}

- (CGFloat)_computeMinHeightForLayoutInfos:(NSArray *)infos {
    CGFloat result = 0;
    HFASSERT(infos != NULL);
    HFASSERT([infos count] > 0);
    FOREACH(HFRepresenterLayoutViewInfo *, info, infos) {
        if (! (info->autoresizingMask & NSViewHeightSizable)) result = MAX(result, NSHeight([info->view frame]));
    }
    return result;
}

- (void)_applyYLocation:(CGFloat)yLocation andMinHeight:(CGFloat)height toInfos:(NSArray *)layoutInfos {
    FOREACH(HFRepresenterLayoutViewInfo *, info, layoutInfos) {    
        info->frame.origin.y = yLocation;
        if (info->autoresizingMask & NSViewHeightSizable) info->frame.size.height = height;
    }
}

- (void)_layoutInfosHorizontally:(NSArray *)infos inRect:(NSRect)layoutRect withBytesPerLine:(NSUInteger)bytesPerLine {
    CGFloat nextX = NSMinX(layoutRect);
    NSUInteger numHorizontallyResizable = 0;
    FOREACH(HFRepresenterLayoutViewInfo *, info, infos) {
        CGFloat minWidth = [info->rep minimumViewWidthForBytesPerLine:bytesPerLine];
        info->frame.origin.x = nextX;
        info->frame.size.width = minWidth;
        nextX += minWidth;
        numHorizontallyResizable += !! (info->autoresizingMask & NSViewWidthSizable);
    }
    
    CGFloat remainingWidth = NSMaxX(layoutRect) - nextX;
    if (numHorizontallyResizable > 0 && remainingWidth > 0) {
        NSView *view = [self view];
        CGFloat remainingPixels = [view convertSize:NSMakeSize(remainingWidth, 0) toView:nil].width;
        HFASSERT(remainingPixels > 0);
        CGFloat pixelsPerView = HFFloor(HFFloor(remainingPixels) / (CGFloat)numHorizontallyResizable);
        if (pixelsPerView > 0) {
            CGFloat pointsPerView = [view convertSize:NSMakeSize(pixelsPerView, 0) fromView:nil].width;
            CGFloat pointsAdded = 0;
            FOREACH(HFRepresenterLayoutViewInfo *, info, infos) {
                info->frame.origin.x += pointsAdded;
                if (info->autoresizingMask & NSViewWidthSizable) {
                    info->frame.size.width += pointsPerView;
                    pointsAdded += pointsPerView;
                }
            }
        }
    }
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    CGFloat result = 0;
    NSArray *arraysOfLayoutInfos = [self arraysOfLayoutInfos];
    
    FOREACH(NSArray *, layoutInfos, arraysOfLayoutInfos) {
        CGFloat minWidthForRow = 0;
        FOREACH(HFRepresenterLayoutViewInfo *, info, layoutInfos) {
            minWidthForRow += [info->rep minimumViewWidthForBytesPerLine:bytesPerLine];
        }
        result = MAX(result, minWidthForRow);
    }
    return result;
}

- (NSUInteger)_computeBytesPerLineForArraysOfLayoutInfos:(NSArray *)arraysOfLayoutInfos forLayoutInRect:(NSRect)layoutRect {
    /* The granularity is our own granularity (probably 1), LCMed with the granularities of all other representers */
    NSUInteger granularity = [self byteGranularity];
    FOREACH(HFRepresenter *, representer, representers) {
        granularity = HFLeastCommonMultiple(granularity, [representer byteGranularity]);
    }
    HFASSERT(granularity >= 1);
    
    NSUInteger newNumGranules = (NSUIntegerMax - 1) / granularity;
    FOREACH(NSArray *, layoutInfos, arraysOfLayoutInfos) {
        NSUInteger maxKnownGood = 0, minKnownBad = newNumGranules + 1;
        while (maxKnownGood + 1 < minKnownBad) {
            CGFloat requiredSpace = 0;
            NSUInteger proposedNumGranules = maxKnownGood + (minKnownBad - maxKnownGood)/2;
            NSUInteger proposedBytesPerLine = proposedNumGranules * granularity;
            FOREACH(HFRepresenterLayoutViewInfo *, info, layoutInfos) {
                requiredSpace += [info->rep minimumViewWidthForBytesPerLine:proposedBytesPerLine];
                if (requiredSpace > NSWidth(layoutRect)) break;
            }
            if (requiredSpace > NSWidth(layoutRect)) minKnownBad = proposedNumGranules;
            else maxKnownGood = proposedNumGranules;
        }
        newNumGranules = maxKnownGood;
    }
    return MAX(1u, newNumGranules) * granularity;
}

- (BOOL)_anyLayoutInfoIsVerticallyResizable:(NSArray *)vals {
    HFASSERT(vals != NULL);
    FOREACH(HFRepresenterLayoutViewInfo *, info, vals) {
        if (info->autoresizingMask & NSViewHeightSizable) return YES;
    }
    return NO;
}

- (BOOL)_addVerticalHeight:(CGFloat)heightPoints andOffset:(CGFloat)offsetPoints toLayoutInfos:(NSArray *)layoutInfos {
    BOOL isVerticallyResizable = [self _anyLayoutInfoIsVerticallyResizable:layoutInfos];
    CGFloat totalHeight = [self _computeMinHeightForLayoutInfos:layoutInfos] + heightPoints;
    FOREACH(HFRepresenterLayoutViewInfo *, info, layoutInfos) {
        info->frame.origin.y += offsetPoints;
        if (isVerticallyResizable) {
            if (info->autoresizingMask & NSViewHeightSizable) {
                info->frame.size.height = totalHeight;
            }
            else {
                CGFloat diff = totalHeight - info->frame.size.height;
                HFASSERT(diff >= 0);
                info->frame.origin.y += HFFloor(diff);
            }
        }
    }
    return isVerticallyResizable;
}

- (void)_distributeVerticalSpace:(CGFloat)space toArraysOfLayoutInfos:(NSArray *)arraysOfLayoutInfos {
    HFASSERT(space >= 0);
    HFASSERT(arraysOfLayoutInfos != NULL);
    
    NSUInteger consumers = 0;
    FOREACH(NSArray *, layoutInfos, arraysOfLayoutInfos) {
        if ([self _anyLayoutInfoIsVerticallyResizable:layoutInfos]) consumers++;
    }
    if (consumers > 0) {
        NSView *view = [self view];
        CGFloat availablePixels = [view convertSize:NSMakeSize(0, space) toView:nil].height;
        HFASSERT(availablePixels > 0);
        CGFloat pixelsPerView = HFFloor(HFFloor(availablePixels) / (CGFloat)consumers);
        CGFloat pointsPerView = [view convertSize:NSMakeSize(0, pixelsPerView) fromView:nil].height;
        CGFloat yOffset = 0;
        if (pointsPerView > 0) {
            FOREACH(NSArray *, layoutInfos, arraysOfLayoutInfos) {
                if ([self _addVerticalHeight:pointsPerView andOffset:yOffset toLayoutInfos:layoutInfos]) {
                    yOffset += pointsPerView;
                }
            }
        }
    }
}

- (void)performLayout {
    HFController *controller = [self controller];
    if (! controller) return;
    if (! representers) return;
    
    NSArray *arraysOfLayoutInfos = [self arraysOfLayoutInfos];
    if (! [arraysOfLayoutInfos count]) return;
    
    NSUInteger transaction = [controller beginPropertyChangeTransaction];
    
    NSRect layoutRect = [self boundsRectForLayout];
    
    NSUInteger bytesPerLine;
    if (maximizesBytesPerLine) bytesPerLine = [self _computeBytesPerLineForArraysOfLayoutInfos:arraysOfLayoutInfos forLayoutInRect:layoutRect];
    else bytesPerLine = [controller bytesPerLine];
    
    CGFloat yPosition = NSMinY(layoutRect);
    FOREACH(NSArray *, layoutInfos, arraysOfLayoutInfos) {
        HFASSERT([layoutInfos count] > 0);
        CGFloat minHeight = [self _computeMinHeightForLayoutInfos:layoutInfos];
        [self _applyYLocation:yPosition andMinHeight:minHeight toInfos:layoutInfos];
        yPosition += minHeight;
        [self _layoutInfosHorizontally:layoutInfos inRect:layoutRect withBytesPerLine:bytesPerLine];
    }
    
    CGFloat remainingVerticalSpace = NSMaxY(layoutRect) - yPosition;
    if (remainingVerticalSpace > 0) {
        [self _distributeVerticalSpace:remainingVerticalSpace toArraysOfLayoutInfos:arraysOfLayoutInfos];
    }
    
    FOREACH(NSArray *, layoutInfoArray, arraysOfLayoutInfos) {
        FOREACH(HFRepresenterLayoutViewInfo *, info, layoutInfoArray) {
            [info->view setFrame:info->frame];
        }
    }
    
    [controller endPropertyChangeTransaction:transaction];
}

- (NSArray *)representers {
    return representers ? [[representers copy] autorelease] : @[];
}

- (instancetype)init {
    self = [super init];
    maximizesBytesPerLine = YES;
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewFrameDidChangeNotification object:[self view]];
    [representers release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:representers forKey:@"HFRepresenters"];
    [coder encodeBool:maximizesBytesPerLine forKey:@"HFMaximizesBytesPerLine"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    representers = [[coder decodeObjectForKey:@"HFRepresenters"] retain];
    maximizesBytesPerLine = [coder decodeBoolForKey:@"HFMaximizesBytesPerLine"];
    NSView *view = [self view];
    [view setPostsFrameChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameChanged:) name:NSViewFrameDidChangeNotification object:view];
    return self;
}

- (void)addRepresenter:(HFRepresenter *)representer {
    REQUIRE_NOT_NULL(representer);
    if (! representers) representers = [[NSMutableArray alloc] init];
    HFASSERT([representers indexOfObjectIdenticalTo:representer] == NSNotFound);
    [representers addObject:representer];
    HFASSERT([[representer view] superview] != [self view]);
    [[self view] addSubview:[representer view]];
    [self performLayout];
}

- (void)removeRepresenter:(HFRepresenter *)representer {
    REQUIRE_NOT_NULL(representer);    
    HFASSERT([representers indexOfObjectIdenticalTo:representer] != NSNotFound);
    NSView *view = [representer view];
    HFASSERT([view superview] == [self view]);
    [view removeFromSuperview];
    [representers removeObjectIdenticalTo:representer];
    [self performLayout];
}

- (void)frameChanged:(NSNotification *)note {
    USE(note);
    [self performLayout];
}

- (void)initializeView {
    NSView *view = [self view];
    [view setPostsFrameChangedNotifications:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameChanged:) name:NSViewFrameDidChangeNotification object:view];
}

- (NSView *)createView {
    return [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
}

- (void)setMaximizesBytesPerLine:(BOOL)val {
    maximizesBytesPerLine = val;
}

- (BOOL)maximizesBytesPerLine {
    return maximizesBytesPerLine;
}

- (NSUInteger)maximumBytesPerLineForLayoutInProposedWidth:(CGFloat)proposedWidth {
    NSArray *arraysOfLayoutInfos = [self arraysOfLayoutInfos];
    if (! [arraysOfLayoutInfos count]) return 0;
    
    NSRect layoutRect = [self boundsRectForLayout];
    layoutRect.size.width = proposedWidth;
    
    NSUInteger bytesPerLine = [self _computeBytesPerLineForArraysOfLayoutInfos:arraysOfLayoutInfos forLayoutInRect:layoutRect];    
    return bytesPerLine;
}

- (CGFloat)minimumViewWidthForLayoutInProposedWidth:(CGFloat)proposedWidth {
    NSUInteger bytesPerLine;
    if ([self maximizesBytesPerLine]) {
        bytesPerLine = [self maximumBytesPerLineForLayoutInProposedWidth:proposedWidth];
    } else {
        bytesPerLine = [[self controller] bytesPerLine];
    }
    CGFloat newWidth = [self minimumViewWidthForBytesPerLine:bytesPerLine];
    return newWidth;
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    [super controllerDidChange:bits];
    if (bits & (HFControllerViewSizeRatios | HFControllerBytesPerColumn | HFControllerByteGranularity)) {
        [self performLayout];
    }
}

@end
