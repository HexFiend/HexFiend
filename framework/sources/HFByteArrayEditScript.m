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

/* indexes into the caches array */
enum {
    SourceForwards,
    SourceBackwards,
    DestForwards,
    DestBackwards
};

typedef long GraphIndex_t;

/* GrowableArray_t allows indexing in the range [-length, length], and preserves data around its center when reallocated. */
struct GrowableArray_t {
    size_t length;
    GraphIndex_t * restrict ptr;
};

static void GrowableArray_reallocate(struct GrowableArray_t *array, size_t minLength, size_t maxLength) {
    /* Since 'length' indicates that we can index in the range [-length, length], we require that (length * 2 - 1) <= MAX(size_t).  Since that's a little tricky to calculate, we require instead that length <= MAX(size_t) / 2, which is slightly more strict  */
    const size_t ultimateMaxLength = ((size_t)(-1)) / 2;
    HFASSERT(minLength <= ultimateMaxLength);
    maxLength = MIN(maxLength, ultimateMaxLength);
    
    /* Don't shrink us.  In practice we shouldn't try to. */
    if (minLength <= array->length) return;
    
    /* The new length is twice the min length */
    size_t newLength = HFSumIntSaturate(minLength, minLength);
        
    /* But don't exceed the maxLength */
    newLength = MIN(newLength, maxLength);
        
    /* We support indexing in the range [-newLength, newLength], which means we need space for 2 * newLength + 1 elements.  And maybe malloc can give us more for free! */
    size_t bufferLength = malloc_good_size((newLength * 2 + 1) * sizeof *array->ptr);
    
    /* Compute the array length backwards from the buffer length: it may be larger if malloc_good_size gave us more. */
    newLength = ((bufferLength / sizeof *array->ptr) - 1) / 2;
    
    /* Allocate our memory */
    GraphIndex_t *newPtr = check_malloc(bufferLength);
    
//    NSLog(@"Allocation: %lu / %lu", minLength, newLength);
    
#if ! NDEBUG
    /* When not optimizing, set it all to -1 to catch bad reads */
    memset(newPtr, -1, bufferLength);
#endif
    
    /* Offset it so it points at the center */
    newPtr += newLength;
    
    if (array->length > 0) {
	/* Copy the data over the center.  For the source, imagine array->length is 3.  Then the buffer looks like -3, -2, -1, 0, 1, 2, 3 with array->ptr pointing at 0.  Thus we subtract 3 to get to the start of the buffer, and the length is 2 * array->length + 1.  For the destination, backtrack the same amount. */

	memcpy(newPtr - array->length, array->ptr - array->length, (2 * array->length + 1) * sizeof *array->ptr);
	
	/* Free the old pointer.  Maybe this frees NULL, which is fine. */
	free(array->ptr - array->length);
    }
    
    /* Now update the array with the new result */
    array->ptr = newPtr;
    array->length = newLength;
}

/* Deallocate the contents of a growable array */
static void GrowableArray_free(struct GrowableArray_t *array) {
    free(array->ptr - array->length);
}


@implementation HFByteArrayEditScript

struct DPath_t {
    struct DPath_t *next;
    long D;
    long *V;
    long array_base[];
};

static struct DPath_t *new_path(const long *V, long D) {
    // valid indexes in V are from -D to D, so we need to allocate 2*D + 1
    size_t array_size = (2*D+1) * sizeof(long);
    struct DPath_t *result = malloc(sizeof(struct DPath_t) + array_size);
    result->next = NULL;
    result->D = D;
    result->V = result->array_base + D;
    memcpy(result->array_base, V - D, array_size);
    return result;
}

static void free_paths(struct DPath_t *path) {
    while (path) {
        struct DPath_t *next = path->next;
        free(path);
        path = next;
    }
}

static BOOL merge_instruction(struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right);

enum HFEditInstructionType {
    HFEditInstructionTypeDelete,
    HFEditInstructionTypeInsert,
    HFEditInstructionTypeReplace
};


static inline enum HFEditInstructionType HFByteArrayInstructionType(struct HFEditInstruction_t insn) {
    HFASSERT(insn.src.length > 0 || insn.dst.length > 0);
    if (insn.src.length == 0) return HFEditInstructionTypeInsert;
    else if (insn.dst.length == 0) return HFEditInstructionTypeDelete;
    else return HFEditInstructionTypeReplace;
}

