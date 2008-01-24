//
//  HFFileReference.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/23/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFFileReference : NSObject {
    int fileDescriptor;
    dev_t device;
    unsigned long long fileLength;
    unsigned long long inode;
}

- initWithPath:(NSString *)path;
- (void)close;

- (void)readBytes:(unsigned char *)buff length:(NSUInteger)length from:(unsigned long long)pos;

- (unsigned long long)length;

@end
