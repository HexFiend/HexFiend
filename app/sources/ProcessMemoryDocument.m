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
    return [HFBTreeByteArray class];
}

@implementation ProcessMemoryDocument

- (void)openProcessWithPID:(pid_t)pid {
    NSLog(@"Yay");
    HFByteSlice *byteSlice = [[[HFProcessMemoryByteSlice alloc] initWithPID:pid range:HFRangeMake(0, 1 + (unsigned long long)UINT_MAX)] autorelease];
    if (byteSlice) {
        HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [controller setByteArray:byteArray];
    }
}

@end
