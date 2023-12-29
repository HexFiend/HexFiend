//
//  HFByteArrayEditScript.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArrayEditScript.h>
#import <HexFiend/HFByteArray.h>
#import <HexFiend/HFProgressTracker.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>
#import "HFByteArray_Internal.h"
#include <malloc/malloc.h>
#include <libkern/OSAtomic.h>
#include <pthread.h>
#include <stdbool.h>

#define READ_AMOUNT (1024u * 32u)
#define CONCURRENT_PROCESS_COUNT 16
#define MAX_RECURSION_DEPTH 64u

#if NDEBUG
#define BYTEARRAY_RELEASE_INLINE __attribute__((always_inline)) static
#else
#define BYTEARRAY_RELEASE_INLINE __attribute__((noinline)) static
#endif

/* indexes into a caches */
enum {
    SourceForwards,
    SourceBackwards,
    DestForwards,
    DestBackwards,
    
    NUM_CACHES
};

#define HEURISTIC_THRESHOLD (1024u)
#define SQUARE_CACHE_SIZE (1024u)

// This is the type of an abstract index in some local LCS problem
typedef int32_t LocalIndex_t;

/* GrowableArray_t is an array that allows indexing in the range [-length, length], and preserves data around its center when reallocated. */
struct GrowableArray_t {
    size_t length;
    LocalIndex_t * __restrict__ ptr;
};

static size_t GrowableArray_reallocate(struct GrowableArray_t *array, size_t minLength, size_t maxLength) {
    /* Since 'length' indicates that we can index in the range [-length, length], we require that (length * 2 - 1) <= MAX(size_t).  Since that's a little tricky to calculate, we require instead that length <= MAX(size_t) / 2, which is slightly more strict  */
    const size_t ultimateMaxLength = ((size_t)(-1)) / 2;
    HFASSERT(minLength <= ultimateMaxLength);
    maxLength = MIN(maxLength, ultimateMaxLength);
    
    /* Don't shrink us. */
    if (minLength <= array->length) return array->length;
    
    /* The new length is twice the min length */
    size_t newLength = HFSumIntSaturate(minLength, minLength);
    
    /* But don't exceed the maxLength */
    newLength = MIN(newLength, maxLength);
    
    /* We support indexing in the range [-newLength, newLength], which means we need space for 2 * newLength + 1 elements.  And maybe malloc can give us more for free! */
    size_t bufferLength = malloc_good_size((newLength * 2 + 1) * sizeof *array->ptr);
    
    /* Compute the array length backwards from the buffer length: it may be larger if malloc_good_size gave us more. */
    newLength = ((bufferLength / sizeof *array->ptr) - 1) / 2;
    //    printf("new length: %lu (%lu)\n", newLength, (newLength * 8) % aligner);
    
    /* Allocate our memory */
    //LocalIndex_t *newPtr = check_malloc(bufferLength);
    LocalIndex_t *newPtr = (LocalIndex_t *)valloc(bufferLength);
    
    //    NSLog(@"Allocation: %lu / %lu", minLength, newLength);
    
#if ! NDEBUG
    /* When not optimizing, set it all to -1 to catch bad reads */
    memset(newPtr, -1, bufferLength);
#endif
    
    /* Offset it so it points at the center */
    newPtr += newLength;
    
    //printf("Newptr: %lu\n", ((unsigned long)newPtr) & 4095);
    
    if (array->length > 0) {
        /* Copy the data over the center.  For the source, imagine array->length is 3.  Then the buffer looks like -3, -2, -1, 0, 1, 2, 3 with array->ptr pointing at 0.  Thus we subtract 3 to get to the start of the buffer, and the length is 2 * array->length + 1.  For the destination, backtrack the same amount. */
        
        memcpy(newPtr - array->length, array->ptr - array->length, (2 * array->length + 1) * sizeof *array->ptr);
        
        /* Free the old pointer.  Maybe this frees NULL, which is fine. */
        free(array->ptr - array->length);
    }
    
    /* Now update the array with the new result */
    array->ptr = newPtr;
    array->length = newLength;
    return newLength;
}

/* Deallocate the contents of a growable array */
static void GrowableArray_free(struct GrowableArray_t *array) {
    free(array->ptr - array->length);
}

/* A struct that stores thread local data.  This needs to be aligned so it doesn't crash with the cmpxchg16b instruction used by OSAtomicEnqueue, etc. */
struct TLCacheGroup_t {
    
    /* Next in the queue */
    struct TLCacheGroup_t *next;
    
    /* The cached data */
    struct {
        unsigned char * __restrict__ buffer;
        HFRange range;
    } caches[4];
    
    /* The growable arrays for storing the furthest reaching D-paths */
    struct GrowableArray_t forwardsArray, backwardsArray;
    
} __attribute__ ((aligned (16)));

/* Create a cache. */
#define CACHE_AMOUNT (2 * 1024 * 1024)
static void initializeCacheGroup(struct TLCacheGroup_t *group) {
    /* Initialize the next pointer to NULL */
    group->next = NULL;
    
    /* Create the buffer caches in one big chunk. Allow 15 bytes of padding on each side, so that we can always do a 16 byte vector read.  Note that each cache can be the padding for its adjacent caches, so we only have to allocate it on the end. */
    const NSUInteger endPadding = 15;
    unsigned char *basePtr = (unsigned char *)malloc(CACHE_AMOUNT * NUM_CACHES + 2 * endPadding);
    for (NSUInteger i=0; i < NUM_CACHES; i++) {
        group->caches[i].buffer = basePtr + endPadding + CACHE_AMOUNT * i;
        group->caches[i].range = HFRangeMake(0, 0);
    }
    
    /* Initialize and allocate our growable arrays.  */
    group->forwardsArray = group->backwardsArray = (struct GrowableArray_t){0, 0};
    GrowableArray_reallocate(&group->forwardsArray, 1024, 1024);
    GrowableArray_reallocate(&group->backwardsArray, 1024, 1024);
}

static void freeCacheGroup(struct TLCacheGroup_t *cache) {
    const NSUInteger endPadding = 15;
    unsigned char *basePtr = cache->caches[0].buffer - endPadding;
    free(basePtr);
    
    GrowableArray_free(&cache->forwardsArray);
    GrowableArray_free(&cache->backwardsArray);
}

static struct TLCacheGroup_t *dequeueOrCreateCacheGroup(OSQueueHead *cacheQueueHead) {
    struct TLCacheGroup_t *newGroup = OSAtomicDequeue(cacheQueueHead, offsetof(struct TLCacheGroup_t, next));
    if (! newGroup) {
        newGroup = malloc(sizeof *newGroup);
        initializeCacheGroup(newGroup);
    }
    return newGroup;
}

struct Snake_t {
    unsigned long long startX;
    unsigned long long startY;
    unsigned long long middleSnakeLength;
    unsigned long long progressConsumed;
    bool hasNonEmptySnake;
};


/* SSE optimized versions of difference matching */
#define EDITSCRIPT_USE_SSE 1
#if EDITSCRIPT_USE_SSE && (defined(__i386__) || defined(__x86_64__))
#include <xmmintrin.h>

