//
//  DiffTextViewContainer.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/13/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DiffTextViewContainer : NSView {
    IBOutlet NSView *leftView;
    IBOutlet NSView *rightView;
    CGFloat interviewDistance;
}

@end
