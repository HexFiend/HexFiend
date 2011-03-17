//
//  HexFiendDifLib.mm
//  HexFiend_2
//
//  Created by Peter Ammon on 3/13/11.
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#include "HexFiendDifLib.h"
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFByteArray.h>
#import "HFByteArrayEditScript_Shared.h"
#import "HFFunctions_Private.h"

/* Use some macros for anonymous namespaces so it doesn't try to indent within the {s  */
#define ANON_NAMESPACE_START namespace {
#define ANON_NAMESPACE_END }


ANON_NAMESPACE_START

struct BytesRectangle {
    HFRange srcRange;
    HFRange dstRange;
};

class BufferedByteRectangle {
public:
    unsigned long long srcOffset;
    size_t srcLength;
    const unsigned char *srcBuffer;
    
    unsigned long long dstOffset;
    size_t dstLength;
    const unsigned char *dstBuffer;
    
    HFRange src_range(void) const { return HFRangeMake(srcOffset, srcLength); }
    HFRange dst_range(void) const { return HFRangeMake(dstOffset, dstLength); }

    unsigned long long compute_forwards_snake_length(volatile const int * cancelRequested, volatile unsigned long long *outProgress) const {
        unsigned long long match = match_forwards(srcBuffer, dstBuffer, MIN(srcLength, dstLength));

        /* We've consumed progress equal to (A+B - x) * x, where x = match */
        unsigned long long progressConsumed = (srcLength + dstLength - match) * match;
        HFAtomicAdd64((int64_t)progressConsumed, (int64_t *)outProgress);
        
        return progressConsumed;
    }
    
    unsigned long long compute_backwards_snake_length(volatile const int * cancelRequested, volatile unsigned long long *currentProgress) const {
        return match_backwards(srcBuffer + srcLength, dstBuffer + dstLength, MIN(srcLength, dstLength));
    }
    
    void apply_prefix(unsigned long long prefix) {
        HFASSERT(prefix <= srcLength && prefix <= dstLength);
        srcOffset += prefix;
        dstOffset += prefix;
        srcBuffer += prefix;
        dstBuffer += prefix;
        srcLength -= prefix;
        dstLength -= prefix;
    }
    
    void apply_suffix(unsigned long long suffix) {
        HFASSERT(suffix <= srcLength && suffix <= dstLength);
        srcLength -= suffix;
        dstLength -= suffix;
    }
    
    struct Snake_t compute_middle_snake(void) {
        /* This function has to "consume" progress equal to rangeInA.length * rangeInB.length. */
        unsigned long long progressAllocated = srcLength * dstLength;
        
        size_t aLen = srcLength, bLen = dstLength;
        unsigned long long aStart = srcOffset, bStart = dstOffset;
        
        //maxD = ceil((M + N) / 2)
        const size_t maxD = ll2l((HFSum(rangeInA.length, rangeInB.length) + 1) / 2);

        /* Adding delta to k in the forwards direction gives you k in the backwards direction */
        const long long delta = (long long)bLen - (long long)aLen;
        const BOOL oddDelta = (delta & 1); 

        
    }
};

template<class ByteRectangle>
class MiddleSnakeDiff {
public:
    volatile const int * const cancelRequested;
    volatile unsigned long long *currentProgress;

    struct InstructionList_t *computeLongestCommonSubsequence(const ByteRectangle rectangle, struct InstructionList_t *insns) {
        
        /* At various points we check for cancellation requests */
        if (*cancelRequested) return insns;

        /* Compute how much progress we are responsible for "consuming" */
        unsigned long long remainingProgress = rectangle.srcLength * rectangle.dstLength;
        
        if (rectangle.srcLength == 0 || rectangle.dstLength == 0) {
            return append_instruction_to_list(nil, insns, rectangle.src_range(), rectangle.dst_range());
        }
        
