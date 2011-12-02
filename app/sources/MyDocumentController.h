//
//  MyDocumentController.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class BaseDataDocument;

/* We subclass NSDocumentController to work around a bug in which LS crashes when it tries to fetch the icon for a block device. */
@interface MyDocumentController : NSDocumentController

/* Similar to TextEdit */
- (BaseDataDocument *)transientDocumentToReplace;

@end