static inline BOOL smallRangeIsSubrangeOfSmallRange(unsigned long long needleLocation, unsigned long needleLength, unsigned long long haystackLocation, unsigned long haystackLength) {
    // If needle starts before haystack, or if needle is longer than haystack, it is not a subrange of haystack
    if (needleLocation < haystackLocation || needleLength > haystackLength) return NO;
    
    // Their difference in lengths determines the maximum difference in their start locations.  We know that these expressions cannot overflow because of the above checks.
    return haystackLength - needleLength >= needleLocation - haystackLocation;
}

/* SSE optimized versions of difference matching */
#if (defined(__i386__) || defined(__x86_64__))
#include <xmmintrin.h>

static inline size_t match_forwards(const unsigned char * restrict a, const unsigned char * restrict b, size_t length) {
    size_t i;
    for (i=0; i < length; i+=16) {
	__m128i aVec = _mm_loadu_si128((const __m128i *)a);
	__m128i bVec = _mm_loadu_si128((const __m128i *)b);
	__m128i cmpVec = _mm_cmpeq_epi8(aVec, bVec);
	/* cmpVec now has -1 anywhere aVec and bVec differ */
	
	short cmpRes = _mm_movemask_epi8(cmpVec);
	/* cmpRes's low 16 bits correspond to the upper bit of each byte in cmpVec */
	
	if (cmpRes != (short)0xFFFF) {
	    /* Some bit is zero, so we have a non-match.  Find the index of the lowest zero bit.  If it's past the end, then return length.*/
	    int lowBitIdx = __builtin_ffs(~cmpRes);
	    return MIN(i + lowBitIdx - 1, length);
	}
	a += 16;
	b += 16;
    }
    return length;
}

static inline size_t match_backwards(const unsigned char * restrict a, const unsigned char * restrict b, size_t length) {
    size_t i = length;
    while (i > 0 && a[i-1] == b[i-1]) {
	i--;
    }
    return length - i;
}

#else

/* Non-optimized reference versions of the difference matching */
static inline size_t match_forwards(const unsigned char * restrict a, const unsigned char * restrict b, size_t length) {
    size_t i = 0;
    while (i < length && a[i] == b[i]) {
	i++;
    }
    return i;
}

static inline size_t match_backwards(const unsigned char * restrict a, const unsigned char * restrict b, size_t length) {
    size_t i = length;
    while (i > 0 && a[i-1] == b[i-1]) {
	i--;
    }
    return length - i;
}

#endif

#define READ_AMOUNT (1024 * 32)
#define CACHE_AMOUNT (4 * READ_AMOUNT)


