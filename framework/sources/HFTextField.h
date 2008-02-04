//
//  HFTextField.h
//  HexFiend_2
//
//  Created by Peter Ammon on 2/2/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFLayoutRepresenter, HFRepresenter, HFController;

@interface HFTextField : NSControl {
    HFController *dataController;
    HFLayoutRepresenter *layoutRepresenter;
    HFRepresenter *activeRepresenter;
}

@end
