//
//  DiffRangeWindowController.h
//  HexFiend_2
//
//  Created by Steven Rogers on 03/14/13.
//  Copyright (c) 2013 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface DiffRangeWindowController : NSWindowController {
    IBOutlet NSTextField *startOfRange;
    IBOutlet NSTextField *lengthOfRange;
}

- (IBAction)compareRange:(id)sender;

- (void)runModal;

@end
