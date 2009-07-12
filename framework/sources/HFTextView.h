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

/*! @class HFTextView
    @brief A high-level view class analagous to NSTextView.
    
    HFTextField encapsulates a HFController and HFRepresenters into a single "do it all" NSControl analagous to NSTextView.  
*/    
@interface HFTextView : NSControl {
    HFController *dataController;
    HFLayoutRepresenter *layoutRepresenter;
    NSArray *backgroundColors;
    BOOL bordered;
    IBOutlet id delegate;
    NSData *cachedData;
}

- (HFLayoutRepresenter *)layoutRepresenter;
- (HFController *)controller;

- (NSArray *)backgroundColors;
- (void)setBackgroundColors:(NSArray *)colors;

- (void)setBordered:(BOOL)val;
- (BOOL)bordered;

- (void)setDelegate:(id)delegate;
- (id)delegate;

- (NSData *)data;
- (void)setData:(NSData *)data;

@end

@protocol HFTextViewDelegate <NSObject>

- (void)hexTextView:(HFTextView *)view didChangeProperties:(HFControllerPropertyBits)properties;

@end
