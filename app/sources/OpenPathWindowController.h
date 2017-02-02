//
//  OpenPathWindowController.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface OpenPathWindowController : NSWindowController {
    IBOutlet NSTextField *pathField;
    IBOutlet NSButton *okButton;

    IBOutlet NSImageView *iconView;
    id operationQueue;
}

- (IBAction)openPathOKButtonClicked:(id)sender;

@end
