//
//  FiendlingAppDelegate.h
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HexFiend.h>

@interface FiendlingAppDelegate : NSObject {
    
    /* The tab view in our nib */
    IBOutlet NSTabView *tabView;
    
    /**** FIRST TAB ****/
    /* Data bound to by both the NSTextView and HFTextView */
    IBOutlet HFTextView *boundDataTextView;
    
    NSData *textViewBoundData;

    /**** SECOND TAB ****/    
    HFController *inMemoryController;
    HFController *fileController;

    /**** THIRD TAB ****/        
    HFController *externalDataController;
    IBOutlet NSTextView *externalDataTextView;
    NSData *externalData;

    
    /* Explanatory texts */
    NSMutableArray *examples;
    IBOutlet NSTextField *explanatoryTextField;
    
}

@end

@interface FiendlingExample : NSObject {
    NSString *label;
    NSString *explanation;
}

@property(readonly) NSString *label;
@property(readonly) NSString *explanation;

+ (instancetype)exampleWithLabel:(NSString *)someLabel explanation:(NSString *)someExplanation;

@end