/* Returns a pointer to bytes in the given range in the given array, whose length is arrayLen.  Here we avoid using HFRange because compilers are not good at optimizing structs. */
static inline const unsigned char *getCachedBytes(HFByteArrayEditScript *self, HFByteArray *array, unsigned long long arrayLen, unsigned long long rangeLocation, unsigned long rangeLength, unsigned int cacheIndex) {
    HFASSERT(rangeLength <= CACHE_AMOUNT);
    HFASSERT(HFSum(rangeLocation, rangeLength) <= arrayLen);
    HFASSERT(cacheIndex < 4);
    unsigned long long cacheRangeLocation = self->caches[cacheIndex].rangeLocation;
    unsigned long cacheRangeLength = self->caches[cacheIndex].rangeLength;
    if (smallRangeIsSubrangeOfSmallRange(rangeLocation, rangeLength, cacheRangeLocation, cacheRangeLength)) {
	/* Our cache range is valid */
	return rangeLocation - cacheRangeLocation + self->caches[cacheIndex].buffer;
    } else {
	/* We need to recache.  Compute the new cache range */
	unsigned long long newCacheRangeLocation;
	unsigned long newCacheRangeLength;
	
	if (CACHE_AMOUNT >= arrayLen) {
	    /* We can cache the entire array */
	    newCacheRangeLocation = 0;
	    newCacheRangeLength = ll2l(arrayLen);
	} else {
	    /* The array is bigger than our cache amount, so we will cache our full amount. */
	    newCacheRangeLength = CACHE_AMOUNT;
	    
	    /* We will only cache part of the array.  Our cache will certainly cover the requested range.  Compute how to extend the cache around that range. */
	    const unsigned long long maxLeftExtension = rangeLocation, maxRightExtension = arrayLen - rangeLocation - rangeLength;
	    
	    /* Give each side up to half, biasing towards the right */
	    unsigned long remainingExtension = CACHE_AMOUNT - rangeLength;
	    unsigned long leftExtension = remainingExtension / 2;
	    unsigned long rightExtension = remainingExtension - leftExtension;

	    /* Only one of these can be too big, else CACHE_AMOUNT would be >= arrayLen */
	    HFASSERT(leftExtension <= maxLeftExtension || rightExtension <= maxRightExtension);
	    
	    if (leftExtension >= maxLeftExtension) {
		/* Pin to the left side */
		newCacheRangeLocation = 0;
	    } else if (rightExtension >= maxRightExtension) {
		/* Pin to the right side */
		newCacheRangeLocation = arrayLen - CACHE_AMOUNT;
	    } else {
		/* No pinning necessary */
		newCacheRangeLocation = rangeLocation - leftExtension;
	    }
	}
	
	self->caches[cacheIndex].rangeLocation = newCacheRangeLocation;
	self->caches[cacheIndex].rangeLength = newCacheRangeLength;        
        [array copyBytes:self->caches[cacheIndex].buffer range:HFRangeMake(newCacheRangeLocation, newCacheRangeLength)];
	
#if 1
	const char * const kNames[] = {
	    "forwards source",
	    "backwards source ",
	    "forwards dest",
	    "backwards dest",
	};
//	NSLog(@"Blown %s cache: desired: {%llu, %lu} current: {%llu, %lu} new: {%llu, %lu}", kNames[cacheIndex], rangeLocation, rangeLength, cacheRangeLocation, cacheRangeLength, newCacheRangeLocation, newCacheRangeLength);
	
#endif
	return rangeLocation - newCacheRangeLocation + self->caches[cacheIndex].buffer;
    }
}

static inline unsigned long compute_forwards_snake_length(HFByteArrayEditScript *self, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len, volatile int64_t * restrict outProgress) {
    HFASSERT(a_len > 0 && b_len > 0);
    HFASSERT(a_len + a_offset <= self->sourceLength);
    HFASSERT(b_len + b_offset <= self->destLength);
    unsigned long alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    unsigned long long progressConsumed = 0;
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = getCachedBytes(self, a, self->sourceLength, a_offset + alreadyRead, amountToRead, SourceForwards);
        const unsigned char *b_buff = getCachedBytes(self, b, self->destLength, b_offset + alreadyRead, amountToRead, DestForwards);
	unsigned long matchLen = match_forwards(a_buff, b_buff, amountToRead);
        alreadyRead += matchLen;
        remainingToRead -= matchLen;
	
	/* We've consumed progress equal to (A+B - x) * x, where x = alreadyRead */
	unsigned long long newProgressConsumed = (a_len + b_len - alreadyRead) * (unsigned long long)alreadyRead;
	HFAtomicAdd64(newProgressConsumed - progressConsumed, outProgress);
	progressConsumed = newProgressConsumed;
	
        if (matchLen < amountToRead) break;
    }
    return alreadyRead;
}

/* returns the backwards snake of length no more than MIN(a_len, b_len), starting at a_offset, b_offset (exclusive) */
static inline unsigned long compute_backwards_snake_length(HFByteArrayEditScript *self, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len, volatile int64_t * restrict outProgress) {
    HFASSERT(a_offset <= self->sourceLength);
    HFASSERT(b_offset <= self->destLength);
    HFASSERT(a_len <= a_offset);
    HFASSERT(b_len <= b_offset);
    unsigned long alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    unsigned long long progressConsumed = 0;
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
	const unsigned char *a_buff = getCachedBytes(self, a, self->sourceLength, a_offset - alreadyRead - amountToRead, amountToRead, SourceBackwards);
	const unsigned char *b_buff = getCachedBytes(self, b, self->destLength, b_offset - alreadyRead - amountToRead, amountToRead, DestBackwards);
	size_t matchLen = match_backwards(a_buff, b_buff, amountToRead);
        remainingToRead -= matchLen;
        alreadyRead += matchLen;
	
	/* We've consumed progress equal to (A+B - x) * x, where x = alreadyRead */
	unsigned long long newProgressConsumed = (a_len + b_len - alreadyRead) * (unsigned long long)alreadyRead;
	HFAtomicAdd64(newProgressConsumed - progressConsumed, outProgress);
	progressConsumed = newProgressConsumed;	
	
        if (matchLen < amountToRead) break; //found some non-matching byte
    }
    return alreadyRead;
}

