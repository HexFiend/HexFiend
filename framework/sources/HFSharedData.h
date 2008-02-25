//
//  HFSharedData.h
//  HexFiend_2
//
//  Created by Peter Ammon on 2/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


//an implementation of NSMutableData that tracks number of owners
//used for the fast path appending

@interface HFSharedData : NSMutableData {
    __strong void *bytes;
    NSUInteger length;
    NSUInteger capacity;
}

- initWithBytes:(const void *)bytes length:(NSUInteger)length;
- initWithData:(NSData *)data;

@end
