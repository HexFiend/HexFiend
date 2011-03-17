//
//  HFByteArrayEditScript.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/7/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArrayEditScript.h>
#import <HexFiend/HFByteArray.h>
#import <HexFiend/HFProgressTracker.h>
#include <malloc/malloc.h>
#include <libkern/OSAtomic.h>
#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFByteArrayEditScript_Shared.h>

#define READ_AMOUNT (1024 * 32)

@implementation HFByteArrayEditScript

/* Returns a pointer to bytes in the given range in the given array, whose length is arrayLen.  Here we avoid using HFRange because compilers are not good at optimizing structs. */
static inline const unsigned char *getCachedBytes(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheList, HFByteArray *array, unsigned long long arrayLen, unsigned long long desiredLocation, unsigned long desiredLength, unsigned int cacheIndex) {
    const HFRange desiredRange = HFRangeMake(desiredLocation, desiredLength);
    HFASSERT(desiredRange.length <= CACHE_AMOUNT);
    HFASSERT(HFMaxRange(desiredRange) <= arrayLen);
    HFASSERT(cacheIndex < 4);
    HFRange cachedRange = cacheList->caches[cacheIndex].range;
    if (HFRangeIsSubrangeOfRange(desiredRange, cachedRange)) {
	/* Our cache range is valid */
	return desiredRange.location - cachedRange.location + cacheList->caches[cacheIndex].buffer;
    } else {
	/* We need to recache.  Compute the new cache range */
	HFRange newCacheRange;
	
	if (CACHE_AMOUNT >= arrayLen) {
	    /* We can cache the entire array */
	    newCacheRange.location = 0;
	    newCacheRange.length = arrayLen;
	} else {
	    /* The array is bigger than our cache amount, so we will cache our full amount. */
	    newCacheRange.length = CACHE_AMOUNT;
	    
	    /* We will only cache part of the array.  Our cache will certainly cover the requested range.  Compute how to extend the cache around that range. */
	    const unsigned long long maxLeftExtension = desiredRange.location, maxRightExtension = arrayLen - desiredRange.location - desiredRange.length;
	    
	    /* Give each side up to half, biasing towards the right */
	    unsigned long remainingExtension = CACHE_AMOUNT - desiredRange.length;
	    unsigned long leftExtension = remainingExtension / 2;
	    unsigned long rightExtension = remainingExtension - leftExtension;

	    /* Only one of these can be too big, else CACHE_AMOUNT would be >= arrayLen */
	    HFASSERT(leftExtension <= maxLeftExtension || rightExtension <= maxRightExtension);
	    
	    if (leftExtension >= maxLeftExtension) {
		/* Pin to the left side */
		newCacheRange.location = 0;
	    } else if (rightExtension >= maxRightExtension) {
		/* Pin to the right side */
		newCacheRange.location = arrayLen - CACHE_AMOUNT;
	    } else {
		/* No pinning necessary */
		newCacheRange.location = desiredRange.location - leftExtension;
	    }
	}
	
	cacheList->caches[cacheIndex].range = newCacheRange;
        [array copyBytes:cacheList->caches[cacheIndex].buffer range:newCacheRange];
	
#if 0
	const char * const kNames[] = {
	    "forwards source",
	    "backwards source ",
	    "forwards dest",
	    "backwards dest",
	};
	NSLog(@"Blown %s cache: desired: {%llu, %lu} current: {%llu, %lu} new: {%llu, %lu}", kNames[cacheIndex], rangeLocation, rangeLength, cacheRangeLocation, cacheRangeLength, newCacheRangeLocation, newCacheRangeLength);
	
#endif
	return desiredRange.location - newCacheRange.location + cacheList->caches[cacheIndex].buffer;
    }
}

static inline unsigned long compute_forwards_snake_length(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len, volatile int64_t * restrict outProgress, const volatile int *cancelRequested) {
    HFASSERT(a_len > 0 && b_len > 0);
    HFASSERT(a_len + a_offset <= self->sourceLength);
    HFASSERT(b_len + b_offset <= self->destLength);
    unsigned long alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    unsigned long long progressConsumed = 0;
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = getCachedBytes(self, cacheGroup, a, self->sourceLength, a_offset + alreadyRead, amountToRead, SourceForwards);
        const unsigned char *b_buff = getCachedBytes(self, cacheGroup, b, self->destLength, b_offset + alreadyRead, amountToRead, DestForwards);
	unsigned long matchLen = match_forwards(a_buff, b_buff, amountToRead);
        alreadyRead += matchLen;
        remainingToRead -= matchLen;
	
	/* We've consumed progress equal to (A+B - x) * x, where x = alreadyRead */
	unsigned long long newProgressConsumed = (a_len + b_len - alreadyRead) * (unsigned long long)alreadyRead;
	HFAtomicAdd64(newProgressConsumed - progressConsumed, outProgress);
	progressConsumed = newProgressConsumed;
	
        if (matchLen < amountToRead) break;
	if (*cancelRequested) break;
    }
    return alreadyRead;
}

