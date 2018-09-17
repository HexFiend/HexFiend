//
//  HFByteArrayEditScript.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTypes.h>

NS_ASSUME_NONNULL_BEGIN

/*! @class HFByteArrayEditScript
 @brief A class that represents an sequence of instructions for editing an @link HFByteArray @endlink.  
 
 HFByteArrayEditScript is useful for representing a diff between two HFByteArrays.
*/

@class HFByteArray, HFProgressTracker;

/*! @struct HFEditInstruction_t
    @brief A struct that represents a single instruction in an @link HFByteArrayEditScript @endlink.
 
   Replace the bytes in the source in range 'src' with bytes from the destination in range 'dst'.  Note that if src is empty, then it is a pure insertion at src.location; if dst is empty it is a pure deletion of src.  If neither is empty, it is replacing some bytes with others.  It should never happen that both are empty.
 */
struct HFEditInstruction_t {
/*! Source range, to be replaced */
    HFRange src;
    
/*! Destination range, that does the replacing */
    HFRange dst;
};

@interface HFByteArrayEditScript : NSObject {
    HFByteArray *source;
    HFByteArray *destination;
    
    unsigned long long sourceLength;
    unsigned long long destLength;
    
    volatile const int *cancelRequested;
    volatile int64_t *currentProgress;
    
    int32_t concurrentProcesses;
    dispatch_queue_t insnQueue;
    struct HFEditInstruction_t *insns;
    size_t insnCount, insnCapacity;
}

/*! Computes the edit script (differences) from src to dst.  This retains both src and dst, and if they are modified then the receiver will likely no longer function. You may optionally pass an HFProgressTracker for progress reporting and cancellation.  This returns nil if it was cancelled. */
- (nullable instancetype)initWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst trackingProgress:(nullable HFProgressTracker *)progressTracker;

/*! Applies the receiver to an HFByteArray. */
- (void)applyToByteArray:(HFByteArray *)byteArray;

/*! Returns the number of instructions. */
- (NSUInteger)numberOfInstructions;

/*! Returns the instruction at a given index. */
- (struct HFEditInstruction_t)instructionAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
