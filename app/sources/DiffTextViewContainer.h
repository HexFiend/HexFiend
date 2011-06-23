//
//  DiffTextViewContainer.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/13/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFTextView;

@interface DiffTextViewContainer : NSView {
    IBOutlet HFTextView *leftView;
    IBOutlet HFTextView *rightView;
    CGFloat interviewDistance;
    BOOL registeredForAppNotifications;
    
}

- (NSSize)minimumFrameSizeForProposedSize:(NSSize)frameSize;

@end
