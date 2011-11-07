//
//  ProcessMemoryDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 9/6/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "ProcessMemoryDocument.h"
#import <HexFiend/HFProcessMemoryByteSlice.h>

static inline Class preferredByteArrayClass(void) {
    return [HFAttributedByteArray class];
}

@implementation ProcessMemoryDocument

- (void)openProcessWithPID:(pid_t)pid {
    HFByteSlice *byteSlice = [[[HFProcessMemoryByteSlice alloc] initWithAddressSpaceOfPID:pid] autorelease];
    if (byteSlice) {
        HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [controller setByteArray:byteArray];
    }
}

@end