/* returns the backwards snake of length no more than MIN(a_len, b_len), starting at a_offset, b_offset (exclusive) */
static inline unsigned long compute_backwards_snake_length(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len, volatile int64_t * restrict outProgress, const volatile int *cancelRequested) {
    HFASSERT(a_offset <= self->sourceLength);
    HFASSERT(b_offset <= self->destLength);
    HFASSERT(a_len <= a_offset);
    HFASSERT(b_len <= b_offset);
    unsigned long alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    unsigned long long progressConsumed = 0;
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
	const unsigned char *a_buff = getCachedBytes(self, cacheGroup, a, self->sourceLength, a_offset - alreadyRead - amountToRead, amountToRead, SourceBackwards);
	const unsigned char *b_buff = getCachedBytes(self, cacheGroup, b, self->destLength, b_offset - alreadyRead - amountToRead, amountToRead, DestBackwards);
	size_t matchLen = match_backwards(a_buff, b_buff, amountToRead);
        remainingToRead -= matchLen;
        alreadyRead += matchLen;
	
	/* We've consumed progress equal to (A+B - x) * x, where x = alreadyRead */
	unsigned long long newProgressConsumed = (a_len + b_len - alreadyRead) * (unsigned long long)alreadyRead;
	HFAtomicAdd64(newProgressConsumed - progressConsumed, outProgress);
	progressConsumed = newProgressConsumed;	
	
        if (matchLen < amountToRead) break; //found some non-matching byte
	if (*cancelRequested) break;
    }
    return alreadyRead;
}

struct Snake_t {
    long startX;
    long startY;
    long middleSnakeLength;
    long maxSnakeLength;
    unsigned long long progressConsumed;
};

#if NDEBUG
static long computeMiddleSnakeTraversal(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL direct, BOOL forwards, long k, long D, GraphIndex_t *restrict vector, long aLen, long bLen, unsigned long long xOffset, unsigned long long yOffset, struct Snake_t * restrict outSnake) __attribute__((always_inline));
#endif
static long computeMiddleSnakeTraversal(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL direct, BOOL forwards, long k, long D, GraphIndex_t *restrict vector, long aLen, long bLen, unsigned long long xOffset, unsigned long long yOffset, struct Snake_t * restrict outSnake) {
    long x, y;
    
    /* k-1 represents considering a movement from the left, while k + 1 represents considering a movement from above */
    if (k == -D || (k != D && vector[k-1] < vector[k+1])) {
        x = vector[k + 1]; // down
    } else {
        x = vector[k - 1] + 1; // right
    }
    y = x - k;
    
    // find the end of the furthest reaching forward D-path in diagonal k.  We require x >= 0, but we don't need to check for it since it's guaranteed by the algorithm.
    long snakeLength = 0;
    int64_t unused = 0;
    HFASSERT(x >= 0);
    if (y >= 0 && x < aLen && y < bLen) {
        /* The intent is that both "direct" and "forwards" are known constants, so with the forced inlining above, these branches can be evaluated at compile time */
	if (direct) {
	    /* Direct buffer access */
	    const long maxSnakeLength = MIN(aLen - x, bLen - y);
	    if (forwards) {
		snakeLength = match_forwards(aBuff + x, bBuff + y, maxSnakeLength);
	    } else {
		snakeLength = match_backwards(aBuff + aLen - x - maxSnakeLength, bBuff + bLen - y - maxSnakeLength, maxSnakeLength);
	    }
	} else {
	    /* Indirect buffer access */
	    if (forwards) {
		snakeLength = compute_forwards_snake_length(self, cacheGroup, self->source, (unsigned long)xOffset + x, aLen - x, self->destination, (unsigned long)yOffset + y, bLen - y, &unused, self->cancelRequested);
	    } else {
		snakeLength = compute_backwards_snake_length(self, cacheGroup, self->source, (unsigned long)xOffset + aLen - x, aLen - x, self->destination, (unsigned long)yOffset + bLen - y, bLen - y, &unused, self->cancelRequested);
	    }
	}
    }
    outSnake->maxSnakeLength = MAX(outSnake->maxSnakeLength, snakeLength);
    x += snakeLength;
    vector[k] = x;
    return snakeLength;   
}

