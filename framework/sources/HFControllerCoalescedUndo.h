//
//  HFControllerCoalescedUndo.h
//  HexFiend_2
//
//  Created by Peter Ammon on 12/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFTypes.h>

@class HFByteArray;

@interface HFControllerCoalescedUndo : NSObject {
    HFRange rangeToReplace;
    HFByteArray *replacementByteArray;
}

- (HFRange)rangeToReplace;
- (void)setRangeToReplace:(HFRange)range;

- (HFByteArray *)replacementByteArray;

@end
