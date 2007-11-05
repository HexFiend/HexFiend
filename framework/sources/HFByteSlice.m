//
//  HFByteSlice.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFByteSlice.h"


@implementation HFByteSlice

- init {
    if ([self class] == [HFByteSlice class]) {
        [NSException raise:NSInvalidArgumentException format:@"init sent to HFByteArray, but HFByteArray is an abstract class.  Instantiate one of its subclasses instead."];
    }
    return [super init];
}

- (unsigned long long)length { UNIMPLEMENTED(); }

- (void)copyBytes:(unsigned char*)dst range:(HFRange)range { USE(dst); USE(range); UNIMPLEMENTED_VOID(); }

- (HFByteSlice *)subsliceWithRange:(HFRange)range { USE(range); UNIMPLEMENTED(); }

@end
