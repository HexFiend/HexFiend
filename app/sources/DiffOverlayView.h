//
//  DiffOverlayView.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum DiffOverlayViewRangeType_t {
    DiffOverlayViewRangeIsAbove,
    DiffOverlayViewRangeIsVisible,
    DiffOverlayViewRangeIsBelow
};

/* A view used to draw the cross-view arrows in a DiffDocument */
@interface DiffOverlayView : NSView {
    NSRect leftRect;
    NSRect rightRect;
    
    enum DiffOverlayViewRangeType_t leftRangeType;
    enum DiffOverlayViewRangeType_t rightRangeType;
    
    NSView *leftView;
    NSView *rightView;
}

- (void)setLeftRangeType:(enum DiffOverlayViewRangeType_t)type rect:(NSRect)rect;
- (void)setRightRangeType:(enum DiffOverlayViewRangeType_t)type rect:(NSRect)rect;

- (void)setLeftView:(NSView *)view;
- (void)setRightView:(NSView *)view;

@end