#if NDEBUG
static BOOL computeMiddleSnakeTraversal_OverlapCheck(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL direct, BOOL forwards, long k, long D, GraphIndex_t *restrict vector, long aLen, long bLen, unsigned long long xOffset, unsigned long long yOffset, const GraphIndex_t *restrict overlapVector, struct Snake_t *restrict result) __attribute__((always_inline));
#endif
static BOOL computeMiddleSnakeTraversal_OverlapCheck(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL direct, BOOL forwards, long k, long D, GraphIndex_t *restrict vector, long aLen, long bLen, unsigned long long xOffset, unsigned long long yOffset, const GraphIndex_t *restrict overlapVector, struct Snake_t *restrict result) {
    
    /* Traverse the snake */
    long snakeLength = computeMiddleSnakeTraversal(self, cacheGroup, aBuff, bBuff, direct, forwards, k, D, vector, aLen, bLen, xOffset, yOffset, result);
        
    /* Check for overlap */
    long delta = bLen - aLen;
    long flippedK = -(k + delta);
    if (vector[k] + overlapVector[flippedK] >= aLen) {
        if (forwards) {
            result->startX = xOffset + vector[k] - snakeLength;
            result->startY = yOffset + vector[k] - snakeLength - k;
        } else {
            result->startX = xOffset + aLen - vector[k];
            result->startY = yOffset + bLen - (vector[k] - k);
        }
        result->middleSnakeLength = snakeLength;
        return YES;
    } else {
        return NO;
    }
}

#if NDEBUG
static struct Snake_t computeMiddleSnake_MaybeDirect(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, BOOL direct, long giveUpD, const unsigned char * restrict directABuff, const unsigned char * restrict directBBuff, HFRange rangeInA, HFRange rangeInB) __attribute__((always_inline));
#endif
static struct Snake_t computeMiddleSnake_MaybeDirect(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, BOOL direct, long giveUpD, const unsigned char * restrict directABuff, const unsigned char * restrict directBBuff, HFRange rangeInA, HFRange rangeInB) {
    
    /* This function has to "consume" progress equal to rangeInA.length * rangeInB.length. */
    unsigned long long progressAllocated = rangeInA.length * rangeInB.length;
    
    long aLen = ll2l(rangeInA.length), bLen = ll2l(rangeInB.length);
    long aStart = ll2l(rangeInA.location), bStart = ll2l(rangeInB.location);
    
    //maxD = ceil((M + N) / 2)
    const long maxD = MIN(giveUpD, ll2l((HFSum(rangeInA.length, rangeInB.length) + 1) / 2));
    
    /* Adding delta to k in the forwards direction gives you k in the backwards direction */
    const long delta = bLen - aLen;
    const BOOL oddDelta = (delta & 1); 
    
    GraphIndex_t *restrict forwardsVector = cacheGroup->forwardsArray.ptr;
    GraphIndex_t *restrict backwardsVector = cacheGroup->backwardsArray.ptr;
    size_t forwardsBackwardsVectorLength = MIN(cacheGroup->forwardsArray.length, cacheGroup->backwardsArray.length);
    
    /* Initialize the vector.  Unlike the standard algorithm, we precompute and traverse the snake from the upper left (0, 0) and the lower right (aLen, bLen), so we know there's nothing to do there.  Thus we know that vector[0] is 0, so we initialize that and start at D = 1. */
    forwardsVector[0] = 0;
    backwardsVector[0] = 0;    
    
    /* Our result */
    struct Snake_t result;
    result.maxSnakeLength = 0;
    result.progressConsumed = 0;
    
    volatile const int * const cancelRequested = self->cancelRequested;
    
