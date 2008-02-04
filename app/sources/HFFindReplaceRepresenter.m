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
}

- (IBAction)findNextOrPrevious:sender {

}

@end
