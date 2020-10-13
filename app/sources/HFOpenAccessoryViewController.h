//
//  HFOpenAccessoryViewController.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 2/2/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface HFOpenAccessoryViewController : NSViewController <NSOpenSavePanelDelegate>

@property (readonly) NSString *extendedAttributeName; // returns nil to open file data

- (void)reset;

@end
