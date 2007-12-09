//
//  MyDocument.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFRepresenter, HFLineCountingRepresenter;

@interface MyDocument : NSDocument {
    IBOutlet NSView *containerView;
    HFController *controller;
    
    HFRepresenter *debugRepresenter;
    HFLineCountingRepresenter *lineCountingRepresenter;
    HFRepresenter *hexRepresenter;
    HFRepresenter *asciiRepresenter;
    HFRepresenter *scrollRepresenter;
}

@end
