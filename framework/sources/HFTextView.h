//
//  HFTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 6/28/09.
//  Copyright 2009 Apple Computer. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFController, HFLayoutRepresenter;

@interface HFTextView : NSControl {
    HFController *dataController;
    HFLayoutRepresenter *layoutRepresenter;
    NSArray *backgroundColors;
}

- (HFLayoutRepresenter *)layoutRepresenter;
- (HFController *)controller;

- (NSArray *)backgroundColors;
- (void)setBackgroundColors:(NSArray *)colors;

@end