static BOOL can_compute_diff(unsigned long long a_len, unsigned long long b_len) {
    BOOL result = NO;
    // we require (2 * max + 1) * sizeof(long) < LONG_MAX
    // which implies that max < (LONG_MAX / sizeof(long) - 1) / 2
    if (HFSumDoesNotOverflow(a_len, b_len)) {
        unsigned long long max = a_len + b_len;
        result = (max < ((LONG_MAX / sizeof(long)) - 1) / 2);
    }
    return result;
}

struct Snake_t {
    long startX;
    long startY;
    long middleSnakeLength;
    long maxSnakeLength;
    unsigned long long progressConsumed;
};

#if NDEBUG
static long computeMiddleSnakeTraversal(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL direct, BOOL forwards, long k, long D, GraphIndex_t *restrict vector, long aLen, long bLen, unsigned long long xOffset, unsigned long long yOffset, struct Snake_t * restrict outSnake) __attribute__((always_inline));
#endif
static long computeMiddleSnakeTraversal(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL direct, BOOL forwards, long k, long D, GraphIndex_t *restrict vector, long aLen, long bLen, unsigned long long xOffset, unsigned long long yOffset, struct Snake_t * restrict outSnake) {
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
		snakeLength = compute_forwards_snake_length(self, self->source, (unsigned long)xOffset + x, aLen - x, self->destination, (unsigned long)yOffset + y, bLen - y, &unused);
	    } else {
		snakeLength = compute_backwards_snake_length(self, self->source, (unsigned long)xOffset + aLen - x, aLen - x, self->destination, (unsigned long)yOffset + bLen - y, bLen - y, &unused);
	    }
	}
    }
    outSnake->maxSnakeLength = MAX(outSnake->maxSnakeLength, snakeLength);
    x += snakeLength;
    vector[k] = x;
    return snakeLength;   
}