        /* Compute any prefix */
        unsigned long long prefix = rectangle.compute_forwards_snake_length(this->currentProgress, this->cancelRequested);
        HFASSERT(prefix <= rectangle.srcLength && prefix <= rectangle.dstLength);
        if (prefix > 0) {
            
            /* Apply the prefix */
            rectangle.apply_prefix(prefix);
            
            /* Recompute the remaining progress. */
            remainingProgress = rectangle.srcLength * rectangle.dstLength;
            
            if (rectangle.srcLength == 0 || rectangle.dstLength == 0) {
                /* All done */
                return append_instruction_to_list(nil, insns, rectangle.src_range(), rectangle.dst_range());
            }
        }
        
        
        /* Compute any suffix */
        unsigned long long suffix = rectangle.compute_backwards_snake_length(this->currentProgress, this->cancelRequested);
        /* The suffix can't have consumed the whole thing though, because the prefix would have caught that */
        HFASSERT(suffix < rectangle.srcLength && suffix < rectangle.dstLength);
        if (suffix > 0) {
            rectangle.apply_suffix(suffix);

            /* Recompute the remaining progress. */
            remainingProgress = rectangle.srcLength * rectangle.dstLength;
            
            /* Note that we don't have to check to see if the snake consumed the entire thing on the reverse path, because we would have caught that with the prefix check up above */
        }
        
        struct Snake_t middleSnake = rectangle.compute_middle_snake(this->currentProgress, this->cancelRequested);
        if (*cancelRequested) return insns;
        
        /* Subtract off how much progress the middle snake consumed.  Note that this may make remainingProgress negative. */
        remainingProgress -= middleSnake.progressConsumed;
        
        if (middleSnake.maxSnakeLength == 0) {
            /* There were no non-empty snakes at all, so the entire range must be a diff */
            HFAtomicAdd64(remainingProgress, this->currentProgress);
            return append_instruction_to_list(this, insns, rectangle.src_range(), rectangle.dst_range());
        }
        
    }
};

template<class Reader>
class Differ {
private:
    const volatile int *cancelRequested;
    volatile unsigned long long *currentProgress;
    BytesRectangle rectangle;
    
    Reader srcReader;
    Reader dstReader;

public:
    Differ(const Reader &pSrcReader, const Reader &pDstReader, const volatile int *pCancelRequested, volatile unsigned long long *pCurrentProgress) : srcReader(pSrcReader), dstReader(pDstReader), cancelRequested(pCancelRequested), currentProgress(pCurrentProgress) {}
    
    BOOL compute_differences(void) {
        
    }
};

/* An adapter class to allow Differ to read from an HFByteArray */
class ByteArrayReaderAdapter {
private:
    HFByteArray *array;
    
public:
    ByteArrayReaderAdapter(HFByteArray *val) : array(val) { }
    
    ByteArrayReaderAdapter(const ByteArrayReaderAdapter &val) : array(val.array) { }
    
    unsigned long long length() {
        return [array length];
    }
    
    void copy_bytes(unsigned char *buffer, HFRange range) {
        [array copyBytes:buffer range:range];
    }
};


ANON_NAMESPACE_END


@interface HFByteArrayEditScript (HFStuff)
- (id)initWithSource:(HFByteArray *)src toDestination:(HFByteArray *)dst;
@end


@implementation HFByteArrayEditScript (HFDiffLib)

- (id)initDiffLibWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst trackingProgress:(HFProgressTracker *)progressTracker {
    [self initWithSource:src toDestination:dst];
    
    BOOL success;
    [progressTracker retain];
    
    const int localCancelRequested = 0;
    unsigned long long localCurrentProgress = 0;
    if (progressTracker) {
        [progressTracker setMaxProgress:[src length] * [dst length]];
        differ.currentProgress = &progressTracker->currentProgress;
        differ.cancelRequested = &progressTracker->cancelRequested;
    } else {
        differ.currentProgress = &localCurrentProgress;
        differ.cancelRequested = &localCancelRequested;
    }
    
    Differ differ(
    
    differ.src = src;
    differ.dst = dst;
    
    success = differ.compute_differences();

    [progressTracker release];
    
    if (success) {
        return self;
    } else {
        /* Cancelled */
        [self release];
        return nil;
    }
}

@end
