//
//  FiendlingAppDelegate.h
//  HexFiend_2
//
//  Created by Peter Ammon on 6/27/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HexFiend.h>

@interface FiendlingAppDelegate : NSObject {
    /* The tab view in our nib */
    IBOutlet NSTabView *tabView;
    
    /*** FIRST TAB ****/
    /* Data bound to by both the NSTextView and HFTextView */
    NSData *textViewBoundData;

    /*** SECOND TAB ****/    
    HFController *inMemoryController;
    HFController *fileController;

    /*** THIRD TAB ****/        
    HFController *externalDataController;
    IBOutlet NSTextView *externalDataTextView;
    NSData *externalData;
    
    /* Explanatory texts */
    NSArray *explanatoryTexts;
    IBOutlet NSTextField *explanatoryTextField;
    
}

@end
