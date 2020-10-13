//
//  HFTextSelectionPulseView.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFTextSelectionPulseView : NSView {
    NSImage *image;
}

- (void)setImage:(NSImage *)val;

@end

NS_ASSUME_NONNULL_END