    long D;
    for (D=1; D <= maxD; D++) {
	if (0 == (D % 256)) printf("%ld / %ld\n", D, maxD);
	
	/* Check for cancellation */
	if (*cancelRequested) break;
	
	/* We haven't yet found the middle snake.  The "worst case" would be a 0-length snake on some diagonal.  Which diagonal maximizes the "badness?"  I wrote out the equations and took the derivative and found it had a max at (d/2) + (N-M)/4, which is sort of intuitive...I guess. (N is the width, M is the height).
	 
	 Rounding is a concern.  While the continuous equation has a max at that point, it's not clear which integer on either side of it produces a worse-r case.  (That is, we don't know which way to round). Rather than try to get that right, we let our progress get a little sloppy: in fact the progress bar may move back very slightly if we pick the wrong worst case, and then we discover the other one.  Tough noogies. 
	 
	 Rewriting (D/2) + (N-M)/4 as (D + (N-M)/2)/2 produces slightly less error.  Writing it as (2D + (N-M)) / 4 might be a bit more efficient, but also is more likely to overflow and does not produce less error.
	 
	 Note that delta = M - N, so -delta is the same as N + M.
	 */
	long worstX = (D - delta/2) / 2;
	if (worstX >= 0) {
	    long worstY = D - worstX;
	    long revWorstX = aLen - worstX;
	    long revWorstY = bLen - worstY;
	    if (worstY >= 0 && revWorstX >= 0 && revWorstY >= 0 && worstX <= revWorstX && worstY <= revWorstY) {
		unsigned long long maxBadnessForThatX = worstX * worstY + revWorstX * revWorstY;
		unsigned long long newProgress = rangeInA.length * rangeInB.length - maxBadnessForThatX;
		//HFASSERT(newProgress >= result.progressConsumed);
		// due to the aforementioned round off error, the above assertion may not be true.
		HFAtomicAdd64(newProgress - result.progressConsumed, self->currentProgress);
		result.progressConsumed = newProgress;
	    }
	}
	
	/* We will be indexing from -D to D, so reallocate if necessary.  It's a little sketchy that we check both forwardsArray->length and backwardsArray->length, which are usually the same size: this is just in case malloc_good_size returns something different for them. */
	if ((size_t)D > forwardsBackwardsVectorLength) {
	    GrowableArray_reallocate(&cacheGroup->forwardsArray, D, maxD);
	    forwardsVector = cacheGroup->forwardsArray.ptr;
	    
	    GrowableArray_reallocate(&cacheGroup->backwardsArray, D, maxD);
	    backwardsVector = cacheGroup->backwardsArray.ptr;
	    
	    forwardsBackwardsVectorLength = MIN(cacheGroup->forwardsArray.length, cacheGroup->backwardsArray.length);
	}
	
	for (int direction = 1; direction >= 0; direction--) {
	    const BOOL forwards = (direction == 1);
	    
	    /* we check for overlap on the forwards path if oddDelta is YES and direction is forwards, or oddDelta is NO and direction is backwards */
	    BOOL checkForOverlap = (direction == oddDelta);
	    
	    if (checkForOverlap) {
		/* Check for overlap, but only when the diagonal is within the right range */
		for (long k = -D; k <= D; k += 2) {
		    if (*cancelRequested) break;
		    
		    long flippedK = -(k + delta);
		    /* If we're forwards, the reverse path has only had time to explore diagonals -(D-1) through (D-1).  If we're backwards, it's had time to explore diagonals -D through D. */
		    const long reverseExploredDiagonal = D - direction;
		    if (flippedK >= -reverseExploredDiagonal && flippedK <= reverseExploredDiagonal) {
			if (computeMiddleSnakeTraversal_OverlapCheck(self, cacheGroup, directABuff, directBBuff, direct, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, aStart, bStart, (forwards ? backwardsVector : forwardsVector), &result)) {
			    return result;
			}			    
		    } else {
			computeMiddleSnakeTraversal(self, cacheGroup, directABuff, directBBuff, direct, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, aStart, bStart, &result);
		    }
		}
	    } else {
		/* Don't check for overlap */
		for (long k = -D; k <= D; k += 2) {
		    if (*cancelRequested) break;
		    
		    computeMiddleSnakeTraversal(self, cacheGroup, directABuff, directBBuff, direct, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, aStart, bStart, &result);
		}
	    }
	}
    }
    
    /* We don't expect to exit this loop unless we cancel or reach giveUpD */
    HFASSERT(*self->cancelRequested || D > giveUpD);
    
