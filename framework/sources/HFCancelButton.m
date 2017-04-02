//
//  HFCancelButton.m
//  HexFiend_2
//
//  Created by peter on 6/11/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#if !__has_feature(objc_arc)
#error ARC required
#endif

#import <HexFiend/HFCancelButton.h>

#define kHFCancelButtonIdentifier @"cancelButton"

@interface NSObject (BackwardCompatibleDeclarations)
- (void)setUserInterfaceItemIdentifier:(NSString *)val;
@end


@implementation HFCancelButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if ([self respondsToSelector:@selector(setIdentifier:)]) {
        [self setIdentifier:kHFCancelButtonIdentifier];
    } else if ([self respondsToSelector:@selector(setUserInterfaceItemIdentifier:)]) {
        [self setUserInterfaceItemIdentifier:kHFCancelButtonIdentifier];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) {
        NSImage *stopImage = [NSImage imageNamed:NSImageNameStopProgressTemplate];
        HFASSERT(stopImage != NULL);
        [self setImage:stopImage];
        [[self cell] setButtonType:NSMomentaryChangeButton];
    }
    return self;
}

@end
