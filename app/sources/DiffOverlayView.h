//
//  DiffOverlayView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 3/26/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


/* A view used to draw the cross-view arrows in a DiffDocument */
@interface DiffOverlayView : NSView {
    NSRect leftRect;
    NSRect rightRect;
    NSView *leftView;
    NSView *rightView;
}

- (void)setLeftRect:(NSRect)rect;
- (void)setRightRect:(NSRect)rect;

- (void)setLeftView:(NSView *)view;
- (void)setRightView:(NSView *)view;

@end