#if NDEBUG
static BOOL computeMiddleSnakeTraversal_OverlapCheck(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL direct, BOOL forwards, long k, long D, GraphIndex_t *restrict vector, long aLen, long bLen, unsigned long long xOffset, unsigned long long yOffset, const GraphIndex_t *restrict overlapVector, struct Snake_t *restrict result) __attribute__((always_inline));
#endif
static BOOL computeMiddleSnakeTraversal_OverlapCheck(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL direct, BOOL forwards, long k, long D, GraphIndex_t *restrict vector, long aLen, long bLen, unsigned long long xOffset, unsigned long long yOffset, const GraphIndex_t *restrict overlapVector, struct Snake_t *restrict result) {
    
    /* Traverse the snake */
    long snakeLength = computeMiddleSnakeTraversal(self, aBuff, bBuff, direct, forwards, k, D, vector, aLen, bLen, xOffset, yOffset, result);
        
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
static struct Snake_t computeMiddleSnake_MaybeDirect(HFByteArrayEditScript *self, BOOL direct, const unsigned char * restrict directABuff, const unsigned char * restrict directBBuff, HFRange rangeInA, HFRange rangeInB, struct GrowableArray_t * restrict forwardsArray, struct GrowableArray_t * restrict backwardsArray) __attribute__((always_inline));
#endif
static struct Snake_t computeMiddleSnake_MaybeDirect(HFByteArrayEditScript *self, BOOL direct, const unsigned char * restrict directABuff, const unsigned char * restrict directBBuff, HFRange rangeInA, HFRange rangeInB, struct GrowableArray_t * restrict forwardsArray, struct GrowableArray_t * restrict backwardsArray) {
    
    /* This function has to "consume" progress equal to rangeInA.length * rangeInB.length. */
    unsigned long long progressAllocated = rangeInA.length * rangeInB.length;
    
    long aLen = ll2l(rangeInA.length), bLen = ll2l(rangeInB.length);
    long aStart = ll2l(rangeInA.location), bStart = ll2l(rangeInB.location);
    
    //maxD = ceil((M + N) / 2)
    const long maxD = ll2l((HFSum(rangeInA.length, rangeInB.length) + 1) / 2);
    
    /* Adding delta to k in the forwards direction gives you k in the backwards direction */
    const long delta = bLen - aLen;
    const BOOL oddDelta = (delta & 1);    
    
    GraphIndex_t *restrict forwardsVector = forwardsArray->ptr;
    GraphIndex_t *restrict backwardsVector = backwardsArray->ptr;
    
    /* Initialize the vector.  Unlike the standard algorithm, we precompute and traverse the snake from the upper left (0, 0) and the lower right (aLen, bLen), so we know there's nothing to do there.  Thus we know that vector[0] is 0, so we initialize that and start at D = 1. */
    forwardsVector[0] = 0;
    backwardsVector[0] = 0;    
    
    /* Our result */
    struct Snake_t result;
    result.maxSnakeLength = 0;
    result.progressConsumed = 0;
    
    for (long D=1; D <= maxD; D++) {
	//if (0 == (D % 256)) printf("%ld / %ld\n", D, maxD);
	
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
	if ((size_t)D > forwardsArray->length || (size_t)D > backwardsArray->length) {
	    GrowableArray_reallocate(forwardsArray, D, maxD);
	    forwardsVector = forwardsArray->ptr;
	    
	    GrowableArray_reallocate(backwardsArray, D, maxD);
	    backwardsVector = backwardsArray->ptr;
	}
	
	for (int direction = 1; direction >= 0; direction--) {
	    const BOOL forwards = (direction == 1);
	    
	    /* we check for overlap on the forwards path if oddDelta is YES and direction is forwards, or oddDelta is NO and direction is backwards */
	    BOOL checkForOverlap = (direction == oddDelta);
	    
	    if (checkForOverlap) {
		/* Check for overlap, but only when the diagonal is within the right range */
		for (long k = -D; k <= D; k += 2) {
		    long flippedK = -(k + delta);
		    /* If we're forwards, the reverse path has only had time to explore diagonals -(D-1) through (D-1).  If we're backwards, it's had time to explore diagonals -D through D. */
		    const long reverseExploredDiagonal = D - direction;
		    if (flippedK >= -reverseExploredDiagonal && flippedK <= reverseExploredDiagonal) {
			if (computeMiddleSnakeTraversal_OverlapCheck(self, directABuff, directBBuff, direct, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, aStart, bStart, (forwards ? backwardsVector : forwardsVector), &result)) {
			    return result;
			}			    
		    } else {
			computeMiddleSnakeTraversal(self, directABuff, directBBuff, direct, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, aStart, bStart, &result);
		    }
		}
	    } else {
		/* Don't check for overlap */
		for (long k = -D; k <= D; k += 2) {
		    computeMiddleSnakeTraversal(self, directABuff, directBBuff, direct, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, aStart, bStart, &result);
		}  
	    }
	}
    }
    /* We don't expect to ever exit this loop */
    [NSException raise:NSInternalInconsistencyException format:@"Diff algorithm terminated unexpectedly"];
    return result;
}

#if NDEBUG
static struct Snake_t computeMiddleSnake(HFByteArrayEditScript *self, HFRange rangeInA, HFRange rangeInB, struct GrowableArray_t * restrict forwardsArray, struct GrowableArray_t * restrict backwardsArray) __attribute__ ((noinline));
#endif
static struct Snake_t computeMiddleSnake(HFByteArrayEditScript *self, HFRange rangeInA, HFRange rangeInB, struct GrowableArray_t * restrict forwardsArray, struct GrowableArray_t * restrict backwardsArray) {
    /* If both our ranges are small enough that they fit in our cache, then we can just read them all in and avoid all the range checking we would otherwise have to do. */
    BOOL direct = (rangeInA.length <= CACHE_AMOUNT && rangeInB.length <= CACHE_AMOUNT);
    if (direct) {
	/* Cache everything */
	const unsigned char * const directABuff = getCachedBytes(self, self->source, self->sourceLength, rangeInA.location, rangeInA.length, SourceForwards);
	const unsigned char * const directBBuff = getCachedBytes(self, self->destination, self->destLength, rangeInB.location, rangeInB.length, DestForwards);
	return computeMiddleSnake_MaybeDirect(self, YES, directABuff, directBBuff, rangeInA, rangeInB, forwardsArray, backwardsArray);
    } else {
	/* We can't cache everything */
	return computeMiddleSnake_MaybeDirect(self, NO, NULL, NULL, rangeInA, rangeInB, forwardsArray, backwardsArray);
    }
}



static void appendInstruction(HFByteArrayEditScript *self, HFRange rangeInA, HFRange rangeInB) {
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInA, HFRangeMake(0, [self->source length])));
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInB, HFRangeMake(0, [self->destination length])));
    if (rangeInA.length || rangeInB.length) {
	/* Make the new instruction */
	const struct HFEditInstruction_t insn = {.src = rangeInA, .dst = rangeInB};
	
	/* Try to merge them */
	BOOL merged = NO;
	NSUInteger insnCount = [self->altInsns length] / sizeof(struct HFEditInstruction_t);
	if (insnCount > 0) {
	    struct HFEditInstruction_t *existingInsns = [self->altInsns mutableBytes];
	    merged = merge_instruction(existingInsns + insnCount - 1, &insn);
	}
	if (! merged) {
	    [self->altInsns appendBytes:&insn length:sizeof insn];
	}
    }
}

