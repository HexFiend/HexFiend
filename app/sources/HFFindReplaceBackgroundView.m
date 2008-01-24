//
//  HFFindReplaceBackgroundView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/24/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "HFFindReplaceBackgroundView.h"


@implementation HFFindReplaceBackgroundView

- (void)drawRect:(NSRect)rect {
    [[NSColor orangeColor] set];
    NSRectFill(rect);
}

@end
