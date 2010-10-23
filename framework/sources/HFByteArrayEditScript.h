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

@class HFByteArray, HFProgressTracker;

/*! @struct HFEditInstruction
 @breief A struct that represents a single instruction in an @link HFByteArrayEditScript @link.  Replace the bytes in the source in range 'src' with the from the destination in range 'dst'.  Note that if src is empty, then it is a pure insertion at src.location; if dst is empty it is a pure deletion of src.  If neither is empty, it is replacing some bytes with others.  Both are empty should never happen.
 */
struct HFEditInstruction_t {
    HFRange src;
    HFRange dst;
};

@interface HFByteArrayEditScript : NSObject {
    HFByteArray *source;
    HFByteArray *destination;
    
    unsigned long long sourceLength;
    unsigned long long destLength;
  
    struct {
	/* buffer is malloc'd and free'd deterministically, so it should not be marked __strong */
	unsigned char * restrict buffer;
	unsigned long long rangeLocation;
	unsigned long rangeLength;
    } caches[4];
    
    volatile const int *cancelRequested;
    volatile int64_t *currentProgress;
        
    HFRange sourceCacheRange;
    HFRange destCacheRange;
    
    long *forwardsVector;
    long *backwardsVector;
    
    NSMutableData *altInsns;
    
    __strong struct HFEditInstruction_t *insns;
    size_t insnCount;
}

/*! Computes the edit script (differences) from src to dst.  This retains both src and dst, and if they are modified then the receiver will likely no longer function. You may optionally pass an HFProgressTracker for progress reporting and cancellation.  This returns nil if it was cancelled. */
+ (HFByteArrayEditScript *)editScriptFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst trackingProgress:(HFProgressTracker *)progressTracker;

/*! Applies the receiver to an HFByteArray. */
- (void)applyToByteArray:(HFByteArray *)byteArray;

/*! Returns the number of instructions. */
- (NSUInteger)numberOfInstructions;

/*! Returns the instruction at a given index. */
- (struct HFEditInstruction_t)instructionAtIndex:(NSUInteger)index;

@end
