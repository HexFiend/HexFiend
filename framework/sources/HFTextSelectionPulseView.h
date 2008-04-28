//
//  HFTextSelectionPulseView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 4/27/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFTextSelectionPulseView : NSView {
    NSImage *image;
}

- (void)setImage:(NSImage *)val;

@end