/* match_forwards and match_backwards are assumed to be fast enough and to operate on small enough buffers that they don't have to check for cancellation. */
BYTEARRAY_RELEASE_INLINE
LocalIndex_t match_forwards(const unsigned char * restrict a, const unsigned char * restrict b, LocalIndex_t length) {
    /* Quick check for first few bytes in the likely event that we have no snake */
    if (length >= 2) {
        if (a[0] != b[0]) return 0;
        if (a[1] != b[1]) return 1;
    }
    
    for (LocalIndex_t i = 0; i < length; i+=16) {
        __m128i aVec = _mm_loadu_si128((const __m128i *)a);
        __m128i bVec = _mm_loadu_si128((const __m128i *)b);
        __m128i cmpVec = _mm_cmpeq_epi8(aVec, bVec);
        /* cmpVec now has -1 anywhere aVec and bVec differ */
        
        short cmpRes = 0xFFFF & (unsigned)_mm_movemask_epi8(cmpVec);
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

BYTEARRAY_RELEASE_INLINE
LocalIndex_t match_backwards(const unsigned char * restrict a, const unsigned char * restrict b, LocalIndex_t length) {
    if (length >= 2) {
        if (a[length-1] != b[length-1]) return 0;
        if (a[length-2] != b[length-2]) return 1;
    }
    LocalIndex_t i = length;
    const unsigned char * restrict a_curs = a + length - 16;
    const unsigned char * restrict b_curs = b + length - 16;
    while (i > 0) {
        __m128i aVec = _mm_loadu_si128((const __m128i *)a_curs);
        __m128i bVec = _mm_loadu_si128((const __m128i *)b_curs);
        __m128i cmpVec = _mm_cmpeq_epi8(aVec, bVec);
        /* cmpVec now has -1 anywhere aVec and bVec differ */
        
        unsigned int cmpRes = _mm_movemask_epi8(cmpVec);
        /* cmpRes's low 16 bits correspond to the upper bit of each byte in cmpVec. High bits are 0. */
        
        if (cmpRes != 0x0000FFFFu) {
            /* Some bit is zero, so we have a non-match.  Find the index of the highest zero bit in the low 16 bits.  If it's past the end, then return length. */
            unsigned int flipped = (~cmpRes) << 16;
            int highBitIdx = __builtin_clz(flipped);
            return MIN(length - i + highBitIdx, length);
        }
        i -= 16;
        a_curs -= 16;
        b_curs -= 16;
    }
    return length;
}
#else

/* Non-optimized reference versions of the difference matching */
BYTEARRAY_RELEASE_INLINE
LocalIndex_t match_forwards(const unsigned char * restrict a, const unsigned char * restrict b, LocalIndex_t length) {
    LocalIndex_t i = 0;
    while (i < length && a[i] == b[i]) {
        i++;
    }
    return i;
}

BYTEARRAY_RELEASE_INLINE
LocalIndex_t match_backwards(const unsigned char * restrict a, const unsigned char * restrict b, LocalIndex_t length) {
    LocalIndex_t i = length;
    while (i > 0 && a[i-1] == b[i-1]) {
        i--;
    }
    return length - i;
}

#endif

@implementation HFByteArrayEditScript

#if ! NDEBUG
static BOOL validate_instructions(const struct HFEditInstruction_t *insns, size_t insnCount) {
    struct HFEditInstruction_t prevInsn;
    for (size_t i=0; i < insnCount; i++) {
        struct HFEditInstruction_t insn = insns[i];
        if (i > 0) {
            HFASSERT(! HFIntersectsRange(prevInsn.src, insn.src));
            HFASSERT(! HFIntersectsRange(prevInsn.dst, insn.dst));
            HFASSERT(insn.src.location > prevInsn.src.location);
            HFASSERT(insn.dst.location > prevInsn.dst.location);
        }
        prevInsn = insn;
    }
    return YES;
}
#endif

/* The entry point for appending a snake to the instruction list (that is, splitting instructions that contain the snake) */
BYTEARRAY_RELEASE_INLINE
void append_snake_to_instructions(__unsafe_unretained HFByteArrayEditScript *self, unsigned long long srcOffset, unsigned long long dstOffset, unsigned long long snakeLength) {
    HFASSERT(snakeLength > 0);
    dispatch_async(self->insnQueue, ^{
        /* Bail if we cancelled */
        if (*self->cancelRequested) return;
        
        const size_t insnSize = sizeof(struct HFEditInstruction_t);
        
        /* There must be exactly one instruction that contains srcOffset and dstOffset. Our instructions are sorted - use a binary search */
        size_t insnIndex = -1;
        size_t low = 0, high = self->insnCount;
        for (;;) {
            size_t mid = low + (high-low)/2;
            HFRange range = self->insns[mid].src;
            if (srcOffset < range.location) {
                /* Too high */
                high = mid;
            } else if (srcOffset - range.location  >= range.length) {
                /* Too low */
                low = mid + 1;
            } else {
                /* This is it */
                HFASSERT(HFLocationInRange(srcOffset, range));
                insnIndex = mid;
                break;
            }
        }
        HFASSERT(insnIndex != (size_t)-1);
        
#if ! NDEBUG
        /* Ensure this and only this range contains this location */
        size_t j;
        for (j=0; j < self->insnCount; j++) {
            HFASSERT((j==insnIndex) == HFLocationInRange(srcOffset, self->insns[j].src));
        }
#endif
        
        const struct HFEditInstruction_t insn = self->insns[insnIndex];
        HFASSERT(HFLocationInRange(dstOffset, insn.dst));
        HFASSERT(! HFSumIsLargerThanSum(srcOffset, snakeLength, insn.src.location, insn.src.length));
        HFASSERT(! HFSumIsLargerThanSum(dstOffset, snakeLength, insn.dst.location, insn.dst.length));
        
        /* Split the instruction about the snake */
        struct HFEditInstruction_t prefix, suffix;
        HFRangeSplitAboutSubrange(insn.src, HFRangeMake(srcOffset, snakeLength), &prefix.src, &suffix.src);
        HFRangeSplitAboutSubrange(insn.dst, HFRangeMake(dstOffset, snakeLength), &prefix.dst, &suffix.dst);
        
        /* Figure out how many we have */
        size_t numNewInsns = (prefix.src.length || prefix.dst.length) + (suffix.src.length || suffix.dst.length);
        switch (numNewInsns) {
            case 0:
                /* Remove this instruction */
                memmove(self->insns + insnIndex, self->insns + insnIndex + 1, (self->insnCount - insnIndex - 1) * insnSize);
                self->insnCount -= 1;
                break;
            case 1:
                /* Replace this instruction */
                self->insns[insnIndex] = ((prefix.src.length || prefix.dst.length)  ? prefix : suffix);
                break;
            case 2:
                /* Make room for at least one more instruction instructions */
                if (self->insnCount == self->insnCapacity) {
                    size_t desiredCapacity = ((self->insnCount + 1) * 8) / 5;
                    size_t newBufferByteCount = malloc_good_size(desiredCapacity * insnSize);
                    self->insns = check_realloc(self->insns, newBufferByteCount);
                    self->insnCapacity = newBufferByteCount / insnSize;
                }
                HFASSERT(self->insnCount < self->insnCapacity);
                
                /* Move everything to its right over by one */
                size_t numToMove = self->insnCount - insnIndex - 1;
                struct HFEditInstruction_t *tail = self->insns + insnIndex + 1;
                memmove(tail + 1, tail, numToMove * insnSize);
                
                /* Now insert both of our instructions */
                self->insns[insnIndex] = prefix;
                self->insns[insnIndex+1] = suffix;
                self->insnCount += 1;
                break;
        }
    });
}


/* Returns a pointer to bytes in the given range in the given array, whose length is arrayLen.  Here we avoid using HFRange because compilers are not good at optimizing structs. */
static inline const unsigned char *get_cached_bytes(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheList, HFByteArray *array, unsigned long long arrayLen, unsigned long long desiredLocation, size_t desiredLength, unsigned int cacheIndex) {
    USE(self);
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
            unsigned long long remainingExtension = CACHE_AMOUNT - desiredRange.length;
            unsigned long long leftExtension = remainingExtension / 2;
            unsigned long long rightExtension = remainingExtension - leftExtension;
            
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

/* A progress reporting helper block. */
typedef unsigned long long (^ProgressComputer_t)(unsigned long long lengthMatched);

BYTEARRAY_RELEASE_INLINE
unsigned long long compute_forwards_snake_length(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInSource, HFRange rangeInDest, unsigned long long *inoutProgressConsumed, ProgressComputer_t progressComputer) {
    HFByteArray *a = self->source, *b = self->destination;
    const volatile int * const cancelRequested = self->cancelRequested;
    
    HFASSERT(HFMaxRange(rangeInSource) <= self->sourceLength);
    HFASSERT(HFMaxRange(rangeInDest) <= self->destLength);
    unsigned long long alreadyRead = 0, remainingToRead = MIN(rangeInSource.length, rangeInDest.length);
    unsigned long long progressConsumed = (inoutProgressConsumed ? *inoutProgressConsumed : 0);
    while (remainingToRead > 0) {
        LocalIndex_t amountToRead = (LocalIndex_t)MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = get_cached_bytes(self, cacheGroup, a, self->sourceLength, rangeInSource.location + alreadyRead, amountToRead, SourceForwards);
        const unsigned char *b_buff = get_cached_bytes(self, cacheGroup, b, self->destLength, rangeInDest.location + alreadyRead, amountToRead, DestForwards);
        LocalIndex_t matchLen = match_forwards(a_buff, b_buff, amountToRead);
        alreadyRead += matchLen;
        remainingToRead -= matchLen;
        
        /* Report progress. Ratchet it so it doesn't fall backwards. */
        unsigned long long newProgress = progressComputer(alreadyRead);
        if (newProgress > progressConsumed) {
            HFAtomicAdd64(newProgress - progressConsumed, self->currentProgress);
            progressConsumed = newProgress;
        }
        
        /* We may be done or cancelled */ 
        if (matchLen < amountToRead) break;
        if (*cancelRequested) break;
    }
    if (inoutProgressConsumed) *inoutProgressConsumed = progressConsumed;
    return alreadyRead;
}

/* returns the backwards snake of length no more than MIN(a_len, b_len), starting at HFMaxRange(rangeInA), HFMaxRange(rangeInB) (exclusive) */
BYTEARRAY_RELEASE_INLINE
unsigned long long compute_backwards_snake_length(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInSource, HFRange rangeInDest, unsigned long long *inoutProgressConsumed, ProgressComputer_t progressComputer) {
    
    HFByteArray *a = self->source, *b = self->destination;
    const volatile int * const cancelRequested = self->cancelRequested;
    
    HFASSERT(HFMaxRange(rangeInSource) <= self->sourceLength);
    HFASSERT(HFMaxRange(rangeInDest) <= self->destLength);
    unsigned long long alreadyRead = 0, remainingToRead = MIN(rangeInSource.length, rangeInDest.length);
    unsigned long long progressConsumed = (inoutProgressConsumed ? *inoutProgressConsumed : 0);
    unsigned long long a_offset = HFMaxRange(rangeInSource), b_offset = HFMaxRange(rangeInDest);
    while (remainingToRead > 0) {
        LocalIndex_t amountToRead = (LocalIndex_t)MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = get_cached_bytes(self, cacheGroup, a, self->sourceLength, a_offset - alreadyRead - amountToRead, amountToRead, SourceBackwards);
        const unsigned char *b_buff = get_cached_bytes(self, cacheGroup, b, self->destLength, b_offset - alreadyRead - amountToRead, amountToRead, DestBackwards);
        LocalIndex_t matchLen = match_backwards(a_buff, b_buff, amountToRead);
        remainingToRead -= matchLen;
        alreadyRead += matchLen;

        /* Report progress. Ratchet it so it doesn't fall backwards. */
        unsigned long long newProgress = progressComputer(alreadyRead);
        if (newProgress > progressConsumed) {
            HFAtomicAdd64(newProgress - progressConsumed, self->currentProgress);
            progressConsumed = newProgress;
        }
        
        if (matchLen < amountToRead) break; //found some non-matching byte
        if (*cancelRequested) break;
    }
    if (inoutProgressConsumed) *inoutProgressConsumed = progressConsumed;
    return alreadyRead;
}

BYTEARRAY_RELEASE_INLINE
LocalIndex_t computeMiddleSnakeTraversal(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL forwards, LocalIndex_t k, LocalIndex_t D, LocalIndex_t *restrict vector, LocalIndex_t aLen, LocalIndex_t bLen, struct Snake_t * restrict outSnake) {
    USE(self);
    LocalIndex_t x, y;
    
    // We like to use LocalIndex_t instead of long long here, so make sure k fits in one
    HFASSERT(k == (LocalIndex_t)k);
    
    /* k-1 represents considering a movement from the left, while k + 1 represents considering a movement from above */
    if (k == -D || (k != D && vector[k-1] < vector[k+1])) {
        x = vector[k + 1]; // down
    } else {
        x = vector[k - 1] + 1; // right
    }
    y = x - k;
    
    // find the end of the furthest reaching forward D-path in diagonal k.  We require x >= 0, but we don't need to check for it since it's guaranteed by the algorithm.
    LocalIndex_t snakeLength = 0;
    HFASSERT(x >= 0);
    HFASSERT(y >= 0); //I think this is right
    LocalIndex_t maxSnakeLength = MIN(aLen - x, bLen - y);
    
    if (maxSnakeLength > 0) {
        /* The intent is that both "forwards" is a known constant, so with the forced inlining above, these branches can be evaluated at compile time */
        if (forwards) {
            snakeLength = match_forwards(aBuff + x, bBuff + y, maxSnakeLength);
        } else {
            snakeLength = match_backwards(aBuff + aLen - x - maxSnakeLength, bBuff + bLen - y - maxSnakeLength, maxSnakeLength);
        }
        x += snakeLength;
        if (snakeLength > 0) outSnake->hasNonEmptySnake = YES;
    }
    vector[k] = x;
    return snakeLength;   
}

BYTEARRAY_RELEASE_INLINE
BOOL computeMiddleSnakeTraversal_OverlapCheck(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL forwards, LocalIndex_t k, LocalIndex_t D, LocalIndex_t *restrict vector, LocalIndex_t aLen, LocalIndex_t bLen, const LocalIndex_t *restrict overlapVector, struct Snake_t *restrict result) {
    
    /* Traverse the snake */
    LocalIndex_t snakeLength = computeMiddleSnakeTraversal(self, aBuff, bBuff, forwards, k, D, vector, aLen, bLen, result);
    HFASSERT(snakeLength >= 0);
    
    /* Check for overlap */
    long delta = bLen - aLen;
    long flippedK = -(k + delta);
    if (vector[k] + overlapVector[flippedK] >= aLen) {
        LocalIndex_t startX, startY;
        if (forwards) {
            startX = vector[k] - snakeLength;
            startY = vector[k] - snakeLength - k;
        } else {
            startX = aLen - vector[k];
            startY = bLen - (vector[k] - k);
        }
        HFASSERT(snakeLength + startX <= aLen);
        HFASSERT(snakeLength + startY <= bLen);
        
        result->startX = startX;
        result->startY = startY;
        result->middleSnakeLength = snakeLength;
        
        return YES;
    } else {
        return NO;
    }
}

BYTEARRAY_RELEASE_INLINE
struct Snake_t computeActualMiddleSnake(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, const unsigned char * restrict directABuff, const unsigned char * restrict directBBuff, LocalIndex_t aLen, LocalIndex_t bLen) {
    
    /* This function wants to "consume" progress equal to aLen * bLen. */
    HFASSERT(aLen > 0);
    HFASSERT(bLen > 0);
    const unsigned long long progressAllocated = HFProductULL(aLen, bLen);
    
    //maxD = ceil((M + N) / 2)
    const LocalIndex_t maxD = (aLen + bLen + 1) / 2;
    
    /* Adding delta to k in the forwards direction gives you k in the backwards direction */
    const LocalIndex_t delta = bLen - aLen;
    const BOOL oddDelta = (delta & 1) ? YES : NO; 
    
    LocalIndex_t *restrict forwardsVector = cacheGroup->forwardsArray.ptr;
    LocalIndex_t *restrict backwardsVector = cacheGroup->backwardsArray.ptr;
    size_t forwardsBackwardsVectorLength = MIN(cacheGroup->forwardsArray.length, cacheGroup->backwardsArray.length);
    
    /* Initialize the vector.  Unlike the standard algorithm, we precompute and traverse the snake from the upper left (0, 0) and the lower right (aLen, bLen), so we know there's nothing to do there.  Thus we know that vector[0] is 0, so we initialize that and start at D = 1. */
    forwardsVector[0] = 0;
    backwardsVector[0] = 0;    
    
    /* Our result */
    struct Snake_t result;
    result.hasNonEmptySnake = false; // Assume we don't have a non-empty snake. This will get set to true if we discover one.
    result.progressConsumed = 0;
    
    volatile const int * const cancelRequested = self->cancelRequested;
    
    LocalIndex_t D;
    for (D=1; D <= maxD; D++) {
        //if (0 == (D % 256)) printf("Full %ld / %ld\n", D, maxD);
        
        /* Check for cancellation */
        if (*cancelRequested) break;
        
        /* We haven't yet found the middle snake.  The "worst case" would be a 0-length snake on some diagonal.  Which diagonal maximizes the "badness?"  I wrote out the equations and took the derivative and found it had a max at (d/2) + (N-M)/4, which is sort of intuitive...I guess. (N is the width, M is the height).
         
         Rounding is a concern.  While the continuous equation has a max at that point, it's not clear which integer on either side of it produces a worse-r case.  (That is, we don't know which way to round). Rather than try to get that right, we let our progress get a little sloppy: in fact the progress bar may move back very slightly if we pick the wrong worst case, and then we discover the other one.  Tough noogies. 
         
         Rewriting (D/2) + (N-M)/4 as (D + (N-M)/2)/2 produces slightly less error.  Writing it as (2D + (N-M)) / 4 might be a bit more efficient, but also is more likely to overflow and does not produce less error.
         
         Note that delta = M - N, so -delta is the same as N + M.
         
         We clamp X in the range [0, D] too.
         */
        LocalIndex_t worstX = (D - delta/2) / 2;
        worstX = MIN(D, MAX(worstX, 0));
        worstX = MIN(worstX, aLen);
        
        LocalIndex_t worstY = D - worstX;
        worstY = MIN(D, MAX(worstY, 0));
        worstY = MIN(worstY, bLen);
        
        unsigned long long upperLeftRectangle = (unsigned long long)worstX * (unsigned long long)worstY;
        unsigned long long lowerRightRectangle = (unsigned long long)(aLen - worstX) * (unsigned long long)(bLen - worstY);
        unsigned long long progressRemainingForThatXY = upperLeftRectangle + lowerRightRectangle;
        HFASSERT(progressRemainingForThatXY <= progressAllocated);
        unsigned long long progressConsumed = progressAllocated - progressRemainingForThatXY;
        HFAtomicAdd64(progressConsumed - result.progressConsumed, self->currentProgress);
        result.progressConsumed = progressConsumed;
        
        
        /* We will be indexing from up to -D to D, so reallocate if necessary.  It's a little sketchy that we check both forwardsArray->length and backwardsArray->length, which are usually the same size: this is just in case malloc_good_size returns something different for them. */
        if ((size_t)D > forwardsBackwardsVectorLength) {
            GrowableArray_reallocate(&cacheGroup->forwardsArray, D, maxD);
            forwardsVector = cacheGroup->forwardsArray.ptr;
            
            GrowableArray_reallocate(&cacheGroup->backwardsArray, D, maxD);
            backwardsVector = cacheGroup->backwardsArray.ptr;
            
            forwardsBackwardsVectorLength = MIN(cacheGroup->forwardsArray.length, cacheGroup->backwardsArray.length);
        }
        
        /* Manually unrolled loop of length 2, because clang does not unroll it  */
        
        /* We may have buffers of very different sizes. Rather than exploring "empty space" formed by the square, limit the diagonals we explore to the valid range. But make sure we keep the same parity (even/odd) as D!*/
        LocalIndex_t startK = -D, endK = D;
        if (-bLen > startK) {
            /* We're going to skip empty space in the vertical direction (e.g. below our square). Keep same parity as D, rounding towards zero. E.g. if D is even, then -5 -> -4, -4 -> -4; if D is odd, then -6 -> -5, -5 -> -5 .*/
            int parityChange = (D ^ bLen) & 1; //1 if the parities are different
            startK = -bLen + parityChange;
        }
        if (aLen < endK) {
            /* We're going to skip empty space in the horizontal direction (e.g. to the right of our square). Keep same parity as D, rounding towards zero. */
            int parityChange = (D ^ aLen) & 1; //1 if the parities are different
            endK = aLen - parityChange;
        }
        HFASSERT(startK < endK);
        
        /* FORWARDS */
        if (oddDelta) {
            /* Check for overlap, but only when the diagonal is within the right range */
            for (LocalIndex_t k = startK; k <= endK; k += 2) {
                if (*cancelRequested) break;
                
                LocalIndex_t flippedK = -(k + delta);
                /* If we're forwards, the reverse path has only had time to explore diagonals -(D-1) through (D-1).  If we're backwards, it's had time to explore diagonals -D through D. */
                const LocalIndex_t reverseExploredDiagonal = D - 1 /* direction */;
                if (flippedK >= -reverseExploredDiagonal && flippedK <= reverseExploredDiagonal) {
                    if (computeMiddleSnakeTraversal_OverlapCheck(self, directABuff, directBBuff, YES /* forwards */, k, D, forwardsVector, aLen, bLen, backwardsVector, &result)) {
                        return result;
                    }			    
                } else {
                    computeMiddleSnakeTraversal(self, directABuff, directBBuff, YES /* forwards */, k, D, forwardsVector, aLen, bLen, &result);
                }
            }
        } else {
            /* Don't check for overlap */
            for (LocalIndex_t k = startK; k <= endK; k += 2) {
                if (*cancelRequested) break;
                
                computeMiddleSnakeTraversal(self, directABuff, directBBuff, YES /* forwards */, k, D, forwardsVector, aLen, bLen, &result);
            }
        }
        
        /* BACKWARDS */
        if (! oddDelta) {
            /* Check for overlap, but only when the diagonal is within the right range */
            for (LocalIndex_t k = startK; k <= endK; k += 2) {
                if (*cancelRequested) break;
                
                LocalIndex_t flippedK = -(k + delta);
                /* If we're forwards, the reverse path has only had time to explore diagonals -(D-1) through (D-1).  If we're backwards, it's had time to explore diagonals -D through D. */
                const LocalIndex_t reverseExploredDiagonal = D - 0 /* direction */;
                if (flippedK >= -reverseExploredDiagonal && flippedK <= reverseExploredDiagonal) {
                    if (computeMiddleSnakeTraversal_OverlapCheck(self, directABuff, directBBuff, NO /* forwards */, k, D, backwardsVector, aLen, bLen, forwardsVector, &result)) {
                        return result;
                    }			    
                } else {
                    computeMiddleSnakeTraversal(self, directABuff, directBBuff, NO, k, D, backwardsVector, aLen, bLen, &result);
                }
            }
        } else {
            /* Don't check for overlap */
            for (LocalIndex_t k = startK; k <= endK; k += 2) {
                if (*cancelRequested) break;
                
                computeMiddleSnakeTraversal(self, directABuff, directBBuff, NO, k, D, backwardsVector, aLen, bLen, &result);
            }
        }
    }
    
    /* We don't expect to exit this loop unless we cancel */
    HFASSERT(*self->cancelRequested);
    return result;
}

struct LatticePoint_t {
    LocalIndex_t x;
    LocalIndex_t y;
};

BYTEARRAY_RELEASE_INLINE
BOOL computePrettyGoodMiddleSnakeTraversal(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL forwards, LocalIndex_t k, LocalIndex_t D, LocalIndex_t *restrict vector, LocalIndex_t aLen, LocalIndex_t bLen, struct LatticePoint_t * restrict bestAchievedCoords) {
    /* It would be nice if this could be combined with computeMiddleSnakeTraversal */
    USE(self);
    
    LocalIndex_t x, y;
    LocalIndex_t minK = -D, maxK = D;
    HFASSERT(minK <= maxK);
    HFASSERT(k >= minK && k <= maxK);
    
    /* k-1 represents considering a movement from the left, while k + 1 represents considering a movement from above */
    if (k == minK || (k != maxK && vector[k-1] < vector[k+1])) {
        x = vector[k + 1]; // down
    } else {
        x = vector[k - 1] + 1; // right
    }
    y = x - k;
    
    HFASSERT(x >= 0);
    HFASSERT(y >= 0);
    
    /* We may have exceeded either edge. If so, backtrack into the rectangle.*/
    if (x > aLen) {
        y -= (x - aLen);
        x = aLen;
    }
    if (y > bLen) {
        x -= (y - bLen);
        y = bLen;
    }
    
    HFASSERT(x <= aLen);
    HFASSERT(y <= bLen);
    
    /* Compute the snake length. */
    LocalIndex_t maxSnakeLength = MIN(aLen - x, bLen - y);
    
    /* Find the end of the furthest reaching forward D-path in diagonal k */
    LocalIndex_t snakeLength = 0;
    
    /* The intent is that "forwards" is a known constant, so with the forced inlining above, this branch can be evaluated at compile time */
    if (forwards) {
        snakeLength = match_forwards(aBuff + x, bBuff + y, maxSnakeLength);
    } else {
        snakeLength = match_backwards(aBuff + aLen - x - maxSnakeLength, bBuff + bLen - y - maxSnakeLength, maxSnakeLength);
    }

    HFASSERT(snakeLength <= maxSnakeLength);
    x += snakeLength;
    y += snakeLength;
    HFASSERT(x <= aLen);
    HFASSERT(y <= bLen);
    vector[k] = x;
    
    /* Update bestAchievedCoords */
    if (x > bestAchievedCoords->x) bestAchievedCoords->x = x;
    if (y > bestAchievedCoords->y) bestAchievedCoords->y = y;
    
#if 1
    /* Return YES if we reach the edge in either dimension */
    return snakeLength == maxSnakeLength;
#else
    /* Return YES if we reached the edge in the longer dimension, i.e. something like this but exploiting the fact that x <= aLen && y <= bLen:
     if (aLen > bLen) return x == aLen;
     else if (bLen > aLen) return y == bLen;
     else return x == aLen || y == bLen;
     */
    
    return MAX(x, y) == MAX(aLen, bLen);
#endif
}

BYTEARRAY_RELEASE_INLINE
struct LatticePoint_t bestDiagonal(HFByteArrayEditScript *self, LocalIndex_t D, const LocalIndex_t * restrict vector) {
    /* Find the diagonal that did the best. */
    USE(self);
    struct LatticePoint_t result = {0, 0};
    LocalIndex_t bestScore = -1;
    for (LocalIndex_t k = -D; k <= D; k += 2) {
        LocalIndex_t x = vector[k];
        LocalIndex_t y = x - k;
        LocalIndex_t score = x + y;
        if (score > bestScore) {
            bestScore = score;
            result.x = x;
            result.y = y;
        }
    }
    return result;
}

BYTEARRAY_RELEASE_INLINE
struct Snake_t computePrettyGoodMiddleSnake(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInA, HFRange rangeInB, BOOL heuristicInA, BOOL heuristicInB) {
    
    /* At least one dimension must use the heuristic (else we'd just use the full algorithm) */
    HFASSERT(heuristicInA || heuristicInB);
    
    /* This function wants to "consume" progress equal to aLen * bLen. */
    const unsigned long long progressAllocated = HFProductULL(rangeInA.length, rangeInB.length);
    __block unsigned long long progressConsumed = 0;
    
    /* k cannot exceeed SQUARE_CACHE_SIZE so allocate that up front */
    const LocalIndex_t maxD = SQUARE_CACHE_SIZE;
    GrowableArray_reallocate(&cacheGroup->forwardsArray, maxD, maxD);
    GrowableArray_reallocate(&cacheGroup->backwardsArray, maxD, maxD);
    LocalIndex_t * const restrict forwardsVector = cacheGroup->forwardsArray.ptr;
    LocalIndex_t * const restrict backwardsVector = cacheGroup->backwardsArray.ptr;
    
    /* Initialize the vector.  Unlike the standard algorithm, we precompute and traverse the snake from the upper left (0, 0) and the lower right (aLen, bLen), so we know there's nothing to do there.  Thus we know that vector[0] is 0, so we initialize that and start at D = 1. */
    forwardsVector[0] = 0;
    backwardsVector[0] = 0;    
    
    volatile const int * const cancelRequested = self->cancelRequested;    
    struct LatticePoint_t maxAchievedForwards = {0, 0}, maxAchievedBackwards = {0, 0};
    
    /* The offsets of our buffers */
    unsigned long long offsets[NUM_CACHES] = {0, 0, 0, 0};
    
    /* Compute our lengths */
    LocalIndex_t lengths[NUM_CACHES] = {
        [SourceForwards] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInA.length - offsets[SourceForwards]),
        [DestForwards] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInB.length - offsets[DestForwards]),
        [SourceBackwards] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInA.length - offsets[SourceBackwards]),
        [DestBackwards] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInB.length - offsets[DestBackwards])
    };
    
    /* Initialize our buffers */
    const unsigned char * restrict buffers[NUM_CACHES] = {
        [SourceForwards] = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location, lengths[SourceForwards], SourceForwards),
        [DestForwards] = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location, lengths[DestForwards], DestForwards),
        [SourceBackwards] = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, HFMaxRange(rangeInA) - lengths[SourceBackwards], lengths[SourceBackwards], SourceBackwards),
        [DestBackwards] = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, HFMaxRange(rangeInB) - lengths[DestBackwards], lengths[DestBackwards], DestBackwards)
    };
    
    /* Progress reporting helper block */
    const unsigned long long * const offsetsPtr = offsets;
    unsigned long long (^ const progressHelper)(unsigned long long, unsigned long long) = ^(unsigned long long forwardsMatch, unsigned long long backwardsMatch) {
        unsigned long long left, top, right, bottom, upperLeft, lowerRight, newProgressConsumed;
        left = offsetsPtr[SourceForwards] + forwardsMatch;
        top = offsetsPtr[DestForwards] + forwardsMatch;
        right = offsetsPtr[SourceBackwards] + backwardsMatch;
        bottom = offsetsPtr[DestBackwards] + backwardsMatch;
        upperLeft = HFProductULL(left, top);
        lowerRight = HFProductULL(right, bottom);
        if (upperLeft >= lowerRight) {
            newProgressConsumed = progressAllocated - upperLeft - HFProductULL(rangeInA.length - left, rangeInB.length - top);
        } else {
            newProgressConsumed = progressAllocated - lowerRight - HFProductULL(rangeInA.length - right, rangeInB.length - bottom);
        }
        return newProgressConsumed;
    };

    
    LocalIndex_t forwardsD = 0, backwardsD = 0;
    for (;;) {
        
        forwardsD += 1;
        backwardsD += 1;
        
        HFASSERT(forwardsD <= maxD);
        HFASSERT(backwardsD <= maxD);
        
        //if (! (forwardsD % 256)) printf("ForwardsD: %ld\n", (long)forwardsD);
        //if (! (backwardsD % 256)) printf("BackwardsD: %ld\n", (long)backwardsD);        
        
        /* Check for cancellation */
        if (*cancelRequested) break;
        
        BOOL allDone = NO;
        
        /* Manually unrolled variant */
        
#if 0
        /* We may have buffers of very different sizes. Rather than exploring "empty space" formed by the square, limit the diagonals we explore to the valid range. But make sure we keep the same parity (even/odd) as D!*/
        LocalIndex_t startK = -D, endK = D;
        if (-bLen > startK) {
            /* We're going to skip empty space in the vertical direction (e.g. below our square). Keep same parity as D, rounding towards zero. E.g. if D is even, then -5 -> -4, -4 -> -4; if D is odd, then -6 -> -5, -5 -> -5 .*/
            int parityChange = (D ^ bLen) & 1; //1 if the parities are different
            startK = -bLen + parityChange;
        }
        if (aLen < endK) {
            /* We're going to skip empty space in the horizontal direction (e.g. to the right of our square). Keep same parity as D, rounding towards zero. */
            int parityChange = (D ^ aLen) & 1; //1 if the parities are different
            endK = aLen - parityChange;
        }
        HFASSERT(startK < endK);
#endif
        
        /* Forwards */
        BOOL exitedForwards = NO;
        for (LocalIndex_t k = -forwardsD; k <= forwardsD; k += 2) {
            if (*cancelRequested) break;
            if (computePrettyGoodMiddleSnakeTraversal(self, buffers[SourceForwards], buffers[DestForwards], YES /* forwards */, k, forwardsD, forwardsVector, lengths[SourceForwards], lengths[DestForwards], &maxAchievedForwards)) {
                exitedForwards = YES;
            }
        }
        
        /* Backwards */
        BOOL exitedBackwards = NO;
        for (LocalIndex_t k = -backwardsD; k <= backwardsD; k += 2) {
            if (*cancelRequested) break;            
            if (computePrettyGoodMiddleSnakeTraversal(self, buffers[SourceBackwards], buffers[DestBackwards], NO /* backwards */, k, backwardsD, backwardsVector, lengths[SourceBackwards], lengths[DestBackwards], &maxAchievedBackwards)) {
                exitedBackwards = YES;
            }
        }
        
        if (exitedForwards) {
            const int sourceDir = SourceForwards, destDir = DestForwards;
            
            /* Find the diagonal that did the best */
            struct LatticePoint_t diagonal = bestDiagonal(self, forwardsD, forwardsVector);
            HFASSERT(diagonal.x >= 0);
            HFASSERT(diagonal.y >= 0);
            //NSLog(@"bestDiagonal: %d, %d\n", diagonal.x, diagonal.y);
            
            /* Compute our new rectangle starting position */
            offsets[sourceDir] += diagonal.x;
            offsets[destDir] += diagonal.y;
            HFASSERT(offsets[sourceDir] <= rangeInA.length);
            HFASSERT(offsets[destDir] <= rangeInB.length);
            
            /* Extend any forwards snake from that diagonal. */
            HFRange forwardSnakeSrcRange = rangeInA, forwardSnakeDstRange = rangeInB;
            forwardSnakeSrcRange.location += offsets[sourceDir];
            forwardSnakeSrcRange.length -= offsets[sourceDir];
            forwardSnakeDstRange.location += offsets[destDir];
            forwardSnakeDstRange.length -= offsets[destDir];
            
            unsigned long long snakeLength = compute_forwards_snake_length(self, cacheGroup, forwardSnakeSrcRange, forwardSnakeDstRange, &progressConsumed, ^(unsigned long long lengthMatched) {
                return progressHelper(lengthMatched /* forwards match */, 0 /* backwards match */);
            });
            
            offsets[sourceDir] = HFSum(offsets[sourceDir], snakeLength);
            offsets[destDir] = HFSum(offsets[destDir], snakeLength);
            
            /* Compute new lengths */
            lengths[sourceDir] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInA.length - offsets[sourceDir]);
            lengths[destDir] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInB.length - offsets[destDir]);
                        
            /* Now reallocate */
            buffers[sourceDir] = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location + offsets[sourceDir], lengths[sourceDir], sourceDir);
            buffers[destDir] = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location + offsets[destDir], lengths[destDir], destDir);
            
            /* D starts over */
            forwardsD = 0;
            forwardsVector[0] = 0;
            maxAchievedForwards.x = 0;
            maxAchievedForwards.y = 0;
        }
        
        if (exitedBackwards) {
            const int sourceDir = SourceBackwards, destDir = DestBackwards;
            
            /* Find the diagonal that did the best */
            struct LatticePoint_t diagonal = bestDiagonal(self, backwardsD, backwardsVector);
            HFASSERT(diagonal.x >= 0);
            HFASSERT(diagonal.y >= 0);
            
            /* Compute our new rectangle starting position */
            offsets[sourceDir] += diagonal.x;
            offsets[destDir] += diagonal.y;
            HFASSERT(offsets[sourceDir] <= rangeInA.length);
            HFASSERT(offsets[destDir] <= rangeInB.length);
            
            /* Extend any backwards snake from that diagonal. */
            HFRange backwardSnakeSrcRange = rangeInA, backwardSnakeDstRange = rangeInB;
            backwardSnakeSrcRange.length -= offsets[sourceDir];
            backwardSnakeDstRange.length -= offsets[destDir];
            unsigned long long snakeLength = compute_backwards_snake_length(self, cacheGroup, backwardSnakeSrcRange, backwardSnakeDstRange, &progressConsumed, ^(unsigned long long lengthMatched) {
                return progressHelper(0 /* forwards match */, lengthMatched /* backwards match */);
            });
            offsets[sourceDir] = HFSum(offsets[sourceDir], snakeLength);
            offsets[destDir] = HFSum(offsets[destDir], snakeLength);
            
            /* Compute new lengths */
            lengths[sourceDir] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInA.length - offsets[sourceDir]);
            lengths[destDir] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInB.length - offsets[destDir]);
            
            /* Now reallocate */
            buffers[sourceDir] = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, HFMaxRange(rangeInA) - offsets[sourceDir] - lengths[sourceDir], lengths[sourceDir], sourceDir);
            buffers[destDir] = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, HFMaxRange(rangeInB) - offsets[destDir] - lengths[destDir], lengths[destDir], destDir);

            /* Backwards starts over */
            backwardsD = 0;
            backwardsVector[0] = 0;
            maxAchievedBackwards.x = 0;
            maxAchievedBackwards.y = 0;
        }
        
        if (exitedForwards || exitedBackwards) {
            /* Maybe consume more progress (the compute_forwards/backwards_snake_length function may not have called us if there was no snake */
            unsigned long long newProgressConsumed = progressHelper(0, 0);
            if (newProgressConsumed > progressConsumed) {
                HFAtomicAdd64(newProgressConsumed - progressConsumed, self->currentProgress);
                progressConsumed = newProgressConsumed;
            }
        }
        
        /* Check for overlap in either dimension */
        if (heuristicInA) {
            unsigned long long totalX = offsets[SourceForwards] + (unsigned long long)maxAchievedForwards.x + offsets[SourceBackwards] + (unsigned long long)maxAchievedBackwards.x;
            if (totalX > rangeInA.length) allDone = YES;
        }
        if (heuristicInB) {
            unsigned long long totalY = offsets[DestForwards] + (unsigned long long)maxAchievedForwards.y + offsets[DestBackwards] + (unsigned long long)maxAchievedBackwards.y;
            if (totalY > rangeInB.length) allDone = YES;
        }        
        if (allDone) {
            
            /* We're all done! Return the best diagonal thus far. */
            struct LatticePoint_t fw = bestDiagonal(self, forwardsD, forwardsVector);
            struct LatticePoint_t bk = bestDiagonal(self, backwardsD, backwardsVector);
            
            unsigned long long forwardScore = fw.x + fw.y + offsets[SourceForwards] + offsets[DestForwards];
            unsigned long long backwardScore = bk.x + bk.y + offsets[SourceBackwards] + offsets[DestBackwards];
            
            struct Snake_t result;
            result.middleSnakeLength = 0;
            result.progressConsumed = progressConsumed;
            result.hasNonEmptySnake = YES;
            if (forwardScore >= backwardScore) {
                result.startX = rangeInA.location + HFSum(fw.x, offsets[SourceForwards]);
                result.startY = rangeInB.location + HFSum(fw.y, offsets[DestForwards]);
            } else {
                result.startX = HFMaxRange(rangeInA) - HFSum(bk.x, offsets[SourceBackwards]);
                result.startY = HFMaxRange(rangeInB) - HFSum(bk.y, offsets[DestBackwards]);                
            }
            
            /* The middle snake has to actually be in the interior, otherwise we recurse forever */
            HFASSERT(result.startX < HFMaxRange(rangeInA) || result.startY < HFMaxRange(rangeInB));
            HFASSERT(result.startX > rangeInA.location || result.startY > rangeInB.location);

            return result;
        }
    }
    
    /* We don't expect to exit this loop unless we cancel */
    HFASSERT(*self->cancelRequested);
    return (struct Snake_t){};
}


