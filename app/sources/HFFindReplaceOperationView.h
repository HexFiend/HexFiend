//
//  HFFindReplaceOperationView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 12/1/11.
//  Copyright (c) 2011 ridiculous_fish. All rights reserved.
//

#import "HFDocumentOperationView.h"

@class HFTextField, BaseDataDocument;

@interface HFFindReplaceOperationView : HFDocumentOperationView {
    IBOutlet HFTextField *findField, *replaceField;
    IBOutlet NSSegmentedControl *fieldTypeControl;
    IBOutlet BaseDataDocument *document;
    BOOL installedObservations;
    BOOL fieldTypeIsASCII;
}

- (IBAction)modifyFieldTypeFromControl:(NSSegmentedControl *)sender;

@end
