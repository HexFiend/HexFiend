//
//  HFRepresenterTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFRepresenterTextView.h>
#import <HexFiend/HFRepresenterTextLayoutManager.h>
#import <HexFiend/HFRepresenterHexTypesetter.h>

@implementation HFRepresenterTextView

- initWithRepresenter:(HFRepresenter *)rep {
    [super initWithFrame:NSMakeRect(0, 0, 1, 1)];
    
    NSTextContainer *container = [self textContainer];
    [container setWidthTracksTextView:YES];
    [container setHeightTracksTextView:YES];
    [self setHorizontallyResizable:NO];
    [self setVerticallyResizable:NO];
    
    HFRepresenterTextLayoutManager* layoutManager = [[HFRepresenterTextLayoutManager alloc] init];
    [[self textContainer] replaceLayoutManager:layoutManager];
    [layoutManager release];
    
    representer = rep;
    return self;
}

@end