BYTEARRAY_RELEASE_INLINE
struct Snake_t computeMiddleSnake(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInA, HFRange rangeInB) {
    
    struct Snake_t result;
    
    if (rangeInA.length < HEURISTIC_THRESHOLD && rangeInB.length < HEURISTIC_THRESHOLD) {
        /* Full algorithm */
        const unsigned char * const forwardsABuff = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location, ll2l(rangeInA.length), SourceForwards);
        const unsigned char * const forwardsBBuff = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location, ll2l(rangeInB.length), DestForwards);        
        result = computeActualMiddleSnake(self, cacheGroup, forwardsABuff, forwardsBBuff, (int)rangeInA.length, (int)rangeInB.length);
        
        /* Offset the result */
        result.startX = HFSum(result.startX, rangeInA.location);
        result.startY = HFSum(result.startY, rangeInB.location);
        
    } else if (rangeInA.length < HEURISTIC_THRESHOLD) {
        /* Heuristic only in dest */
        result = computePrettyGoodMiddleSnake(self, cacheGroup, rangeInA, rangeInB, NO /* heuristicInA */, YES /* heuristicInB */);
    } else if (rangeInB.length < HEURISTIC_THRESHOLD) {
        /* Heuristic only in source */
        result = computePrettyGoodMiddleSnake(self, cacheGroup, rangeInA, rangeInB, YES /* heuristicInA */, NO /* heuristicInB */);
    } else {
        /* Heuristic in both */
        result = computePrettyGoodMiddleSnake(self, cacheGroup, rangeInA, rangeInB, YES /* heuristicInA */, YES /* heuristicInB */);
    }
    
    if (! *self->cancelRequested) {
        HFASSERT(result.startX >= rangeInA.location);
        HFASSERT(result.startY >= rangeInB.location);
        HFASSERT(result.startX + result.middleSnakeLength <= HFMaxRange(rangeInA));
        HFASSERT(result.startY + result.middleSnakeLength <= HFMaxRange(rangeInB));
        
        /* The middle snake has to actually be in the interior, otherwise we recurse forever */
        HFASSERT(result.startX < HFMaxRange(rangeInA) || result.startY < HFMaxRange(rangeInB));
        HFASSERT(result.startX > rangeInA.location || result.startY > rangeInB.location);
    }
    
    return result;
}

