//
//  HFProcessMemoryByteSlice.m
//  HexFiend_2
//
//  Created by Peter Ammon on 8/23/09.
//  Copyright 2009 Apple Computer. All rights reserved.
//

#import "HFProcessMemoryByteSlice.h"
#import "HFPrivilegedHelperConnection.h"

@implementation HFProcessMemoryByteSlice

- (id)initWithPID:(pid_t)pid range:(HFRange)range {
    [super init];
    processIdentifier = pid;
    memoryRange = range;
    return self;
}

- (unsigned long long)length {
    return memoryRange.length;
}

- (HFPrivilegedHelperConnection *)connection {
    return [HFPrivilegedHelperConnection sharedConnection];
}

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(HFMaxRange(range) <= memoryRange.length);
    NSError *error = NULL;
    range.location = HFSum(range.location, memoryRange.location);
    [[self connection] readBytes:dst range:range process:processIdentifier error:&error];
}

- (HFByteSlice *)subsliceWithRange:(HFRange)range {
    HFASSERT(HFMaxRange(range) <= memoryRange.length);
    if (range.length == memoryRange.length) return self;
    HFRange newMemoryRange = HFRangeMake(HFSum(range.location, memoryRange.location), range.length);
    return [[[[self class] alloc] initWithPID:processIdentifier range:newMemoryRange] autorelease];
}

@end
