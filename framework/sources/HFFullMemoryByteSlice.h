//
//  HFFullMemoryByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

@interface HFFullMemoryByteSlice : HFByteSlice {
    NSData *data;
}

- initWithData:(NSData *)val;

@end