static inline unsigned long long change_progress(HFByteArrayEditScript *self, unsigned long long remainingProgress, unsigned long long newRemainingProgress) {
    HFAtomicAdd64(remainingProgress - newRemainingProgress, self->currentProgress); //note: remainingProgress - newRemainingProgress may be negative
    return newRemainingProgress;
}

static void computeLongestCommonSubsequence(HFByteArrayEditScript *self, struct TLCacheGroup_t *restrict cacheGroup, OSQueueHead * restrict cacheQueueHead, dispatch_group_t dispatchGroup, HFRange rangeInA, HFRange rangeInB, uint32_t recursionDepth) {
    if (recursionDepth >= MAX_RECURSION_DEPTH) {
        /* Oops! */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        OSAtomicIncrement32(&self->concurrentProcesses);
#pragma clang diagnostic pop
        dispatch_group_async(dispatchGroup, dispatch_get_global_queue(0, 0), ^{
            /* We can't re-use cacheGroup because our caller may want to use it again.  So get a new group. */
            struct TLCacheGroup_t *newGroup = dequeueOrCreateCacheGroup(cacheQueueHead);
            
            /* Compute the LCS */
            computeLongestCommonSubsequence(self, newGroup, cacheQueueHead, dispatchGroup, rangeInA, rangeInB, 0);
            
            /* Put the group on the queue (either back or fresh) so others can use it */
            OSAtomicEnqueue(cacheQueueHead, newGroup, offsetof(struct TLCacheGroup_t, next));
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            OSAtomicDecrement32(&self->concurrentProcesses);
#pragma clang diagnostic pop
        });
        return;
    }
    
    HFByteArray *source = self->source;
    HFByteArray *destination = self->destination;
    
    /* At various points we check for cancellation requests */
    volatile const int * const cancelRequested = self->cancelRequested;
    if (*cancelRequested) return;
    
    /* Compute how much progress we are responsible for "consuming" */
    unsigned long long remainingProgress = rangeInA.length * rangeInB.length;
    
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInA, HFRangeMake(0, [source length])));
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInB, HFRangeMake(0, [destination length])));
    if (rangeInA.length == 0 || rangeInB.length == 0) return;
    
    
    /* Compute prefix snake */
    unsigned long long prefix = compute_forwards_snake_length(self, cacheGroup, rangeInA, rangeInB, NULL, ^(unsigned long long lengthMatched) {
        /* We've consumed progress equal to (A+B - x) * x, where x = alreadyRead */
        return (rangeInA.length + rangeInB.length - lengthMatched) * lengthMatched;
    });
    
    HFASSERT(prefix <= rangeInA.length && prefix <= rangeInB.length);    
    if (prefix > 0) {
        append_snake_to_instructions(self, rangeInA.location, rangeInB.location, prefix);
        rangeInA.location += prefix;
        rangeInA.length -= prefix;
        rangeInB.location += prefix;
        rangeInB.length -= prefix;
        
        /* Recompute the remaining progress. */
        remainingProgress = rangeInA.length * rangeInB.length;
        
        if (rangeInA.length == 0 || rangeInB.length == 0) return;
    }
    
    /* Compute suffix snake */
    unsigned long long suffix = compute_backwards_snake_length(self, cacheGroup, rangeInA, rangeInB, NULL, ^(unsigned long long lengthMatched) {
        /* We've consumed progress equal to (A+B - x) * x, where x = alreadyRead */
        return (rangeInA.length + rangeInB.length - lengthMatched) * lengthMatched;
    });
    HFASSERT(suffix <= rangeInA.length && suffix <= rangeInB.length);
    if (suffix > 0) {
        append_snake_to_instructions(self, HFMaxRange(rangeInA) - suffix, HFMaxRange(rangeInB) - suffix, suffix);
        rangeInA.length -= suffix;
        rangeInB.length -= suffix;
        
        /* Recompute the remaining progress. */
        remainingProgress = rangeInA.length * rangeInB.length;
        
        if (rangeInA.length == 0 || rangeInB.length == 0) return;
    }
    
    struct Snake_t middleSnake = computeMiddleSnake(self, cacheGroup, rangeInA, rangeInB);
    if (*cancelRequested) return;
    
    HFASSERT(middleSnake.middleSnakeLength >= 0);
    HFASSERT(middleSnake.startX >= rangeInA.location);
    HFASSERT(middleSnake.startY >= rangeInB.location);
    HFASSERT(HFSum(middleSnake.startX, middleSnake.middleSnakeLength) <= HFMaxRange(rangeInA));
    HFASSERT(HFSum(middleSnake.startY, middleSnake.middleSnakeLength) <= HFMaxRange(rangeInB));
    //    NSLog(@"Middle snake: %lu -> %lu, %lu -> %lu, max: %lu, dPath: %lu", middleSnake.startX, middleSnake.startX + middleSnake.middleSnakeLength, middleSnake.startY, middleSnake.startY + middleSnake.middleSnakeLength, middleSnake.maxSnakeLength, middleSnake.dPathLength);
    
    /* Subtract off how much progress the middle snake consumed.  Note that this may in rare cases make remainingProgress negative. */
