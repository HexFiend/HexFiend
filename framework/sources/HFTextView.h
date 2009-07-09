//
//  HFTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 6/28/09.
//  Copyright 2009 Apple Computer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFController.h>

@class HFLayoutRepresenter;

@interface HFTextView : NSControl {
    HFController *dataController;
    HFLayoutRepresenter *layoutRepresenter;
    NSArray *backgroundColors;
    BOOL bordered;
    IBOutlet id delegate;
}

- (HFLayoutRepresenter *)layoutRepresenter;
- (HFController *)controller;

- (NSArray *)backgroundColors;
- (void)setBackgroundColors:(NSArray *)colors;

- (void)setBordered:(BOOL)val;
- (BOOL)bordered;

- (void)setDelegate:(id)delegate;
- (id)delegate;

@end

@protocol HFTextViewDelegate <NSObject>

- (void)hexTextView:(HFTextView *)view didChangeProperties:(HFControllerPropertyBits)properties;

@end
