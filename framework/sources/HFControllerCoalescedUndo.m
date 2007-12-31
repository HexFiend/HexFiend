//
//  HFControllerCoalescedUndo.m
//  HexFiend_2
//
//  Created by Peter Ammon on 12/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFControllerCoalescedUndo.h>
#import <HexFiend/HFFullMemoryByteArray.h>

@implementation HFControllerCoalescedUndo

- init {
    [super init];
    rangeToReplace = HFRangeMake(ULLONG_MAX, ULLONG_MAX);
    replacementByteArray = [[HFFullMemoryByteArray alloc] init];
    return self;
}

- (void)dealloc {
    [replacementByteArray release];
    [super dealloc];
}

- (HFRange)rangeToReplace {
    return rangeToReplace;
}

- (void)setRangeToReplace:(HFRange)range {
    rangeToReplace = range;
}

- (HFByteArray *)replacementByteArray {
    return replacementByteArray;
}

@end