#if ! NDEBUG
    if (middleSnake.progressConsumed > remainingProgress) {
        NSLog(@"Note: overestimated progress by %llu", middleSnake.progressConsumed - remainingProgress);
    }
#endif
    remainingProgress -= middleSnake.progressConsumed;
    
    if (! middleSnake.hasNonEmptySnake) {
        /* There were no non-empty snakes at all, so the entire range must be a diff */
        change_progress(self, remainingProgress, 0);
        return;
    }
    
    if (middleSnake.middleSnakeLength > 0) {
        /* Append this snake */
        append_snake_to_instructions(self, middleSnake.startX, middleSnake.startY, middleSnake.middleSnakeLength);
    }
    
    /* Compute the new prefix and suffix */
    HFRange prefixRangeA, prefixRangeB, suffixRangeA, suffixRangeB;
    HFRangeSplitAboutSubrange(rangeInA, HFRangeMake(middleSnake.startX, middleSnake.middleSnakeLength), &prefixRangeA, &suffixRangeA);
    HFRangeSplitAboutSubrange(rangeInB, HFRangeMake(middleSnake.startY, middleSnake.middleSnakeLength), &prefixRangeB, &suffixRangeB);
    
    /* Figure out how much we allocate to each of our subranges, and consume the remainder. */
    unsigned long long newRemainingProgress = prefixRangeA.length * prefixRangeB.length + suffixRangeA.length * suffixRangeB.length;
    
