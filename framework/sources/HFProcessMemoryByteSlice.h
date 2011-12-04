//
//  HFProcessMemoryByteSlice.h
//  HexFiend_2
//
//  Copyright 2009 Apple Computer. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

/*! @class HFProcessMemoryByteSlice
    @brief Some day…
*/
@interface HFProcessMemoryByteSlice : HFByteSlice {
    pid_t processIdentifier;
    HFRange memoryRange;
}

- (id)initWithAddressSpaceOfPID:(pid_t)pid;
- (id)initWithPID:(pid_t)pid range:(HFRange)memoryRange;

@end
