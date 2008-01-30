//
//  HFFindReplaceRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "HFFindReplaceRepresenter.h"
#import "HFFindReplaceBackgroundView.h"

@implementation HFFindReplaceRepresenter

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, 2);
}

- (NSView *)createView {
    if (! [NSBundle loadNibNamed:@"FindReplace" owner:self] || ! backgroundView) {
        [NSException raise:NSInternalInconsistencyException format:@"Unable to load nib FindReplace.nib"];
    }
    return backgroundView;
}

- (void)initializeView {
    [super initializeView];
    findReplaceController = [[HFController alloc] init];
    HFByteArray *findReplaceByteArray = [[[HFTavlTreeByteArray alloc] init] autorelease];
    [findReplaceController setByteArray:findReplaceByteArray];
    
    findReplaceLayout = [[HFLayoutRepresenter alloc] init];
    activeRepresenter = [[HFHexTextRepresenter alloc] init];
    [[activeRepresenter view] setShowsFocusRing:YES];
    [[activeRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [findReplaceController addRepresenter:activeRepresenter];
    [findReplaceLayout addRepresenter:activeRepresenter];
    
    [findReplaceController addRepresenter:findReplaceLayout];
    NSView *layoutView = [findReplaceLayout view];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    NSRect backgroundViewBounds = [backgroundView bounds];
    NSRect layoutViewFrame;
    layoutViewFrame.origin.x = NSMaxX([navigateView frame]) + 2;
    layoutViewFrame.origin.y = NSMinY(backgroundViewBounds) + 2;
    layoutViewFrame.size.width = NSMaxX(backgroundViewBounds) - layoutViewFrame.origin.x - 6;
    layoutViewFrame.size.height = NSHeight(backgroundViewBounds) - 4;
    NSLog(@"%@ -> %@", NSStringFromRect([backgroundView bounds]), NSStringFromRect(layoutViewFrame));
    [layoutView setFrame:layoutViewFrame];
    [backgroundView setLayoutRepresenterView:layoutView];
    [backgroundView addSubview:layoutView];
}

- (IBAction)findNextOrPrevious:sender {

}

- (void)gainFocus {
    NSView *view = [activeRepresenter view];
    [[view window] makeFirstResponder:view];
}

@end