#if 0
    if (remainingProgress != newRemainingProgress) {
        NSLog(@"For ranges %@, %@, Additional add %lld (consumed %lld, expect %lld * %lld + %lld * %lld == %lld)", HFRangeToString(rangeInA), HFRangeToString(rangeInB), remainingProgress - newRemainingProgress, (long long)middleSnake.progressConsumed, prefixRangeA.length, prefixRangeB.length, suffixRangeA.length, suffixRangeB.length, prefixRangeA.length * prefixRangeB.length + suffixRangeA.length * suffixRangeB.length);
    }
#endif
    remainingProgress = change_progress(self, remainingProgress, newRemainingProgress);
    USE(remainingProgress);
    
    /* We check for *cancelRequested at the beginning of these functions, so we don't gain by checking for it again here */
    const unsigned long long minAsyncLength = 1024;
    BOOL asyncA = prefixRangeA.length > minAsyncLength || prefixRangeB.length > minAsyncLength;
    BOOL asyncB = suffixRangeA.length > minAsyncLength || suffixRangeB.length > minAsyncLength;
    
    /* Limit the amount of concurrency we do by checking concurrentProcesses */
    if ((asyncA && asyncB && self->concurrentProcesses < CONCURRENT_PROCESS_COUNT)) {
        
        /* Compute the suffix in the background */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        OSAtomicIncrement32(&self->concurrentProcesses);
#pragma clang diagnostic pop
        dispatch_group_async(dispatchGroup, dispatch_get_global_queue(0, 0), ^{
            
            /* Attempt to dequeue a group. If we can't, we'll have to make one. */
            struct TLCacheGroup_t *newGroup = dequeueOrCreateCacheGroup(cacheQueueHead);
            
            /* Compute the subsequence */
            computeLongestCommonSubsequence(self, newGroup, cacheQueueHead, dispatchGroup, suffixRangeA, suffixRangeB, 0);
            
            /* Put the group on the queue (either back or fresh) so others can use it */
            OSAtomicEnqueue(cacheQueueHead, newGroup, offsetof(struct TLCacheGroup_t, next));
            
            /* We're done */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            OSAtomicDecrement32(&self->concurrentProcesses);
#pragma clang diagnostic pop
        });
        
        /* Compute the prefix now. We don't return our group to the queue - our caller does that.  */
        computeLongestCommonSubsequence(self, cacheGroup, cacheQueueHead, dispatchGroup, prefixRangeA, prefixRangeB, recursionDepth + 1);
    } else {
        
        if (prefixRangeA.length > 0 || prefixRangeB.length > 0) {
            computeLongestCommonSubsequence(self, cacheGroup, cacheQueueHead, dispatchGroup, prefixRangeA, prefixRangeB, recursionDepth + 1);
        }
        if (suffixRangeA.length > 0 || suffixRangeB.length > 0) {
            /* Tail call, so don't increase recursion depth. */
            computeLongestCommonSubsequence(self, cacheGroup, cacheQueueHead, dispatchGroup, suffixRangeA, suffixRangeB, recursionDepth + 1);
        }
    }
}

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
    
    /* Make a dispatch queue for instructions */
    HFASSERT(insnQueue == NULL);
    insnCount = insnCapacity = 0;
    insnQueue = dispatch_queue_create("HFByteArrayEditScript Instruction Queue", NULL);
    
    /* Make a dispatch group for concurrent processing */
    dispatch_group_t dispatchGroup = dispatch_group_create();
    
    /* Create one cache */
    struct TLCacheGroup_t cacheGroup;
    initializeCacheGroup(&cacheGroup);
    
    /* Create our queue for additional caches */
    OSQueueHead queueHead = OS_ATOMIC_QUEUE_INIT;
    
    /* Make an initial "everything replaces everything" instruction */
    insnCapacity = 128;
    if(insns) free(insns);
    insns = malloc(insnCapacity * sizeof(*insns));
    insns[0].src = HFRangeMake(0, sourceLength);
    insns[0].dst = HFRangeMake(0, destLength);
    insnCount = 1;
    
    /* Compute the longest common subsequence. */
    computeLongestCommonSubsequence(self, &cacheGroup, &queueHead, dispatchGroup, HFRangeMake(0, sourceLength), HFRangeMake(0, destLength), 0);
    
    /* Wait until we're done */
    dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
    dispatchGroup = NULL;
    
    /* Make sure our insnQueue is done by submitting a no-op to it, then clear it */
    dispatch_sync(insnQueue, ^{});
    insnQueue = NULL;
    
    if (! *cancelRequested) {
#if ! NDEBUG
        /* Validate the data */
        HFASSERT(validate_instructions(insns, insnCount));
#endif
        
        /* We succeed unless we were cancelled */
        success = YES;
    }
    
    /* Free our cache */
    freeCacheGroup(&cacheGroup);
    
    /* Dequeue and free all the other caches, which were allocated with malloc */
    struct TLCacheGroup_t *additionalCache;
    while ((additionalCache = OSAtomicDequeue(&queueHead, offsetof(struct TLCacheGroup_t, next)))) {
        freeCacheGroup(additionalCache);
        free(additionalCache);
    }
    
    //if (success) [self _dumpDebug];
    
    return success;
}

