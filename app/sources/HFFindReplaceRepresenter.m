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
    HFRepresenter *hexRepresenter = [[HFHexTextRepresenter alloc] init];
    [findReplaceController addRepresenter:hexRepresenter];
    [findReplaceLayout addRepresenter:hexRepresenter];
    
    [findReplaceController addRepresenter:findReplaceLayout];
    NSView *layoutView = [findReplaceLayout view];
    [layoutView setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
    NSRect backgroundViewBounds = [backgroundView bounds];
    NSRect layoutViewFrame;
    layoutViewFrame.origin.x = NSMaxX([navigateView frame]);
    layoutViewFrame.origin.y = NSMinY(backgroundViewBounds);
    layoutViewFrame.size.width = NSMaxX(backgroundViewBounds) - layoutViewFrame.origin.x;
    layoutViewFrame.size.height = NSHeight(backgroundViewBounds);
    layoutViewFrame = NSInsetRect(layoutViewFrame, 2, 4);
    [layoutView setFrame:layoutViewFrame];
    [backgroundView addSubview:layoutView];
}

- (IBAction)findNextOrPrevious:sender {

}

@end
