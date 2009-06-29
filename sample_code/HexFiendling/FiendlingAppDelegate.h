//
//  FiendlingAppDelegate.h
//  HexFiend_2
//
//  Created by Peter Ammon on 6/27/09.
//  Copyright 2009 Apple Computer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HexFiend.h>

@interface FiendlingAppDelegate : NSObject {
    IBOutlet NSTabView *tabView;
    
    HFController *inMemoryController;
    HFController *fileController;
    
    HFController *externalDataController;
    IBOutlet NSTextView *externalDataTextView;
    NSData *externalData;
    
    NSArray *explanatoryTexts;
    IBOutlet NSTextField *explanatoryTextField;
    
}

@end