- (BOOL)computeDifferenceViaDirectComparison:(BOOL)skipOneByteMatches {
    /* We succeed unless we are cancelled */
    BOOL success = NO;
    
    /* Make a dispatch queue for instructions */
    HFASSERT(insnQueue == NULL);
    insnCount = insnCapacity = 0;
    
    insnCapacity = 128;
    if(insns) free(insns);
    insns = malloc(insnCapacity * sizeof(*insns));
    insnCount = 0;

    
    const size_t bufSize = 16384;
    
    uint8_t srcBuf[bufSize], dstBuf[bufSize];
    
    for (size_t i = 0; !*cancelRequested && i < MIN(sourceLength, destLength); i += bufSize) {
        *self->currentProgress = i * i;
        // Read block
        size_t len = MIN(bufSize, MIN(sourceLength - i, destLength - i));
        [self->source copyBytes:srcBuf range:HFRangeMake(i, len)];
        [self->destination copyBytes:dstBuf range:HFRangeMake(i, len)];

        // Compare this block fully
        size_t j = 0;
        while (j < len) {
            while (j < len && srcBuf[j] == dstBuf[j])
                j++;
            
            size_t difference_begin = i + j;
            while ((j < len && srcBuf[j] != dstBuf[j]) || (skipOneByteMatches && (j + 1 < len && srcBuf[j + 1] != dstBuf[j + 1])))
                j++;
            size_t difference_end = i + j;
            
            if (difference_end != difference_begin) {
                if (insnCount != 0 && (insns[insnCount - 1].src.location + insns[insnCount - 1].src.length == difference_begin ||
                                       (skipOneByteMatches && insns[insnCount - 1].src.location + insns[insnCount - 1].src.length + 1 == difference_begin))) {
                    // join with prev
                    insns[insnCount - 1].src.length = insns[insnCount - 1].dst.length = difference_end - insns[insnCount - 1].src.location;
                }
                else {
                    // new instruction
                    insns[insnCount].src = insns[insnCount].dst = HFRangeMake(difference_begin, difference_end - difference_begin);
                    insnCount++;
                    if (insnCount == insnCapacity) {
                        insnCapacity += 128;
                        insns = realloc(insns, insnCapacity * sizeof(*insns));
                    }
                }
            }
        }
    }
    
    if (sourceLength > destLength) {
        insns[insnCount].src = HFRangeMake(destLength, sourceLength - destLength);
        insns[insnCount].dst = HFRangeMake(destLength, 0);
        insnCount++;
    }
    else if (destLength > sourceLength) {
        insns[insnCount].src = HFRangeMake(sourceLength, 0);
        insns[insnCount].dst = HFRangeMake(sourceLength, destLength - sourceLength);
        insnCount++;
    }
    *self->currentProgress = sourceLength * destLength;

    
    if (! *cancelRequested) {
#if ! NDEBUG
        /* Validate the data */
        HFASSERT(validate_instructions(insns, insnCount));
#endif
        
        /* We succeed unless we were cancelled */
        success = YES;
    }
    
    return success;
}