static void computeLongestCommonSubsequence(HFByteArrayEditScript *self, HFRange rangeInA, HFRange rangeInB, struct GrowableArray_t * restrict forwardsArray, struct GrowableArray_t * restrict backwardsArray) {
    HFByteArray *source = self->source;
    HFByteArray *destination = self->destination;
    
    /* Compute how much progress we are responsible for "consuming" */
    unsigned long long remainingProgress = rangeInA.length * rangeInB.length;
    
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInA, HFRangeMake(0, [source length])));
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInB, HFRangeMake(0, [destination length])));
    if (rangeInA.length == 0 || rangeInB.length == 0) {
	appendInstruction(self, rangeInA, rangeInB);
	return;
    }
    
    unsigned long prefix = compute_forwards_snake_length(self, source, rangeInA.location, rangeInA.length, destination, rangeInB.location, rangeInB.length, self->currentProgress);
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
	    appendInstruction(self, rangeInA, rangeInB);
	    return;
	}
    }
    
    unsigned long suffix = compute_backwards_snake_length(self, source, HFMaxRange(rangeInA), rangeInA.length, destination, HFMaxRange(rangeInB), rangeInB.length, self->currentProgress);
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
    struct Snake_t middleSnake = computeMiddleSnake(self, rangeInA, rangeInB, forwardsArray, backwardsArray);
    
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
	appendInstruction(self, rangeInA, rangeInB);
	HFAtomicAdd64(remainingProgress, self->currentProgress);
	return;
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
    
    if (prefixRangeA.length > 0 || prefixRangeB.length > 0) {
	computeLongestCommonSubsequence(self, prefixRangeA, prefixRangeB, forwardsArray, backwardsArray);
    }
    if (suffixRangeA.length > 0 || suffixRangeB.length > 0) {
	computeLongestCommonSubsequence(self, suffixRangeA, suffixRangeB, forwardsArray, backwardsArray);
    }
}

