//
//  HFByteArrayEditScript.h
//  HexFiend_2
//
//  Created by Peter Ammon on 3/7/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*! @class HFByteArrayEditScript
 @brief A class that represents an sequence of instructions for editing an @link HFByteArray @endlink.  
 
 HFByteArrayEditScript is useful for representing a diff between two HFByteArrays.
*/

@class HFByteArray;

@interface HFByteArrayEditScript : NSObject {
    HFByteArray *source;
    HFByteArray *destination;
    
    NSMutableData *sourceCache;
    NSMutableData *destCache;
    
    HFRange sourceCacheRange;
    HFRange destCacheRange;
    
    __strong struct HFEditInstruction_t *insns;
    size_t insnCount;
}

/*! Returns an HFByteArrayEditScript that represents the difference from src to dst.  This retains both src and dst, and if they are modified then the receiver will likely no longer function. */
+ (id)scriptWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst;

/*! Applies the receiver to an HFByteArray. */
- (void)applyToByteArray:(HFByteArray *)byteArray;

@end
