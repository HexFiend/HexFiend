//
//  HFProcessMemoryByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 8/23/09.
//  Copyright 2009 Apple Computer. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>


@interface HFProcessMemoryByteSlice : HFByteSlice {
    pid_t processIdentifier;
    HFRange memoryRange;
}

- (id)initWithPID:(pid_t)pid range:(HFRange)memoryRange;

@end
