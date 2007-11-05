//
//  HFRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFRepresenter.h"

@implementation HFRepresenter

- (id)view {
    if (! view) {
        view = [self createView];
        [self initializeView];
    }
    return view;
}

- (void)initializeView {
    
}

- (void)dealloc {
    [view release];
    [super dealloc];
}

- (NSView *)createView {
    UNIMPLEMENTED();
}

- (HFController *)controller {
    return controller;
}

- (void)_setController:(HFController *)val {
    controller = val;
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    USE(bits);
}

@end
