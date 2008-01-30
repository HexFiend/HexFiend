//
//  HFFindReplaceBackgroundView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFFindReplaceBackgroundView : NSView {
    IBOutlet NSSegmentedControl *navigateControl;
    IBOutlet NSView *layoutRepresenterView;
}

- (void)setLayoutRepresenterView:(NSView *)view;
- (NSView *)layoutRepresenterView;

@end
