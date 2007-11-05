//
//  HFByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFByteSlice : NSObject {
    
}

- (unsigned long long)length;
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range;
- (HFByteSlice *)subsliceWithRange:(HFRange)range;

@end
