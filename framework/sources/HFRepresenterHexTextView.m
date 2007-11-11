//
//  HFRepresenterHexTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFRepresenterHexTextView.h"

@implementation HFRepresenterHexTextView

- (void)drawRect:(NSRect)rect {
    [[NSColor purpleColor] set];
    NSRectFill([self bounds]);
    [super drawRect:rect];
}

@end