    if (D > giveUpD) {
        D = giveUpD;
        /* Find the best diagonals going forwards and backwards */
        long x, y, bestForwardsX = 0, bestForwardsY = 0, bestBackwardsX = 0, bestBackwardsY = 0;
        for (long k = -D; k <= D; k+=2) {
            x = forwardsVector[k];
            y = x - k;
            if (x + y >= bestForwardsX + bestForwardsY) {
                bestForwardsX = x;
                bestForwardsY = y;
            }
            
            x = backwardsVector[k];
            y = x - k;
            if (x + y >= bestBackwardsX + bestBackwardsY) {
                bestBackwardsX = x;
                bestBackwardsY = y;
            }
        }
        
        /* Now return a snake about the best diagonal */
        if (bestForwardsX + bestForwardsY >= bestBackwardsX + bestBackwardsY) {
            /* Forwards is better, or at least no worse */
            result.startX = aStart + bestForwardsX;
            result.startY = bStart + bestForwardsY;
        } else {
            result.startX = aStart + aLen - bestBackwardsX;
            result.startY = bStart + bLen - bestBackwardsY;
        }
        result.middleSnakeLength = 0;
    }
    
    return result;
}

#if NDEBUG
static struct Snake_t computeMiddleSnake(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInA, HFRange rangeInB) __attribute__ ((noinline));
#endif
static struct Snake_t computeMiddleSnake(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInA, HFRange rangeInB) {
    /* If both our ranges are small enough that they fit in our cache, then we can just read them all in and avoid all the range checking we would otherwise have to do. */
    BOOL direct = (rangeInA.length <= CACHE_AMOUNT && rangeInB.length <= CACHE_AMOUNT);
    long giveUpD = LONG_MAX;//100 * 100;
    if (direct) {
	/* Cache everything */
	const unsigned char * const directABuff = getCachedBytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location, rangeInA.length, SourceForwards);
	const unsigned char * const directBBuff = getCachedBytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location, rangeInB.length, DestForwards);
	return computeMiddleSnake_MaybeDirect(self, cacheGroup, YES, giveUpD, directABuff, directBBuff, rangeInA, rangeInB);
    } else {
	/* We can't cache everything */
	return computeMiddleSnake_MaybeDirect(self, cacheGroup, NO, giveUpD, NULL, NULL, rangeInA, rangeInB);
    }
}

static struct InstructionList_t *computeLongestCommonSubsequence(HFByteArrayEditScript *self, struct TLCacheGroup_t *restrict cacheGroup, OSQueueHead * restrict cacheQueueHead, struct InstructionList_t *insns, HFRange rangeInA, HFRange rangeInB) {
    HFByteArray *source = self->source;
    HFByteArray *destination = self->destination;
    
    /* At various points we check for cancellation requests */
    volatile const int * const cancelRequested = self->cancelRequested;
    if (*cancelRequested) return insns;
    
    /* Compute how much progress we are responsible for "consuming" */
    unsigned long long remainingProgress = rangeInA.length * rangeInB.length;
    
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInA, HFRangeMake(0, [source length])));
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInB, HFRangeMake(0, [destination length])));
    if (rangeInA.length == 0 || rangeInB.length == 0) {
        return append_instruction_to_list(self, insns, rangeInA, rangeInB);
    }
    
    unsigned long prefix = compute_forwards_snake_length(self, cacheGroup, source, rangeInA.location, rangeInA.length, destination, rangeInB.location, rangeInB.length, self->currentProgress, cancelRequested);
    HFASSERT(prefix <= rangeInA.length && prefix <= rangeInB.length);
    
    if (prefix > 0) {	
	rangeInA.location += prefix;
	rangeInA.length -= prefix;
	rangeInB.location += prefix;
	rangeInB.length -= prefix;
	
	/* Recompute the remaining progress. */
	remainingProgress = rangeInA.length * rangeInB.length;
	
	if (rangeInA.length == 0 || rangeInB.length == 0) {
	    /* All done */
	    return append_instruction_to_list(self, insns, rangeInA, rangeInB);
	}
    }
    
    unsigned long suffix = compute_backwards_snake_length(self, cacheGroup, source, HFMaxRange(rangeInA), rangeInA.length, destination, HFMaxRange(rangeInB), rangeInB.length, self->currentProgress, cancelRequested);
    HFASSERT(suffix <= rangeInA.length && suffix <= rangeInB.length);
    /* The suffix can't have consumed the whole thing though, because the prefix would have caught that */
    HFASSERT(suffix <= rangeInA.length && suffix <= rangeInB.length);
    if (suffix > 0) {
	rangeInA.length -= suffix;
	rangeInB.length -= suffix;
	
	/* Recompute the remaining progress. */
	remainingProgress = rangeInA.length * rangeInB.length;
	
	/* Note that we don't have to check to see if the snake consumed the entire thing on the reverse path, because we would have caught that with the prefix check up above */
    }
    
    struct Snake_t middleSnake = computeMiddleSnake(self, cacheGroup, rangeInA, rangeInB);
    if (*cancelRequested) return insns;
    
    HFASSERT(middleSnake.middleSnakeLength >= 0);
    HFASSERT(middleSnake.startX >= rangeInA.location);
    HFASSERT(middleSnake.startY >= rangeInB.location);
    HFASSERT(HFSum(middleSnake.startX, middleSnake.middleSnakeLength) <= HFMaxRange(rangeInA));
    HFASSERT(HFSum(middleSnake.startY, middleSnake.middleSnakeLength) <= HFMaxRange(rangeInB));
