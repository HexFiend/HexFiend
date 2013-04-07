//
//  HFCancelButton.m
//  HexFiend_2
//
//  Created by peter on 6/11/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFCancelButton.h>

#define kHFCancelButtonIdentifier @"cancelButton"

@interface NSObject (BackwardCompatibleDeclarations)
- (void)setUserInterfaceItemIdentifier:(NSString *)val;
@end


@implementation HFCancelButton

- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if ([self respondsToSelector:@selector(setIdentifier:)]) {
        [self setIdentifier:kHFCancelButtonIdentifier];
    } else if ([self respondsToSelector:@selector(setUserInterfaceItemIdentifier:)]) {
        [self setUserInterfaceItemIdentifier:kHFCancelButtonIdentifier];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder {
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
