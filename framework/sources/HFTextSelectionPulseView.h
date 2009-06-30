//
//  HFTextSelectionPulseView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 4/27/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFTextSelectionPulseView : NSView {
    NSImage *image;
}

- (void)setImage:(NSImage *)val;

@end