- (instancetype)initWithSource:(HFByteArray *)src toDestination:(HFByteArray *)dst { 
    self = [super init];
    NSParameterAssert(src != nil);
    NSParameterAssert(dst != nil);
    source = src;
    destination = dst;
    sourceLength = [source length];
    destLength = [destination length];
    return self;
}


/* Theory of progress reporting: at each step, we attempt to compute the remaining worst case (in time) and show that as the progress.  The Myers diff worst case for diffing two arrays of length M and N is M*N.  Initially we "allocate" that much progress.  In the  linear-space divide-and-conquer variation, we compute the middle snake and then recursively apply the algorithm to two "halves" of the data.  At that point, we "give" some of our allocated progress to the recursive calls, and "consume" the rest by incrementing the progress count. 
 
 Our implementation of the Longest Common Subsequence traverses any leading/trailing snakes.  We can be certain that these snakes are part of the LCS, so they can contribute to our progress.  Imagine that the arrays are of length M and N, for allocated progress M*N.  If we traverse a leading/trailing snake of length x, then the new arrays are of length M-x and N-x, so the new progress is (M-x)*(N-x).  Since we initially allocated M*N, this means we "progressed" by M*N - (M-x)*(N-x), which reduces to (M+N-x)*x.
 */
- (BOOL)computeDifferencesTrackingProgress:(HFProgressTracker *)tracker
                               onlyReplace:(BOOL)onlyReplace
                        skipOneByteMatches:(BOOL)skipOneByteMatches {
    const int localCancelRequested = 0;
    unsigned long long localCurrentProgress = 0;
    
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    
    /* Remember our progress tracker (if any) */
    if (tracker) {
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
    
    BOOL result = onlyReplace ?
        [self computeDifferenceViaDirectComparison:skipOneByteMatches] :
        [self computeDifferenceViaMiddleSnakes];

    cancelRequested = NULL;
    currentProgress = NULL;
    
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    fprintf(stderr, "Diffs computed in %.2f seconds\n", end - start);
    return result;
}

- (instancetype)initWithDifferenceFromSource:(HFByteArray *)src
                               toDestination:(HFByteArray *)dst
                                 onlyReplace:(BOOL)onlyReplace
                          skipOneByteMatches:(BOOL)skipOneByteMatches
                            trackingProgress:(HFProgressTracker *)progressTracker {
    self = [self initWithSource:src toDestination:dst];
    BOOL success = [self computeDifferencesTrackingProgress:progressTracker
                                                onlyReplace:onlyReplace
                                         skipOneByteMatches:skipOneByteMatches];
    if (! success) {
        /* Cancelled */
        self = nil;
    }    
    return self;
}

- (void)dealloc {
    free(insns);
    insns = NULL;
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