//    NSLog(@"Middle snake: %lu -> %lu, %lu -> %lu, max: %lu, dPath: %lu", middleSnake.startX, middleSnake.startX + middleSnake.middleSnakeLength, middleSnake.startY, middleSnake.startY + middleSnake.middleSnakeLength, middleSnake.maxSnakeLength, middleSnake.dPathLength);
    
    /* Subtract off how much progress the middle snake consumed.  Note that this may make remainingProgress negative. */
    remainingProgress -= middleSnake.progressConsumed;
    
    if (middleSnake.maxSnakeLength == 0) {
	/* There were no non-empty snakes at all, so the entire range must be a diff */
	HFAtomicAdd64(remainingProgress, self->currentProgress);
	return append_instruction_to_list(self, insns, rangeInA, rangeInB);
    }
    
    HFRange prefixRangeA, prefixRangeB, suffixRangeA, suffixRangeB;
    prefixRangeA = HFRangeMake(rangeInA.location, middleSnake.startX - rangeInA.location);
    prefixRangeB = HFRangeMake(rangeInB.location, middleSnake.startY - rangeInB.location);
    
    suffixRangeA.location = HFSum(middleSnake.startX, middleSnake.middleSnakeLength);
    suffixRangeA.length = HFMaxRange(rangeInA) - suffixRangeA.location;
    
    suffixRangeB.location = HFSum(middleSnake.startY, middleSnake.middleSnakeLength);
    suffixRangeB.length = HFMaxRange(rangeInB) - suffixRangeB.location;
    
    /* Figure out how much we allocate to each of our subranges, and consume the remainder. */
    unsigned long long newRemainingProgress = prefixRangeA.length * prefixRangeB.length + suffixRangeA.length * suffixRangeB.length;
    
    HFAtomicAdd64(remainingProgress - newRemainingProgress, self->currentProgress);
    remainingProgress = newRemainingProgress;
    
    /* We check for *cancelRequested at the beginning of these functions, so we don't gain by checking for it again here */
    const unsigned long long minAsyncLength = 1024;
    BOOL asyncA = prefixRangeA.length > minAsyncLength || prefixRangeB.length > minAsyncLength;
    BOOL asyncB = suffixRangeA.length > minAsyncLength || suffixRangeB.length > minAsyncLength;
    
    if (asyncA && asyncB) {
	/* We'll be running two blocks in parallel.  The left one will append to insns, while the right one will create a new list.  We need to link the end of insns to the new right list, so use a double pointer so that we can set the end of the list. */
	struct InstructionList_t *rightList = malloc(sizeof *rightList);
	struct InstructionList_t *endOfRightList = rightList, *endOfLeftList = insns;
	struct InstructionList_t **endOfLeftListPtr = &endOfLeftList, **endOfRightListPtr = &endOfRightList;
	rightList->count = 0;
	rightList->next = NULL;
	
	dispatch_apply(2, dispatch_get_global_queue(0, 0), ^(size_t idx) {
	    if (idx == 0) {
		*endOfLeftListPtr = computeLongestCommonSubsequence(self, cacheGroup, cacheQueueHead, *endOfLeftListPtr, prefixRangeA, prefixRangeB);
	    } else {
		/* Attempt to dequeue a group.  If we can't, we'll have to make one */
		struct TLCacheGroup_t *newGroup = OSAtomicDequeue(cacheQueueHead, offsetof(struct TLCacheGroup_t, next));
		if (! newGroup) {
		    newGroup = malloc(sizeof *newGroup);
		    initializeCacheGroup(newGroup);
		}
		*endOfRightListPtr = computeLongestCommonSubsequence(self, newGroup, cacheQueueHead, *endOfRightListPtr, suffixRangeA, suffixRangeB);
		/* Put it on the queue (either back or fresh) so others can use it */
		OSAtomicEnqueue(cacheQueueHead, newGroup, offsetof(struct TLCacheGroup_t, next));
	    }
	});

	/* Link up our lists */
	HFASSERT((*endOfLeftListPtr)->next == NULL);
	(*endOfLeftListPtr)->next = rightList;
	insns = *endOfRightListPtr;
    } else {
	if (prefixRangeA.length > 0 || prefixRangeB.length > 0) {
	    insns = computeLongestCommonSubsequence(self, cacheGroup, cacheQueueHead, insns, prefixRangeA, prefixRangeB);
	}
	if (suffixRangeA.length > 0 || suffixRangeB.length > 0) {
	    insns = computeLongestCommonSubsequence(self, cacheGroup, cacheQueueHead, insns, suffixRangeA, suffixRangeB);
	}
    }
    return insns;
}


