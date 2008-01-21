//
//  HFByteArrayPiece.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArrayPiece.h>
#import <HexFiend/HFByteSlice.h>


@implementation HFByteArrayPiece

- initWithSlice:(HFByteSlice *)sliceParam offset:(unsigned long long)offsetParam {
    REQUIRE_NOT_NULL(sliceParam);
    [super init];
    slice = [sliceParam retain];
    range.location = offsetParam;
    range.length = [slice length];
    return self;
}

- (unsigned long long)offset {
    return range.location;
}

- (void)setOffset:(unsigned long long)offset {
    range.location = offset;
}

- (unsigned long long)length {
    return range.length;
}

- (HFByteSlice*)byteSlice {
    return slice;
}

@end
