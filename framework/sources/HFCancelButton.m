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
	[self setImage:HFImageNamed(@"HFCancelOff")];
	[self setAlternateImage:HFImageNamed(@"HFCancelOn")];
    }
    return self;
}

@end