- (size_t)computeGraph:(struct DPath_t **)outPaths {
    HFByteArray * const a = source, * const b = destination;
    if (! can_compute_diff([a length], [b length])) {
        [NSException raise:NSInvalidArgumentException format:@"Cannot compute diff between %@ and %@: it would require too much memory!", a, b];
    }
    
    const long a_len = (long)[a length], b_len = (long)[b length];
    const long max = a_len + b_len;
    long * const array_base = malloc((2 * max + 1) * sizeof *array_base);
    long * const V = array_base + max;
    int finished = 0;
    size_t numInsns = 0;
    
    struct DPath_t *path_list = NULL;
    
    V[1] = 0;
    long D;
    int64_t unusedProgress = 0;
    for (D=0; D <= max && ! finished; D++) {
        for (long K = -D; K <= D; K += 2) {
            long X, Y;
            if (K == -D || (K != D && V[K-1] < V[K+1])) {
                X = V[K+1]; //horizontal movement
            }
            else {
                X = V[K-1]+1; //vertical movement
            }
            Y = X - K;
	    unsigned long snakeLength = 0;
	    if (X < a_len && Y < b_len) {
		snakeLength = compute_forwards_snake_length(self, a, X, a_len - X, b, Y, b_len - Y, &unusedProgress);
	    }
            X += snakeLength;
            Y += snakeLength;
            V[K] = X;
            if (X >= a_len && Y >= b_len) {
                finished = YES;
                break;
            }
        }
        if (outPaths) {
            struct DPath_t *next_path = new_path(V, D);
            next_path->next = path_list;
            path_list = next_path;
            numInsns++;
        }
    }
    free(array_base);
    if (outPaths) {
        *outPaths = path_list;
    }
    numInsns -= 1; //ignore the first "fake" instruction
    printf("******** D: %lu\n", D);
    return numInsns;
}

- (void)generateInstructions:(const struct DPath_t *)pathsHead count:(size_t)numInsns diagonal:(long)diagonal {
    if (pathsHead == NULL || pathsHead->D == 0) return;
    insnCount = numInsns;
    insns = NSAllocateCollectable(insnCount * sizeof *insns, 0); //not scanned, collectable
    const struct DPath_t *paths = pathsHead;
    size_t insnTop = insnCount;
    long currentDiagonal = diagonal;
    while (paths->next) {
        assert((currentDiagonal >= -paths->D) && (currentDiagonal <= paths->D));
        long X = paths->V[currentDiagonal];
        long Y = X - currentDiagonal;

        assert(X >= 0);
        assert(Y >= 0);

        /* We are either the result of a horizontal movement followed by a snake, or a vertical movement followed by a snake (or possibly both).  To figure out which, look at the X coordinate of the end of the farthest reaching path in the diagonal above us and below us, and pick the larger; this is because if the smaller is also just one away from the snake, the larger must be too. */
        
        const struct DPath_t * const next = paths->next;
        long xCoordForVertical = (currentDiagonal + 1 <= next->D ? next->V[currentDiagonal + 1] : -2);
        long xCoordForHorizontal = (currentDiagonal - 1 >= - next->D ? next->V[currentDiagonal - 1] : -2);
        
        assert(xCoordForVertical >= 0 || xCoordForHorizontal >= 0);
        BOOL wasVertical = (xCoordForVertical > xCoordForHorizontal);
        if (wasVertical) {
            /* It was vertical */
            currentDiagonal += 1;
            X = xCoordForVertical;
            Y = X - currentDiagonal;
	    //insertion
            insns[--insnTop] = (struct HFEditInstruction_t){.src = HFRangeMake(X, 0), .dst = HFRangeMake(Y, 1)};

        }
        else {
            /* It was horizontal */
            X = xCoordForHorizontal;
            Y = X - currentDiagonal;
                       
	    //deletion
            currentDiagonal -= 1;
            insns[--insnTop] = (struct HFEditInstruction_t){.src = HFRangeMake(X, 1), .dst = HFRangeMake(-1, 0)};
        }
        paths = next;
    }
    assert(insnTop == 0);
}

static BOOL merge_instruction(struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right) {
    if (HFMaxRange(left->src) == right->src.location) {
	/* We can merge these if one (or both) of the dest ranges are empty, or if they are abutting.  Note that if a destination is empty, we have to copy the location from the other one, because we like to give nonsense locations (-1) to zero length ranges.  src never has a nonsense location. */
	if (left->dst.length == 0 || right->dst.length == 0 || HFMaxRange(left->dst) == right->dst.location) {
	    left->src.length = HFSum(left->src.length, right->src.length);
	    if (left->dst.length == 0) left->dst.location = right->dst.location;
	    left->dst.length = HFSum(left->dst.length, right->dst.length);
	    return YES;
	}
    }
    return NO;
}

