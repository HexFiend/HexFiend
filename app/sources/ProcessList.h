//
//  ProcessList.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/29/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface ProcessList : NSObject

- (IBAction)openProcess:(id)sender; //queries the user for a process and opens it
- (IBAction)openProcessByProcessMenuItem:(id)sender; //opens a process from a menu item that directly represents that process

@end
