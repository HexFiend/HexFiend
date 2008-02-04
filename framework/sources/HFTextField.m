//
//  HFTextField.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/2/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFTextField.h>
#import <HexFiend/HFTavlTreeByteArray.h>
#import <HexFiend/HFController.h>
#import <HexFiend/HFLayoutRepresenter.h>
#import <HexFiend/HFHexTextRepresenter.h>

@implementation HFTextField


- (id)initWithFrame:(NSRect)frame {
    if ((self = [super initWithFrame:frame])) {
        dataController = [[HFController alloc] init];
        [dataController setByteArray:[[[HFTavlTreeByteArray alloc] init] autorelease]];
    
        layoutRepresenter = [[HFLayoutRepresenter alloc] init];
        activeRepresenter = [[HFHexTextRepresenter alloc] init];
        [[activeRepresenter view] setShowsFocusRing:YES];
        [[activeRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [dataController addRepresenter:activeRepresenter];
        [layoutRepresenter addRepresenter:activeRepresenter];
        [dataController addRepresenter:layoutRepresenter];
        NSView *layoutView = [layoutRepresenter view];
        [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [layoutView setFrame:[self bounds]];
        [self addSubview:layoutView];
    }
    return self;
}

- (void)drawRect:(NSRect)rect {
    [[NSColor purpleColor] set];
    NSRectFill([self bounds]);
}

- (BOOL)becomeFirstResponder {
    return [[self window] makeFirstResponder:[activeRepresenter view]];
}

@end
