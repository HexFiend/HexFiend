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
    unsigned long long amountOfMemoryToView = (1ULL << 32);
    
    /* Hacky check to see if we're 64 bit.  If so, we want to view all 64 bits worth of its address space. */
    id app = [NSClassFromString(@"NSRunningApplication") runningApplicationWithProcessIdentifier:pid];
    if (app) {
	NSInteger arch = [app executableArchitecture];
	if (arch == NSBundleExecutableArchitectureX86_64 || arch == NSBundleExecutableArchitecturePPC64) {
	    amountOfMemoryToView = ULLONG_MAX;
	}
    }
    
    HFByteSlice *byteSlice = [[[HFProcessMemoryByteSlice alloc] initWithPID:pid range:HFRangeMake(0, amountOfMemoryToView)] autorelease];
    if (byteSlice) {
        HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [controller setByteArray:byteArray];
    }
}

@end
