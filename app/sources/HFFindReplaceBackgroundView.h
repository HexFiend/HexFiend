//
//  HFFindReplaceBackgroundView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/24/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFTextField;

@interface HFFindReplaceBackgroundView : NSView {
    IBOutlet NSSegmentedControl *navigateControl;
    IBOutlet HFTextField *searchField;
    IBOutlet HFTextField *replaceField;
    IBOutlet NSTextField *searchLabel;
    IBOutlet NSTextField *replaceLabel;
    IBOutlet NSProgressIndicator *progressIndicator;
    IBOutlet NSButton *cancelButton;
    CGFloat defaultHeight;
}

- (HFTextField *)searchField;
- (HFTextField *)replaceField;
- (NSSegmentedControl *)navigateControl;
- (NSProgressIndicator *)progressIndicator;
- (NSButton *)cancelButton;
- (CGFloat)defaultHeight;

@end
