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

enum HFEditInstructionType {
    HFEditInstructionTypeDelete,
    HFEditInstructionTypeInsert,
    HFEditInstructionTypeReplace
};

/*! @struct HFEditInstruction
 @breief A struct that represents a single instruction in an @link HFByteArrayEditScript @link.  Replace the bytes in the source in range 'src' with the from the destination in range 'dst'.  Note that if src is empty, then it is a pure insertion at src.location; if dst is empty it is a pure deletion of src.  If neither is empty, it is replacing some bytes with others.  Both are empty should never happen.
 */
struct HFEditInstruction_t {
    HFRange src;
    HFRange dst;
};

static inline enum HFEditInstructionType HFByteArrayInstructionType(struct HFEditInstruction_t insn) {
    HFASSERT(insn.src.length > 0 || insn.dst.length > 0);
    if (insn.src.length == 0) return HFEditInstructionTypeInsert;
    else if (insn.dst.length == 0) return HFEditInstructionTypeDelete;
    else return HFEditInstructionTypeReplace;
}

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
- (id)initWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst;

/*! Applies the receiver to an HFByteArray. */
- (void)applyToByteArray:(HFByteArray *)byteArray;

/*! Returns the number of instructions. */
- (NSUInteger)numberOfInstructions;

/*! Returns the instruction at a given index. */
- (struct HFEditInstruction_t)instructionAtIndex:(NSUInteger)index;

@end
