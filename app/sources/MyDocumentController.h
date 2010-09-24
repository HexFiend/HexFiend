//
//  MyDocumentController.h
//  HexFiend_2
//
//  Created by Peter Ammon on 9/11/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/* We subclass NSDocumentController to work around a bug in which LS crashes when it tries to fetch the icon for a block device. */
@interface MyDocumentController : NSDocumentController

@end