#if 0
/* This function can be used if we want each instruction to be either insert or delete (no replaces) */
static BOOL merge_instruction_noreplaces(struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right) {
    enum HFEditInstructionType leftType = HFByteArrayInstructionType(*left), rightType = HFByteArrayInstructionType(*right);
    if (leftType == HFEditInstructionTypeDelete && rightType == HFEditInstructionTypeDelete && HFMaxRange(left->src) == right->src.location) {
        /* Merge abutting deletions */
        left->src.length += right->src.length;
        return YES;
    }
    else if (leftType == HFEditInstructionTypeInsert && rightType == HFEditInstructionTypeInsert && left->src.location == right->src.location && HFMaxRange(left->dst) == right->dst.location) {
        /* Merge insertions at the same location from abutting ranges */
        left->dst.length += right->dst.length;
        return YES;
    }
    else {
        /* Not mergeable */
        return NO;
    }
}
#endif

- (void)mergeInstructions {
    if (! insnCount) return;
    size_t leading = 1, trailing = 0;
    for (; leading < insnCount; leading++) {
        if (! merge_instruction(insns + trailing, insns + leading)) {
            trailing++;
            insns[trailing] = insns[leading];
        }
    }
    NSUInteger beforeInsnCount = insnCount;
    size_t beforeSize = malloc_size(insns);
    insnCount = trailing + 1;
    insns = NSReallocateCollectable(insns, insnCount * sizeof *insns, 0);
    printf("Merge: %lu -> %lu, size from %lu to %lu (could be as small as %lu)\n", beforeInsnCount, insnCount, malloc_size(insns), beforeSize, insnCount * sizeof *insns);
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
    /* Create our growable arrays, and give them a healthy amount of space.  We could reduce this if source or destination were smaller. */
    struct GrowableArray_t forwardsArray = {0, 0}, backwardsArray = {0, 0};
    GrowableArray_reallocate(&forwardsArray, 1024, 1024);
    GrowableArray_reallocate(&backwardsArray, 1024, 1024);
    
    /* Compute the longest common subsequence. */
    altInsns = [[NSMutableData alloc] init];
    computeLongestCommonSubsequence(self, HFRangeMake(0, sourceLength), HFRangeMake(0, destLength), &forwardsArray, &backwardsArray);
    
    /* Copy out the data */
    HFASSERT([altInsns length] % sizeof *insns == 0);
    insnCount = [altInsns length] / sizeof *insns;
    insns = NSAllocateCollectable(insnCount * sizeof *insns, 0);//not scanned, collectable
    [altInsns getBytes:insns];
    [altInsns release];
    altInsns = nil;
    
    /* We're done with our vectors */
    GrowableArray_free(&forwardsArray);
    GrowableArray_free(&backwardsArray);
    
    return YES;
}

- (BOOL)computeDifferenceViaDPaths {
    printf("Computing %llu + %llu = %llu\n", [source length], [destination length], [source length] + [destination length]);
    struct DPath_t *paths;
    size_t numIsns = [self computeGraph:&paths];
    [self generateInstructions:paths count:numIsns diagonal:(long)[source length] - (long)[destination length]];
    free_paths(paths);
    [self mergeInstructions];
    return YES;
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
    /* Allocate memory for our caches.  Do it in one big chunk. */
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    const NSUInteger numCaches = sizeof caches / sizeof *caches;
    /* Allow 15 bytes of padding on each side, so that we can always do a 16 byte vector read.  Note that each cache can be the padding for its adjacent caches, so we only have to allocate it on the end. */
    const NSUInteger endPadding = 15;
    unsigned char *basePtr = malloc(CACHE_AMOUNT * numCaches + 2 * endPadding);
    for (NSUInteger i=0; i < numCaches; i++) {
	HFASSERT(caches[i].buffer == NULL);
	caches[i].buffer = basePtr + endPadding + CACHE_AMOUNT * i;
    }
    
    const int localCancelRequested = 0;
    unsigned long long localCurrentProgress = 0;
    
    /* Remember our progress tracker (if any) */
    if (tracker) {
	[tracker retain];
	
	/* Tell our progress tracker how much work to expect.  Here we treat the amount of work as the sum of the horizontal and vertical.  Note: this sum may overflow!  Ugh! */
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
    
    BOOL result;
    if (0) {
	result = [self computeDifferenceViaDPaths];
    } else {
	result = [self computeDifferenceViaMiddleSnakes];
    }
    
    /* All done */
    free(basePtr);
    for (NSUInteger i=0; i < numCaches; i++) {
	caches[i].buffer = NULL;
    }
    
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
