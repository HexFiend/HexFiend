//
//  ChooseStringEncodingWindowController.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface StringEncodingLinkButton : NSButton
@end

@interface ChooseStringEncodingWindowController : NSWindowController {
    IBOutlet NSComboBox *encodingField;
    IBOutlet NSButton *okButton;
    NSDictionary *keysToEncodings;
}

- (IBAction)OKButtonClicked:(id)sender;
- (IBAction)openCFStringHeaderClicked:(id)sender;

@end
