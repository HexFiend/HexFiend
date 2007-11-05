//
//  HFRepresenterTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFRepresenterTextView.h"


@implementation HFRepresenterTextView

- initWithRepresenter:(HFRepresenter *)rep {
    [super initWithFrame:NSMakeRect(0, 0, 1, 1)];
    NSTextContainer *container = [self textContainer];
    [container setWidthTracksTextView:YES];
    [container setHeightTracksTextView:YES];
    [self setHorizontallyResizable:NO];
    [self setVerticallyResizable:NO];
    representer = rep;
    return self;
}

@end
