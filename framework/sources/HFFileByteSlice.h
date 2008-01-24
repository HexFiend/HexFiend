//
//  HFFileByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/23/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

@class HFFileReference;

@interface HFFileByteSlice : HFByteSlice {
    HFFileReference *fileReference;
    unsigned long long offset;
    unsigned long long length;
}

- initWithFile:(HFFileReference *)file;
- initWithFile:(HFFileReference *)file offset:(unsigned long long)offset length:(unsigned long long)length;

@end