- (void)convertInstructionsToIncrementalForm {
    long long accumulatedLengthChange = 0;
    size_t idx;
    for (idx = 0; idx < insnCount; idx++) {
        insns[idx].src.location += accumulatedLengthChange;
	accumulatedLengthChange -= insns[idx].src.length;
	accumulatedLengthChange += insns[idx].dst.length;
    }
}

- (void)_dumpDebug {
    printf("Dumping %p:\n", self);
    size_t i;
    for (i=0; i < insnCount; i++) {
        const struct HFEditInstruction_t *isn = insns + i;
	enum HFEditInstructionType type = HFByteArrayInstructionType(*isn);
        if (type == HFEditInstructionTypeInsert) {
            printf("\tInsert %llu at %llu (from %llu)\n", isn->dst.length, isn->src.location, isn->dst.location);
        }
	else if (type == HFEditInstructionTypeDelete) {
	    printf("\tDelete %llu from %llu\n", isn->src.length, isn->src.location);
	}
        else {
            printf("\tReplace %llu with %llu at %llu (from %llu)\n", isn->src.length, isn->dst.length, isn->src.location, isn->dst.location);
        }
    }
}

- (BOOL)computeDifferenceViaMiddleSnakes {
    /* We succeed unless we are cancelled */
    BOOL success = NO;
    
    /* Create one cache */
    struct TLCacheGroup_t cacheGroup;
    initializeCacheGroup(&cacheGroup);
    
    /* Create our queue for additional caches */
    OSQueueHead queueHead = OS_ATOMIC_QUEUE_INIT;
    
    /* Compute the longest common subsequence. */
    struct InstructionList_t stackList;
    stackList.next = NULL;
    stackList.count = 0;
    computeLongestCommonSubsequence(self, &cacheGroup, &queueHead, &stackList, HFRangeMake(0, sourceLength), HFRangeMake(0, destLength));
    
    /* Copy out the data */
    if (! *cancelRequested) {
	size_t numInsns = 0;
	struct InstructionList_t *cursor, *prevNonEmptyLink = NULL;
	
	/* Collapse the linked list into an array.  Do two passes: in the first we count, and in the second we copy. */
	for (cursor = &stackList; cursor != NULL; cursor = cursor->next) {
	    if (! cursor->count) continue;
	    
	    numInsns += cursor->count;
	    if (prevNonEmptyLink && can_merge_instruction(prevNonEmptyLink->insns + prevNonEmptyLink->count - 1, cursor->insns)) {
		/* We can merge the last instruction in the previous link with our first one, so we'll have one fewer instruction */
		numInsns--;
	    }
	    prevNonEmptyLink = cursor;
	}
	
	/* We calculated the number of instructions, so allocate space for that many */
	self->insnCount = numInsns;
	self->insns = NSAllocateCollectable(numInsns * sizeof *insns, 0);//not scanned, collectable
	
	/* Do it again, while copying and freeing */
	cursor = &stackList;
	struct HFEditInstruction_t *nextInstructionPtr = self->insns;
	while (cursor) {
	    if (cursor->count > 0) {
		/* Maybe merge with the previous instruction */
		size_t numMerged = (nextInstructionPtr > self->insns && merge_instruction(nextInstructionPtr - 1, cursor->insns + 0)) ? 1 : 0;
		memcpy(nextInstructionPtr, cursor->insns + numMerged, (cursor->count - numMerged) * sizeof *insns);
		nextInstructionPtr += cursor->count - numMerged;
	    }
	    
	    /* Free this and go to the next */
	    struct InstructionList_t *next = cursor->next;
	    if (cursor != &stackList) free(cursor);
	    cursor = next;
	}
	
	/* We succeed unless we were cancelled */
	success = YES;
    }
        
    /* Free our cache */
    freeCacheGroup(&cacheGroup);
    
    /* Dequeue and free all the other caches, which were allocated with malloc() */
    struct TLCacheGroup_t *additionalCache;
    while ((additionalCache = OSAtomicDequeue(&queueHead, offsetof(struct TLCacheGroup_t, next)))) {
	freeCacheGroup(additionalCache);
	free(additionalCache);
    }
    
    //if (success) [self _dumpDebug];
    
    return success;
}

