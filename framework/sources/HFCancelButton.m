//
//  HFCancelButton.m
//  HexFiend_2
//
//  Created by peter on 6/11/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFCancelButton.h>


@implementation HFCancelButton

- initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
	NSImage *stopImage = [NSImage imageNamed:@"NSStopProgressTemplate"];
	if (stopImage) {
	    [self setImage:stopImage];
	} else {   
	    [self setImage:HFImageNamed(@"HFCancelOff")];
	    [self setAlternateImage:HFImageNamed(@"HFCancelOn")];
	}
        [[self cell] setButtonType:NSMomentaryChangeButton];
    }
    return self;
}

@end
