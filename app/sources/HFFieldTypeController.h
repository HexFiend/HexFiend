//
//  HFFieldTypeController.h
//  HexFiend_2
//
//  Created by Peter Ammon on 4/4/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFDocumentOperationView, HFTextField, BaseDataDocument;

@interface HFFieldTypeController : NSObject {
    IBOutlet HFDocumentOperationView *operationView;
    IBOutlet HFTextField *findField, *replaceField;
    IBOutlet BaseDataDocument *document;
    BOOL observingDocument;
    BOOL operationIsRunning;
    BOOL fieldTypeIsASCII;
}

- (BOOL)operationIsRunning;
- (BOOL)fieldTypeIsASCII;
- (void)setFieldTypeIsASCII:(BOOL)val; //not really ASCII; this means text, not hex

@end