- (id)initWithSource:(HFByteArray *)src toDestination:(HFByteArray *)dst { 
    [super init];
    NSParameterAssert(src != nil);
    NSParameterAssert(dst != nil);
    source = [src retain];
    destination = [dst retain];
    sourceLength = [source length];
    destLength = [destination length];
    return self;
}


/* Theory of progress reporting: at each step, we attempt to compute the remaining worst case (in time) and show that as the progress.  The Myers diff worst case for diffing two arrays of length M and N is M*N.  Initially we "allocate" that much progress.  In the  linear-space divide-and-conquer variation, we compute the middle snake and then recursively apply the algorithm to two "halves" of the data.  At that point, we "give" some of our allocated progress to the recursive calls, and "consume" the rest by incrementing the progress count. 
 
    Our implementation of the Longest Common Subsequence traverses any leading/trailing snakes.  We can be certain that these snakes are part of the LCS, so they can contribute to our progress.  Imagine that the arrays are of length M and N, for allocated progress M*N.  If we traverse a leading/trailing snake of length x, then the new arrays are of length M-x and N-x, so the new progress is (M-x)*(N-x).  Since we initially allocated M*N, this means we "progressed" by M*N - (M-x)*(N-x), which reduces to (M+N-x)*x.
 */
- (BOOL)computeDifferencesTrackingProgress:(HFProgressTracker *)tracker {
    const int localCancelRequested = 0;
    unsigned long long localCurrentProgress = 0;
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    /* Remember our progress tracker (if any) */
    if (tracker) {
	[tracker retain];
	
	/* Tell our progress tracker how much work to expect.  Here we treat the amount of work as the sum of the horizontal and vertical.  Note: this product may overflow!  Ugh! */
	[tracker setMaxProgress: sourceLength * destLength];
	
	/* Stash away pointers to its direct-write variables */
	cancelRequested = &tracker->cancelRequested;
	currentProgress = (int64_t *)&tracker->currentProgress;
	*currentProgress = 0;
    } else {
	/* No progress tracker, so use our local variables so we don't have to keep checking for nil */
	cancelRequested = &localCancelRequested;
	currentProgress = (int64_t *)&localCurrentProgress;
    }
    
    BOOL result = [self computeDifferenceViaMiddleSnakes];
    
    cancelRequested = NULL;
    currentProgress = NULL;
    [tracker release];
    
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    
    printf("Diffs computed in %.2f seconds\n", end - start);
    
    return result;
}

- (id)initWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst trackingProgress:(HFProgressTracker *)progressTracker {
    [self initWithSource:src toDestination:dst];
    BOOL success = [self computeDifferencesTrackingProgress:progressTracker];
    if (! success) {
	/* Cancelled */
	[self release];
	self = nil;
    }    
    return self;
}

- (void)dealloc {
    [source release];
    [destination release];
    free(insns);
    [super dealloc];
}

- (void)applyToByteArray:(HFByteArray *)target {
    size_t i;
    long long accumulatedLengthChange = 0;
    const struct HFEditInstruction_t *isn = insns;
    for (i=0; i < insnCount; i++) {
        if (isn->dst.length > 0) {
	    /* Replace or insertion */
            HFByteArray *sub = [destination subarrayWithRange:isn->dst];
            [target insertByteArray:sub inRange:HFRangeMake(isn->src.location + accumulatedLengthChange, isn->src.length)];
        }
        else {
            /* Deletion */
            [target deleteBytesInRange:HFRangeMake(isn->src.location + accumulatedLengthChange, isn->src.length)];
        }
	accumulatedLengthChange += isn->dst.length - isn->src.length;
	isn++;
    }
}

- (NSUInteger)numberOfInstructions {
    return insnCount;
}

- (struct HFEditInstruction_t)instructionAtIndex:(NSUInteger)index {
    HFASSERT(index < insnCount);
    return insns[index];
}

@end
