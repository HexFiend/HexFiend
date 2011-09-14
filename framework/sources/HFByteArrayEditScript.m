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
#import <HexFiend/HFByteArray_Internal.h>
#include <malloc/malloc.h>
#include <libkern/OSAtomic.h>
#include <pthread.h>
#include <stdbool.h>

#define READ_AMOUNT (1024 * 32)
#define CONCURRENT_PROCESS_COUNT 16
#define MAX_RECURSION_DEPTH 64

#if NDEBUG
#define BYTEARRAY_RELEASE_INLINE __attribute__((always_inline))
#else
#define BYTEARRAY_RELEASE_INLINE __attribute__((noinline))
#endif

/* indexes into a caches */
enum {
    SourceForwards,
    SourceBackwards,
    DestForwards,
    DestBackwards,
    
    NUM_CACHES
};

#define HEURISTIC_THRESHOLD 128 * 64
#define SQUARE_CACHE_SIZE 128 * 64

// This is the type of an abstract index in some local LCS problem
typedef int32_t LocalIndex_t;

//GraphIndex_t must be big enough to hold a value in the range [0, HEURISTIC_THRESHOLD)
typedef int32_t GraphIndex_t;

/* GrowableArray_t allows indexing in the range [-length, length], and preserves data around its center when reallocated. */
struct GrowableArray_t {
    size_t length;
    GraphIndex_t * __restrict__ ptr;
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
    //GraphIndex_t *newPtr = check_malloc(bufferLength);
    GraphIndex_t *newPtr = (GraphIndex_t *)valloc(bufferLength);
    
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


struct Snake_t {
    unsigned long long startX;
    unsigned long long startY;
    unsigned long long middleSnakeLength;
    unsigned long long progressConsumed;
    bool hasNonEmptySnake;
};


static BOOL can_merge_instruction(const struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right) {
    /* We can merge these if one (or both) of the dest ranges are empty, or if they are abutting.  Note that if a destination is empty, we have to copy the location from the other one, because we like to give nonsense locations (-1) to zero length ranges.  src never has a nonsense location. */
    //return HFMaxRange(left->src) == right->src.location && (left->dst.length == 0 || right->dst.length == 0 || HFMaxRange(left->dst) == right->dst.location);
    
    if (HFMaxRange(left->src) == right->src.location) {
        return left->dst.length == 0 || right->dst.length == 0 || HFMaxRange(left->dst) == right->dst.location;
    } else if (HFMaxRange(right->src) == left->src.location) {
        return left->dst.length == 0 || right->dst.length == 0 || HFMaxRange(right->dst) == left->dst.location;
    } else {
        return NO;
    }
}

static BOOL merge_instruction(struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right) {
    BOOL result = NO;
    if (can_merge_instruction(left, right)) {
        left->src.length = HFSum(left->src.length, right->src.length);
        left->src.location = MIN(left->src.location, right->src.location);
        
        // We give nonsense (-1) locations to empty destinations, so guard against that
        unsigned long long newDest = ULLONG_MAX;
        if (left->dst.length > 0) newDest = MIN(newDest, left->dst.location);
        if (right->dst.length > 0) newDest = MIN(newDest, right->dst.location);

        left->dst.location = newDest;
        left->dst.length = HFSum(left->dst.length, right->dst.length);
        result = YES;
    }
    return result;
}

/* SSE optimized versions of difference matching */
#define EDITSCRIPT_USE_SSE 1
#if EDITSCRIPT_USE_SSE && (defined(__i386__) || defined(__x86_64__))
#include <xmmintrin.h>

/* match_forwards and match_backwards are assumed to be fast enough and to operate on small enough buffers that they don't have to check for cancellation. */
BYTEARRAY_RELEASE_INLINE
static LocalIndex_t match_forwards(const unsigned char * restrict a, const unsigned char * restrict b, LocalIndex_t length) {
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

/* I haven't written this guy yet */
BYTEARRAY_RELEASE_INLINE
static LocalIndex_t match_backwards(const unsigned char * restrict a, const unsigned char * restrict b, LocalIndex_t length) {
    LocalIndex_t i = length;
    while (i > 0 && a[i-1] == b[i-1]) {
        i--;
    }
    return length - i;
}

#else

/* Non-optimized reference versions of the difference matching */
BYTEARRAY_RELEASE_INLINE
static LocalIndex_t match_forwards(const unsigned char * restrict a, const unsigned char * restrict b, LocalIndex_t length) {
    LocalIndex_t i = 0;
    while (i < length && a[i] == b[i]) {
        i++;
    }
    return i;
}

BYTEARRAY_RELEASE_INLINE
static LocalIndex_t match_backwards(const unsigned char * restrict a, const unsigned char * restrict b, LocalIndex_t length) {
    LocalIndex_t i = length;
    while (i > 0 && a[i-1] == b[i-1]) {
        i--;
    }
    return length - i;
}

#endif

@implementation HFByteArrayEditScript

// returns -1, 0, or 1 as a is less than, equal to, or greater than b
static inline int compare_ull(unsigned long long a, unsigned long long b) {
    return (a > b) - (a < b);
}

static inline int compare_instructions(struct HFEditInstruction_t left, struct HFEditInstruction_t right) {
    int result;
    if ((result = compare_ull(left.src.location, right.src.location))) return result;
    if ((result = compare_ull(left.dst.location, right.dst.location))) return result;
    if ((result = compare_ull(left.src.length, right.src.length))) return result;
    if ((result = compare_ull(right.dst.length, right.dst.length))) return result;
    return 0;
}


static void append_instruction(HFByteArrayEditScript *self, HFRange rangeInA, HFRange rangeInB) {
    if (rangeInA.length || rangeInB.length) {
        
        /* Make the new instruction */
        const struct HFEditInstruction_t newInsn = {.src = rangeInA, .dst = rangeInB};
        void * const selfP = self; //no need to retain self in the block
        
        dispatch_async(self->insnQueue, ^{
            HFByteArrayEditScript * const self = selfP;
            /* The size of an instruction for some reason */
            const size_t insnSize = sizeof newInsn;

            /* Figure out the insertion index, that is, the first index in which insns[idx].src.location > newInsn.src. */
            const struct HFEditInstruction_t * const insnsPtr = self->insns;
            size_t low = 0, high = self->insnCount;
            while (low < high) {
                size_t mid = low + (high - low)/2;
                int direction = compare_instructions(insnsPtr[mid], newInsn); //-1, 0, or 1
                if (direction <= 0) {
                    // too low
                    low = mid + 1;
                } else {
                    // too high
                    high = mid;
                }
            }
            
            /* We insert at the 'low' index. */
            size_t insertionIndex = low;
            HFASSERT(insertionIndex <= self->insnCount);
            

            BOOL done = NO;
            
            /* Maybe we can merge left */
            if (insertionIndex > 0 && merge_instruction(&self->insns[insertionIndex-1], &newInsn)) {
                /* We merged left (into insertionIndex-1). We may also be able to merge right - try that. */
                if (insertionIndex < self->insnCount && merge_instruction(&self->insns[insertionIndex - 1], &self->insns[insertionIndex])) {
                    /* We merged right as well. Move everything past that left by 1. We just lost instruction insns[insertionIndex]. */
                    memmove(&self->insns[insertionIndex], &self->insns[insertionIndex + 1], (self->insnCount - insertionIndex - 1) * sizeof(struct HFEditInstruction_t));
                    self->insnCount--;
                }
                done = YES;
            }
            
            /* Try merging right */
            if (! done) {
                if (insertionIndex < self->insnCount) {
                    struct HFEditInstruction_t tmp = newInsn;
                    if (merge_instruction(&tmp, &self->insns[insertionIndex])) {
                        /* We merged right */
                        self->insns[insertionIndex] = tmp;
                        done = YES;
                    }
                }
            }
            
            if (! done) {
                /* We have to insert. Ensure we have enough space */
                HFASSERT(self->insnCount <= self->insnCapacity);
                if (self->insnCount == self->insnCapacity) {
                    size_t newBufferByteCount = malloc_good_size((self->insnCount + 1) * insnSize);
                    self->insns = NSReallocateCollectable(self->insns, newBufferByteCount, 0); //not scanned, not collectable
                    self->insnCapacity = newBufferByteCount / insnSize;
                }
                HFASSERT(self->insnCount < self->insnCapacity);
                
                /* Move everything to its right over by one, then insert */
                size_t numToMove = self->insnCount - insertionIndex;
                memmove(self->insns + insertionIndex + 1, self->insns + insertionIndex, numToMove * insnSize);
                self->insns[insertionIndex] = newInsn;
                self->insnCount++;
            }
            
#if 0
#if ! NDEBUG
            /* This validation gets pretty slow */
            if (! *self->cancelRequested) {
                /* Verify that everything is sorted in ascending order and not mergeable */
                size_t i;
                for (i=1; i < self->insnCount; i++) {
                    HFASSERT(compare_instructions(self->insns[i], self->insns[i-1]) > 0);
                    HFASSERT(! can_merge_instruction(&self->insns[i-1], &self->insns[i]));
                }
            }
#endif
#endif
        });
    }
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

BYTEARRAY_RELEASE_INLINE
static unsigned long long compute_forwards_snake_length(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFByteArray *a, unsigned long long a_offset, unsigned long long a_len, HFByteArray *b, unsigned long long b_offset, unsigned long long b_len, volatile int64_t * restrict outProgress, const volatile int *cancelRequested) {
    HFASSERT(a_len > 0 && b_len > 0);
    HFASSERT(a_len + a_offset <= self->sourceLength);
    HFASSERT(b_len + b_offset <= self->destLength);
    unsigned long long alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    unsigned long long progressConsumed = 0;
    while (remainingToRead > 0) {
        LocalIndex_t amountToRead = MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = get_cached_bytes(self, cacheGroup, a, self->sourceLength, a_offset + alreadyRead, amountToRead, SourceForwards);
        const unsigned char *b_buff = get_cached_bytes(self, cacheGroup, b, self->destLength, b_offset + alreadyRead, amountToRead, DestForwards);
        LocalIndex_t matchLen = match_forwards(a_buff, b_buff, amountToRead);
        alreadyRead += matchLen;
        remainingToRead -= matchLen;
        
        /* We've consumed progress equal to (A+B - x) * x, where x = alreadyRead */
        unsigned long long newProgressConsumed = (a_len + b_len - alreadyRead) * alreadyRead;
        HFAtomicAdd64(newProgressConsumed - progressConsumed, outProgress);
        progressConsumed = newProgressConsumed;
        
        if (matchLen < amountToRead) break;
        if (*cancelRequested) break;
    }
    return alreadyRead;
}

/* returns the backwards snake of length no more than MIN(a_len, b_len), starting at a_offset, b_offset (exclusive) */
BYTEARRAY_RELEASE_INLINE
static unsigned long long compute_backwards_snake_length(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFByteArray *a, unsigned long long a_offset, unsigned long long a_len, HFByteArray *b, unsigned long long b_offset, unsigned long long b_len, volatile int64_t * restrict outProgress, const volatile int *cancelRequested) {
    HFASSERT(a_offset <= self->sourceLength);
    HFASSERT(b_offset <= self->destLength);
    HFASSERT(a_len <= a_offset);
    HFASSERT(b_len <= b_offset);
    unsigned long long alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    unsigned long long progressConsumed = 0;
    while (remainingToRead > 0) {
        LocalIndex_t amountToRead = MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = get_cached_bytes(self, cacheGroup, a, self->sourceLength, a_offset - alreadyRead - amountToRead, amountToRead, SourceBackwards);
        const unsigned char *b_buff = get_cached_bytes(self, cacheGroup, b, self->destLength, b_offset - alreadyRead - amountToRead, amountToRead, DestBackwards);
        LocalIndex_t matchLen = match_backwards(a_buff, b_buff, amountToRead);
        remainingToRead -= matchLen;
        alreadyRead += matchLen;
        
        /* We've consumed progress equal to (A+B - x) * x, where x = alreadyRead */
        unsigned long long newProgressConsumed = (a_len + b_len - alreadyRead) * alreadyRead;
        HFAtomicAdd64(newProgressConsumed - progressConsumed, outProgress);
        progressConsumed = newProgressConsumed;	
        
        if (matchLen < amountToRead) break; //found some non-matching byte
        if (*cancelRequested) break;
    }
    return alreadyRead;
}

BYTEARRAY_RELEASE_INLINE
static BOOL prettyGoodSnakeTraversal(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL forwards, LocalIndex_t k, LocalIndex_t D, GraphIndex_t *restrict vector, LocalIndex_t aLen, LocalIndex_t bLen, struct Snake_t * restrict result) {
    USE(self);
    /* It would be nice if this could be combined with computeMiddleSnakeTraversal */
    
    LocalIndex_t x, y;
    
    /* k-1 represents considering a movement from the left, while k + 1 represents considering a movement from above */
    if (k == -D || (k != D && vector[k-1] < vector[k+1])) {
        x = vector[k + 1]; // down
    } else {
        x = vector[k - 1] + 1; // right
    }
    y = x - k;

    // In this variant of the algorithm we require that we always be inside the rectangle
    HFASSERT(x >= 0);
    HFASSERT(y >= 0);
    HFASSERT(x < aLen);
    HFASSERT(y < bLen);
    
    /* Find the end of the furthest reaching forward D-path in diagonal k */
    LocalIndex_t snakeLength = 0;

    /* The intent is that "forwards" is a known constant, so with the forced inlining above, this branch can be evaluated at compile time */
    LocalIndex_t maxSnakeLength = MIN(aLen - x - 1, bLen - y - 1);
    if (forwards) {
        snakeLength = match_forwards(aBuff + x, bBuff + y, maxSnakeLength);
    } else {
        snakeLength = match_backwards(aBuff + aLen - x - maxSnakeLength, bBuff + bLen - y - maxSnakeLength, maxSnakeLength);
    }
    x += snakeLength;
    y += snakeLength;
    vector[k] = x;
    
    // See if we can beat the best snake so far
    BOOL weAreWinning = NO;
    long resultScore = (long)(result->startX + result->startY);
    if (x + y < resultScore) {
        weAreWinning = NO;
    }
    else if (x + y > resultScore) {
        weAreWinning = YES;
    } else {
        /* x+y == result->x + result->y.  Bias towards equal x and y, that is, prefer center snakes. */
        weAreWinning = (labs(x-y) <= llabs(result->startX - result->startY));
    }
    
    if (weAreWinning) {
        result->startX = x;
        result->startY = y;
    }
    
    /* Return YES if we reached the edge */
    return snakeLength == maxSnakeLength;
}

BYTEARRAY_RELEASE_INLINE
static BOOL prettyGoodSnakeTraversal2(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL forwards, LocalIndex_t k, LocalIndex_t minK, LocalIndex_t maxK, GraphIndex_t *restrict vector, LocalIndex_t aLen, LocalIndex_t bLen) {
    USE(self);
    /* It would be nice if this could be combined with computeMiddleSnakeTraversal */
    
    LocalIndex_t x, y;

    if (! forwards && k == -8123) {
        NSLog(@"Wut");
    }
    
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
    
    /* Compute the snake length. We may have exceeded either edge. If so, backtrack into the rectangle. */
    LocalIndex_t maxSnakeLength = MIN(aLen - x, bLen - y);
    if (x > aLen) {
        y -= (x - aLen);
        x = aLen;
        maxSnakeLength = 0;
    }
    if (y > bLen) {
        x -= (y - bLen);
        y = bLen;
        maxSnakeLength = 0;
    }

    HFASSERT(x <= aLen);
    HFASSERT(y <= bLen);
    
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
    
    /* Return YES if we reached the edge in the longer dimension. If the dimensions are equal, return YES if we reached the edge in any dimension. */
    if (snakeLength != maxSnakeLength) {
        /* We could have gone further - must not have reached the edge */
        return NO;
    } else {
        /* Return YES only if we reached the edge in the longer dimension. If our dimensions are equal, allow us to have reached the edge in any dimension. */
        LocalIndex_t max = MAX(aLen, bLen);
        return x == max || y == max;
    }
}


BYTEARRAY_RELEASE_INLINE
static LocalIndex_t computeMiddleSnakeTraversal(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL forwards, LocalIndex_t k, LocalIndex_t D, GraphIndex_t *restrict vector, LocalIndex_t aLen, LocalIndex_t bLen, struct Snake_t * restrict outSnake) {
    USE(self);
    GraphIndex_t x, y;
    
    // We like to use GraphIndex_t instead of long long here, so make sure k fits in one
    HFASSERT(k == (GraphIndex_t)k);
    
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
static BOOL computeMiddleSnakeTraversal_OverlapCheck(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL forwards, LocalIndex_t k, LocalIndex_t D, GraphIndex_t *restrict vector, LocalIndex_t aLen, LocalIndex_t bLen, const GraphIndex_t *restrict overlapVector, struct Snake_t *restrict result) {
    
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
static LocalIndex_t ull_to_index(unsigned long long x) {
    LocalIndex_t result = (LocalIndex_t)x;
    HFASSERT((unsigned long long)result == x);
    return result;
}

BYTEARRAY_RELEASE_INLINE
static struct Snake_t computeActualMiddleSnake(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, const unsigned char * restrict directABuff, const unsigned char * restrict directBBuff, LocalIndex_t aLen, LocalIndex_t bLen) {
    
    /* This function wants to "consume" progress equal to aLen * bLen. */
    HFASSERT(aLen > 0);
    HFASSERT(bLen > 0);
    const unsigned long long progressAllocated = HFProductULL(aLen, bLen);
    
    //maxD = ceil((M + N) / 2)
    const LocalIndex_t maxD = (aLen + bLen + 1) / 2;
    
    /* Adding delta to k in the forwards direction gives you k in the backwards direction */
    const LocalIndex_t delta = bLen - aLen;
    const BOOL oddDelta = (delta & 1); 
    
    GraphIndex_t *restrict forwardsVector = cacheGroup->forwardsArray.ptr;
    GraphIndex_t *restrict backwardsVector = cacheGroup->backwardsArray.ptr;
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
        
        /* Unfortunately clang won't unroll this loop.  I don't think it's correct any more. */
#if 0
        for (int direction = 1; direction >= 0; direction--) {
            const BOOL forwards = (direction == 1);
            
            /* we check for overlap on the forwards path if oddDelta is YES and direction is forwards, or oddDelta is NO and direction is backwards */
            BOOL checkForOverlap = (direction == oddDelta);
            
            if (checkForOverlap) {
                /* Check for overlap, but only when the diagonal is within the right range */
                for (LocalIndex_t k = -D; k <= D; k += 2) {
                    if (*cancelRequested) break;
                    
                    LocalIndex_t flippedK = -(k + delta);
                    /* If we're forwards, the reverse path has only had time to explore diagonals -(D-1) through (D-1).  If we're backwards, it's had time to explore diagonals -D through D. */
                    const LocalIndex_t reverseExploredDiagonal = D - direction;
                    if (flippedK >= -reverseExploredDiagonal && flippedK <= reverseExploredDiagonal) {
                        if (computeMiddleSnakeTraversal_OverlapCheck(self, directABuff, directBBuff, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, (forwards ? backwardsVector : forwardsVector), &result)) {
                            return result;
                        }			    
                    } else {
                        computeMiddleSnakeTraversal(self, directABuff, directBBuff, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, &result);
                    }
                }
            } else {
                /* Don't check for overlap */
                for (LocalIndex_t k = -D; k <= D; k += 2) {
                    if (*cancelRequested) break;
                    
                    computeMiddleSnakeTraversal(self, directABuff, directBBuff, forwards, k, D, (forwards ? forwardsVector : backwardsVector), aLen, bLen, &result);
                }
            }
        }
#else
        /* Manually unrolled variant */
        
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
#endif
    }
    
    /* We don't expect to exit this loop unless we cancel */
    HFASSERT(*self->cancelRequested);
    return result;
}

BYTEARRAY_RELEASE_INLINE
static struct Snake_t computePrettyGoodSnake(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, const unsigned char * restrict directABuff, const unsigned char * restrict directBBuff, LocalIndex_t aLen, LocalIndex_t bLen, unsigned long long fullLengthA, unsigned long long fullLengthB, BOOL forwards) {
    
    /* Our result */
    struct Snake_t result;
    result.hasNonEmptySnake = true; //we don't support this, so just return true
    result.progressConsumed = 0;
    result.middleSnakeLength = 0; //we're always going to return a 0 length snake

    
    /* We mishandle one-length arrays, so treat those specially. */
    HFASSERT(aLen >= 1 && bLen >= 1);
    if (aLen == 1 || bLen == 1) {
        if (aLen == 1) {
            BOOL found = !! HFFastMemchr(directBBuff, *directABuff, bLen);
            result.startX = found ? 1 : 0;
            result.startY = bLen;
        } else {
            BOOL found = !! HFFastMemchr(directABuff, *directBBuff, aLen);
            result.startY = found ? 1 : 0;
            result.startX = aLen;            
        }
        result.startX = aLen/2;
        result.startY = bLen/2;
        return result;
    }
    
    /* Run one-direction Myers diff until we exit the rectangle.  The diagonal that's made the most progress by the time any exit is the split point. */
    unsigned long long allocatedProgress = HFProductULL(fullLengthA, fullLengthB);
    
    /* We stop as soon as we reach an edge, so our max D is the smaller of our two edge lengths */
    const LocalIndex_t maxD = MIN(aLen, bLen);
    
    /* Make our vector big enough. Just do this at the beginning since this function is called with a size not exceeding HEURISTIC_THRESHOLD */
    GrowableArray_reallocate((forwards ? &cacheGroup->forwardsArray : &cacheGroup->backwardsArray), maxD, maxD);

    GraphIndex_t * const restrict vector = forwards ? cacheGroup->forwardsArray.ptr : cacheGroup->backwardsArray.ptr;
    
    /* Initialize the vector */
    vector[0] = 0;
        

    // we use 0 based indexing.  Our caller will add in rangeInA.location and rangeInB.location before returning.
    result.startX = 0;
    result.startY = 0;
    
    volatile const int * const cancelRequested = self->cancelRequested;
    
    LocalIndex_t D;
    for (D=1; D <= maxD; D++) {
        //if (0 == (D % 256)) printf("Heuristic %ld / %ld\n", D, maxD);
        
        /* Report progress. */
        HFASSERT(result.startX <= (unsigned long long)aLen);
        HFASSERT(result.startY <= (unsigned long long)bLen);
        unsigned long long upperLeftRectSize = result.startX * result.startY;
        unsigned long long lowerRightRectSize = (fullLengthA - result.startX) * (fullLengthB - result.startY);
        unsigned long long newProgress = allocatedProgress - (upperLeftRectSize + lowerRightRectSize);
        /* We logically go backwards if we discover a longer diagonal that happens to be more centered.  Ratchet our progress so it never goes backwards. */
        if (newProgress > result.progressConsumed) {
            HFAtomicAdd64(newProgress - result.progressConsumed, self->currentProgress);
            result.progressConsumed = newProgress;
        }
        
        /* Check for cancellation */
        if (*cancelRequested) break;
        
        BOOL reachedLimit = NO;
        for (LocalIndex_t k = -D; k <= D; k += 2) {
            if (*cancelRequested) break;            
            if (prettyGoodSnakeTraversal(self, directABuff, directBBuff, forwards, k, D, vector, aLen, bLen, &result)) {
                reachedLimit = YES;
            }
        }
        
        if (reachedLimit) return result;
    }
    
    /* We don't expect to exit this loop unless we cancel */
    HFASSERT(*self->cancelRequested);
    
    // Since we cancelled, the result is irrelevant
    return result;
}

BYTEARRAY_RELEASE_INLINE
static struct Snake_t computePrettyGoodSnake2(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, const unsigned char * restrict directABuff, const unsigned char * restrict directBBuff, LocalIndex_t aLen, LocalIndex_t bLen, unsigned long long fullLengthA, unsigned long long fullLengthB, double desiredBias, BOOL forwards) {
    
    /* We should not be called with a size exceeding HEURISTIC_THRESHOLD */
    HFASSERT(aLen <= HEURISTIC_THRESHOLD);
    HFASSERT(bLen <= HEURISTIC_THRESHOLD);
    
    /* Our result */
    struct Snake_t result;
    result.hasNonEmptySnake = true; //we don't support this, so just return true
    result.progressConsumed = 0;
    result.middleSnakeLength = 0; //we're always going to return a 0 length snake
    
    /* Run one-direction Myers diff until we exit the rectangle.  The diagonal that's made the most progress by the time any exit is the split point. */
    unsigned long long allocatedProgress = HFProductULL(fullLengthA, fullLengthB);
    
    /* The max D is the max of the two lengths */
    const LocalIndex_t maxD = MAX(aLen, bLen);
    
    /* Make our vector big enough. Just do this at the beginning since this function is called with a size not exceeding HEURISTIC_THRESHOLD */
    GrowableArray_reallocate((forwards ? &cacheGroup->forwardsArray : &cacheGroup->backwardsArray), maxD, maxD);
    
    GraphIndex_t * const restrict vector = forwards ? cacheGroup->forwardsArray.ptr : cacheGroup->backwardsArray.ptr;
    
    /* Initialize the vector */
    vector[0] = 0;
    
    // we use 0 based indexing.  Our caller will add in rangeInA.location and rangeInB.location before returning.
    result.startX = 0;
    result.startY = 0;
    
    volatile const int * const cancelRequested = self->cancelRequested;
    
    LocalIndex_t D;
    for (D=1; D <= maxD; D++) {
        //if (0 == (D % 256)) printf("Heuristic %ld / %ld\n", D, maxD);
        
        /* Report progress. */
        HFASSERT(result.startX <= (unsigned long long)aLen);
        HFASSERT(result.startY <= (unsigned long long)bLen);
        unsigned long long upperLeftRectSize = result.startX * result.startY;
        unsigned long long lowerRightRectSize = (fullLengthA - result.startX) * (fullLengthB - result.startY);
        unsigned long long newProgress = allocatedProgress - (upperLeftRectSize + lowerRightRectSize);
        /* We logically go backwards if we discover a longer diagonal that happens to be more centered.  Ratchet our progress so it never goes backwards. */
        if (newProgress > result.progressConsumed) {
            HFAtomicAdd64(newProgress - result.progressConsumed, self->currentProgress);
            result.progressConsumed = newProgress;
        }
        
        /* Check for cancellation */
        if (*cancelRequested) break;
        
        
        LocalIndex_t startK = -D, endK = D;
        LocalIndex_t minK = -D, maxK = D;
        if (-bLen > startK) {
            
            /* The most negative diagonal we've explored is -bLen */
            minK = -bLen;
            
            /* We're going to skip empty space in the vertical direction (e.g. below our square). Keep same parity as D, rounding towards zero. E.g. if D is even, then -5 -> -4, -4 -> -4; if D is odd, then -6 -> -5, -5 -> -5 .*/
            int parityChange = (D ^ bLen) & 1; //1 if the parities are different
            startK = -bLen + parityChange;
        }
        
        
        if (aLen < endK) {
            /* The most positive diagonal is aLen */
            maxK = aLen;
            
            /* We're going to skip empty space in the horizontal direction (e.g. to the right of our square). Keep same parity as D, rounding towards zero. */
            int parityChange = (D ^ aLen) & 1; //1 if the parities are different
            endK = aLen - parityChange;
        }
        HFASSERT(startK < endK);

        
        BOOL reachedLimit = NO;
        for (LocalIndex_t k = startK; k <= endK; k += 2) {
            if (*cancelRequested) break;            
            if (prettyGoodSnakeTraversal2(self, directABuff, directBBuff, forwards, k, minK, maxK, vector, aLen, bLen)) {
                reachedLimit = YES;
            }
        }
        
        if (reachedLimit) {
            /* See which diagonal did best */
            LocalIndex_t bestX = 0, bestY = 0;
            double bestBiasDifference = 0;
            
            for (LocalIndex_t k = startK; k <= endK; k += 2) {
                LocalIndex_t x = vector[k];
                LocalIndex_t y = x - k;
                
                /* See if this one is better */
                double biasDifference = fabs((double)x / (double)y - desiredBias);
                if (x + y > bestX + bestY || (x + y == bestX + bestY && biasDifference < bestBiasDifference)) {
                    bestX = x;
                    bestY = y;
                    bestBiasDifference = biasDifference;
                }
            }
            
            /* And we're done */
            result.startX = bestX;
            result.startY = bestY;
            return result;
        }
    }
    
    /* We don't expect to exit this loop unless we cancel */
    HFASSERT(*self->cancelRequested);
    
    // Since we cancelled, the result is irrelevant
    return result;
}

struct LatticePoint_t {
    LocalIndex_t x;
    LocalIndex_t y;
};

BYTEARRAY_RELEASE_INLINE
BOOL computePrettyGoodMiddleSnakeTraversal(HFByteArrayEditScript *self, const unsigned char * restrict aBuff, const unsigned char * restrict bBuff, BOOL forwards, LocalIndex_t k, LocalIndex_t D, GraphIndex_t *restrict vector, LocalIndex_t aLen, LocalIndex_t bLen, struct LatticePoint_t * restrict bestAchievedCoords) {
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
    if (y > bestAchievedCoords->x) bestAchievedCoords->y = y;
    
    /* Return YES if we reached the edge in either dimension. */
    return snakeLength == maxSnakeLength;
}

BYTEARRAY_RELEASE_INLINE
static struct LatticePoint_t bestDiagonal(HFByteArrayEditScript *self, LocalIndex_t D, const LocalIndex_t * restrict vector) {
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
static struct Snake_t computePrettyGoodMiddleSnake3(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInA, HFRange rangeInB) {
    
#if 0
    /* This function wants to "consume" progress equal to aLen * bLen. */
    HFASSERT(aLen > 0);
    HFASSERT(bLen > 0);
    const unsigned long long progressAllocated = HFProductULL(aLen, bLen);
#endif
    
    /* k cannot exceeed SQUARE_CACHE_SIZE so allocate that up front */
    const LocalIndex_t maxD = SQUARE_CACHE_SIZE;
    GrowableArray_reallocate(&cacheGroup->forwardsArray, maxD, maxD);
    GrowableArray_reallocate(&cacheGroup->backwardsArray, maxD, maxD);
    GraphIndex_t * const restrict forwardsVector = cacheGroup->forwardsArray.ptr;
    GraphIndex_t * const restrict backwardsVector = cacheGroup->backwardsArray.ptr;
    
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
    
    LocalIndex_t forwardsD = 1, backwardsD = 1;
    for (;;) {
        HFASSERT(forwardsD <= maxD);
        HFASSERT(backwardsD <= maxD);
        //if (0 == (D % 256)) printf("Heuristic %ld / %ld\n", D, maxD);
        
        /* Check for cancellation */
        if (*cancelRequested) break;

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
            
            /* Compute our new rectangle starting position */
            offsets[sourceDir] += diagonal.x;
            offsets[destDir] += diagonal.y;
            HFASSERT(offsets[sourceDir] <= rangeInA.length);
            HFASSERT(offsets[destDir] <= rangeInB.length);
            
            /* Extend any snake from that diagonal */
            int64_t tmpProgress = 0;
            unsigned long long snakeLength = compute_forwards_snake_length(self, cacheGroup, self->source, offsets[sourceDir] + rangeInA.location, rangeInA.length - offsets[sourceDir], self->destination, offsets[destDir] + rangeInB.location, rangeInB.length - offsets[destDir], &tmpProgress, cancelRequested);
            offsets[sourceDir] = HFSum(offsets[sourceDir], snakeLength);
            offsets[destDir] = HFSum(offsets[destDir], snakeLength);
            
            /* Compute new lengths */
            lengths[sourceDir] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInA.length - offsets[sourceDir]);
            lengths[destDir] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInB.length - offsets[destDir]);

            /* Now reallocate */
            buffers[sourceDir] = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location + offsets[sourceDir], lengths[sourceDir], sourceDir);
            buffers[destDir] = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location + offsets[destDir], lengths[destDir], destDir);
            
            /* D starts over */
            //forwardsD = 1;
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
            
            /* Extend any snake from that diagonal */
            int64_t tmpProgress = 0;
            unsigned long long snakeLength = compute_backwards_snake_length(self, cacheGroup, self->source, HFMaxRange(rangeInA) - offsets[sourceDir], rangeInA.length - offsets[sourceDir], self->destination, HFMaxRange(rangeInB) - offsets[destDir], rangeInB.length - offsets[destDir], &tmpProgress, cancelRequested);
            offsets[sourceDir] = HFSum(offsets[sourceDir], snakeLength);
            offsets[destDir] = HFSum(offsets[destDir], snakeLength);
            
            /* Compute new lengths */
            lengths[sourceDir] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInA.length - offsets[sourceDir]);
            lengths[destDir] = (LocalIndex_t)MIN(SQUARE_CACHE_SIZE, rangeInB.length - offsets[DestForwards]);
            
            /* Now reallocate */
            buffers[sourceDir] = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location + offsets[sourceDir], lengths[sourceDir], sourceDir);
            buffers[DestForwards] = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location + offsets[destDir], lengths[destDir], destDir);
            
            /* D starts over */
            //backwardsD = 1;
        }
                        
        /* Check for overlap in either dimension */
        unsigned long long totalX = offsets[SourceForwards] + (unsigned long long)maxAchievedForwards.x + offsets[SourceBackwards] + (unsigned long long)maxAchievedBackwards.x;
        unsigned long long totalY = offsets[DestForwards] + (unsigned long long)maxAchievedForwards.y + offsets[DestBackwards] + (unsigned long long)maxAchievedBackwards.y;
        
        if (totalX > rangeInA.length || totalY > rangeInB.length) {
            
            /* We've overlapped in some dimension. Return the best diagonal thus far. */
            struct LatticePoint_t fw = bestDiagonal(self, forwardsD, forwardsVector);
            struct LatticePoint_t bk = bestDiagonal(self, backwardsD, backwardsVector);
            
            unsigned long long forwardScore = fw.x + fw.y + offsets[SourceForwards] + offsets[DestForwards];
            unsigned long long backwardScore = bk.x + bk.y + offsets[SourceBackwards] + offsets[DestBackwards];
            
            struct Snake_t result;
            result.middleSnakeLength = 0;
            result.progressConsumed = 0;
            result.hasNonEmptySnake = YES;
            if (forwardScore >= backwardScore) {
                result.startX = rangeInA.location + HFSum(fw.x, offsets[SourceForwards]);
                result.startY = rangeInB.location + HFSum(fw.y, offsets[DestForwards]);
            } else {
                result.startX = HFMaxRange(rangeInA) - HFSum(bk.x, offsets[SourceBackwards]);
                result.startY = HFMaxRange(rangeInB) - HFSum(bk.y, offsets[DestBackwards]);                
            }
        }
    }
    
    /* We don't expect to exit this loop unless we cancel */
    HFASSERT(*self->cancelRequested);
    return forwardsResult;
}


BYTEARRAY_RELEASE_INLINE
static struct Snake_t computeMiddleSnake(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInA, HFRange rangeInB) {
    
    struct Snake_t result;
    
    if (rangeInA.length < HEURISTIC_THRESHOLD && rangeInB.length < HEURISTIC_THRESHOLD) {
        /* Full algorithm */
        const unsigned char * const forwardsABuff = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location, ll2l(rangeInA.length), SourceForwards);
        const unsigned char * const forwardsBBuff = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location, ll2l(rangeInB.length), DestForwards);        
        result = computeActualMiddleSnake(self, cacheGroup, forwardsABuff, forwardsBBuff, (int)rangeInA.length, (int)rangeInB.length);
        
        /* Offset the result */
        result.startX = HFSum(result.startX, rangeInA.location);
        result.startY = HFSum(result.startY, rangeInB.location);
        
        HFASSERT(result.startX >= rangeInA.location);
        HFASSERT(result.startY >= rangeInB.location);
        return result;
        
    } else {
        
        /* Run our heuristic forwards and backwards until there is a possibility of overlap */
        const unsigned long long maxA = HFMaxRange(rangeInA), maxB = HFMaxRange(rangeInB);
        struct Snake_t fw = {.startX = 0, .startY = 0, .hasNonEmptySnake = true};
        struct Snake_t bk = {.startX = rangeInA.length, .startY = rangeInB.length, .hasNonEmptySnake = true};
        struct Snake_t * const fwp = &fw;
        struct Snake_t * const bkp = &bk;
        
        const double desiredBias = (double)rangeInA.length / (double)rangeInB.length;
        
        const BOOL LOG = YES;
        
        if (LOG) NSLog(@"%p: Entering %@, %@", (void *)pthread_self(), HFRangeToString(rangeInA), HFRangeToString(rangeInB));
        for (;;) {
                     
            /* Compute our lengths */
            const LocalIndex_t lengths[NUM_CACHES] = {
                [SourceForwards] = (LocalIndex_t)MIN(HEURISTIC_THRESHOLD, rangeInA.length - fw.startX),
                [DestForwards] = (LocalIndex_t)MIN(HEURISTIC_THRESHOLD, rangeInB.length - fw.startY),
                [SourceBackwards] = (LocalIndex_t)MIN(HEURISTIC_THRESHOLD, bk.startX),
                [DestBackwards] = (LocalIndex_t)MIN(HEURISTIC_THRESHOLD, bk.startY)
            };

            /* Cache into buffers */
            const unsigned char * const buffers[NUM_CACHES] = {
                [SourceForwards] = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location + fw.startX, lengths[SourceForwards], SourceForwards),
                [DestForwards] = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location + fw.startY, lengths[DestForwards], DestForwards),
                [SourceBackwards] = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location + bk.startX - lengths[SourceBackwards], lengths[SourceBackwards], SourceBackwards),
                [DestBackwards] = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location + bk.startY - lengths[DestBackwards], lengths[DestBackwards], DestBackwards)
            };
            
            struct Snake_t tmp;
            
            /* Run the forwards algorithm */
            if (LOG) NSLog(@"%p: Running forwards %u / %u", (void *)pthread_self(), lengths[SourceForwards], lengths[DestForwards]);
            tmp = computePrettyGoodSnake2(self, cacheGroup, buffers[SourceForwards], buffers[DestForwards], lengths[SourceForwards], lengths[DestForwards], rangeInA.length, rangeInB.length, desiredBias, YES);
            fw.startX = HFSum(fw.startX, tmp.startX);
            fw.startY = HFSum(fw.startY, tmp.startY);
            if (LOG) NSLog(@"%p: Got %llu, %llu", pthread_self(), fw.startX, fw.startY);
            if (LOG) NSLog(@"%p: Running backwards %u / %u", (void *)pthread_self(), lengths[SourceBackwards], lengths[DestBackwards]);
            
            /* Run the backwards algorithm */
            tmp = computePrettyGoodSnake2(self, cacheGroup, buffers[SourceBackwards], buffers[DestBackwards], lengths[SourceBackwards], lengths[DestBackwards], rangeInA.length, rangeInB.length, desiredBias, NO);;
            bk.startX = HFSubtract(bk.startX, tmp.startX);
            bk.startY = HFSubtract(bk.startY, tmp.startY);
            if (LOG) NSLog(@"%p: Got %llu, %llu", pthread_self(), bk.startX, bk.startY);
            
            /* Check for overlap in either direction. Note this heuristic uses a very different overlap sense than the Myers one. */
            if (fw.startX >= bk.startX || fw.startY >= bk.startY) {
                /* Return whichever snake is "better", that is, made more progress. */
                unsigned long long fwScore = fw.startX + fw.startY;
                unsigned long long bkScore = (HFMaxRange(rangeInA) - bk.startX) + (HFMaxRange(rangeInB) - bk.startY);
                struct Snake_t result = (fwScore >= bkScore ? fw : bk);

                /* Offset the result */
                result.startX = HFSum(result.startX, rangeInA.location);
                result.startY = HFSum(result.startY, rangeInB.location);
                
                if (LOG) NSLog(@"%p: Returning %llu, %llu", (void *)pthread_self(), result.startX, result.startY);
                
                HFASSERT(result.startX >= rangeInA.location);
                HFASSERT(result.startY >= rangeInB.location);
                
                return result;
            }
        }
        
        if (HFSubtract(bk.startX, fw.startX) < HEURISTIC_THRESHOLD && HFSubtract(bk.startY, fw.startY) < HEURISTIC_THRESHOLD) {
            /* Full algorithm */
        }

    }
}

BYTEARRAY_RELEASE_INLINE
static struct Snake_t computeMiddleSnakeOLD(HFByteArrayEditScript *self, struct TLCacheGroup_t * restrict cacheGroup, HFRange rangeInA, HFRange rangeInB) {
    
    LocalIndex_t readLengthA, readLengthB;
    BOOL useHeuristic = (rangeInA.length >= HEURISTIC_THRESHOLD || rangeInB.length >= HEURISTIC_THRESHOLD);
    if (useHeuristic) {
        readLengthA = ull_to_index(MIN(HEURISTIC_THRESHOLD, MAX(1, rangeInA.length / 2)));
        readLengthB = ull_to_index(MIN(HEURISTIC_THRESHOLD, MAX(1, rangeInB.length / 2)));
        
        /* No point in reading more from one than from the other */
        readLengthA = readLengthB = MIN(readLengthA, readLengthB);
    } else {
        readLengthA = ull_to_index(rangeInA.length);
        readLengthB = ull_to_index(rangeInB.length);        
    }
    
    const unsigned char * const forwardsABuff = get_cached_bytes(self, cacheGroup, self->source, self->sourceLength, rangeInA.location, readLengthA, SourceForwards);
    const unsigned char * const forwardsBBuff = get_cached_bytes(self, cacheGroup, self->destination, self->destLength, rangeInB.location, readLengthB, DestForwards);        

    struct Snake_t result;
    
    /* If both our ranges are small enough that they fit in our cache, then we can just read them all in and avoid all the range checking we would otherwise have to do. */
    if (! useHeuristic) {
        /* We can apply the full algorithm */
        result = computeActualMiddleSnake(self, cacheGroup, forwardsABuff, forwardsBBuff, readLengthA, readLengthB);
    } else {
        
        /* We have to use our heuristic. */
        HFASSERT(rangeInA.length >= (unsigned long long)readLengthA && rangeInB.length >= (unsigned long long)readLengthB);
        result = computePrettyGoodSnake(self, cacheGroup, forwardsABuff, forwardsBBuff, readLengthA, readLengthB, rangeInA.length, rangeInB.length, YES /* forwards */);
    }
    
    /* Offset the result */
    result.startX = HFSum(result.startX, rangeInA.location);
    result.startY = HFSum(result.startY, rangeInB.location);
    return result;
}

static inline unsigned long long change_progress(HFByteArrayEditScript *self, unsigned long long remainingProgress, unsigned long long newRemainingProgress) {
    HFAtomicAdd64(remainingProgress - newRemainingProgress, self->currentProgress); //note: remainingProgress - newRemainingProgress may be negative
    return newRemainingProgress;
}

static void computeLongestCommonSubsequence(HFByteArrayEditScript *self, struct TLCacheGroup_t *restrict cacheGroup, OSQueueHead * restrict cacheQueueHead, dispatch_group_t dispatchGroup, HFRange rangeInA, HFRange rangeInB, uint32_t recursionDepth) {
    if (recursionDepth >= MAX_RECURSION_DEPTH) {
        /* Oops! */
        OSAtomicIncrement32(&self->concurrentProcesses);
        dispatch_group_async(dispatchGroup, dispatch_get_global_queue(0, 0), ^{
            /* We can't re-use cacheGroup because our caller may want to use it again.  So attempt to dequeue a group. If we can't, we'll have to make one. */
            struct TLCacheGroup_t *newGroup = OSAtomicDequeue(cacheQueueHead, offsetof(struct TLCacheGroup_t, next));
            if (! newGroup) {
                newGroup = malloc(sizeof *newGroup);
                initializeCacheGroup(newGroup);
            }

            /* Compute the LCS */
            computeLongestCommonSubsequence(self, newGroup, cacheQueueHead, dispatchGroup, rangeInA, rangeInB, 0);
                        
            /* Put the group on the queue (either back or fresh) so others can use it */
            OSAtomicEnqueue(cacheQueueHead, newGroup, offsetof(struct TLCacheGroup_t, next));
            OSAtomicDecrement32(&self->concurrentProcesses);
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
    if (rangeInA.length == 0 || rangeInB.length == 0) {
        append_instruction(self, rangeInA, rangeInB);
        return;
    }
    
    unsigned long long prefix = compute_forwards_snake_length(self, cacheGroup, source, rangeInA.location, rangeInA.length, destination, rangeInB.location, rangeInB.length, self->currentProgress, cancelRequested);
    HFASSERT(prefix <= rangeInA.length && prefix <= rangeInB.length);
    
    if (prefix > 0) {	
        rangeInA.location += prefix;
        rangeInA.length -= prefix;
        rangeInB.location += prefix;
        rangeInB.length -= prefix;
        
        /* Recompute the remaining progress. */
        remainingProgress = change_progress(self, remainingProgress, rangeInA.length * rangeInB.length);
        
        if (rangeInA.length == 0 || rangeInB.length == 0) {
            /* All done */
            append_instruction(self, rangeInA, rangeInB);
            return;
        }
    }
    
    unsigned long long suffix = compute_backwards_snake_length(self, cacheGroup, source, HFMaxRange(rangeInA), rangeInA.length, destination, HFMaxRange(rangeInB), rangeInB.length, self->currentProgress, cancelRequested);
    HFASSERT(suffix <= rangeInA.length && suffix <= rangeInB.length);
    HFASSERT(suffix <= rangeInA.length && suffix <= rangeInB.length);
    if (suffix > 0) {
        rangeInA.length -= suffix;
        rangeInB.length -= suffix;
        
        /* Recompute the remaining progress. */
        remainingProgress = change_progress(self, remainingProgress, rangeInA.length * rangeInB.length);
        
        if (rangeInA.length == 0 || rangeInB.length == 0) {
            /* All done */
            append_instruction(self, rangeInA, rangeInB);
            return;
        }
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
        append_instruction(self, rangeInA, rangeInB);
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
        OSAtomicIncrement32(&self->concurrentProcesses);
        dispatch_group_async(dispatchGroup, dispatch_get_global_queue(0, 0), ^{
            
            /* Attempt to dequeue a group. If we can't, we'll have to make one. */
            struct TLCacheGroup_t *newGroup = OSAtomicDequeue(cacheQueueHead, offsetof(struct TLCacheGroup_t, next));
            if (! newGroup) {
                newGroup = malloc(sizeof *newGroup);
                initializeCacheGroup(newGroup);
            }
            
            /* Compute the subsequence */
            computeLongestCommonSubsequence(self, newGroup, cacheQueueHead, dispatchGroup, suffixRangeA, suffixRangeB, 0);
            
            /* Put the group on the queue (either back or fresh) so others can use it */
            OSAtomicEnqueue(cacheQueueHead, newGroup, offsetof(struct TLCacheGroup_t, next));
            
            /* We're done */
            OSAtomicDecrement32(&self->concurrentProcesses);
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


- (void)convertInstructionsToIncrementalForm {
    long long accumulatedLengthChange = 0;
    size_t idx;
    for (idx = 0; idx < insnCount; idx++) {
        insns[idx].src.location += accumulatedLengthChange;
        accumulatedLengthChange -= insns[idx].src.length;
        accumulatedLengthChange += insns[idx].dst.length;
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
    
    /* Compute the longest common subsequence. */
    computeLongestCommonSubsequence(self, &cacheGroup, &queueHead, dispatchGroup, HFRangeMake(0, sourceLength), HFRangeMake(0, destLength), 0);
    
    /* Wait until we're done */
    dispatch_group_wait(dispatchGroup, DISPATCH_TIME_FOREVER);
    dispatch_release(dispatchGroup);
    
    /* Make sure our insnQueue is done by submitting a no-op to it, then clear it */
    dispatch_sync(insnQueue, ^{});
    dispatch_release(insnQueue);
    insnQueue = NULL;

    if (! *cancelRequested) {
#if ! NDEBUG
        /* Validate the data */
        struct HFEditInstruction_t prevInsn;
        for (size_t i=0; i < insnCount; i++) {
            struct HFEditInstruction_t insn = insns[i];
            if (i > 0) {
                HFASSERT(insn.src.location >= prevInsn.src.location);
                HFASSERT(insn.dst.length == 0 || prevInsn.dst.length == 0 || insn.dst.location >= prevInsn.dst.location);
                HFASSERT(compare_instructions(insn, prevInsn) > 0);
                HFASSERT(! can_merge_instruction(&prevInsn, &insn));
                HFASSERT(! can_merge_instruction(&insn, &prevInsn));
            }
            prevInsn = insn;
        }
#endif
        
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

#if HFUNIT_TESTS

@implementation HFByteArrayEditScript (HFUnitTests)

#define HFTEST(a) do { if (! (a)) { printf("Test failed on line %u of file %s: %s\n", __LINE__, __FILE__, #a); exit(0); } } while (0)

static BOOL test_merge(struct HFEditInstruction_t left, struct HFEditInstruction_t right, struct HFEditInstruction_t expectedResult) {
    if (merge_instruction(&left, &right)) {
        HFTEST(HFRangeEqualsRange(left.src, expectedResult.src));
        HFTEST(HFRangeEqualsRange(left.dst, expectedResult.dst));
        return YES;
    }
    return NO;
}

static struct HFEditInstruction_t newinsn(unsigned long long a, unsigned long long b, unsigned long long c, unsigned long long d) {
    struct HFEditInstruction_t result;
    result.src.location = a;
    result.src.length = b;
    result.dst.location = c;
    result.dst.length = d;
    return result;
}

+ (void)_unitTestStaticFunctions {
#if 0
    struct HFEditInstruction_t left = newinsn(0, 0, 0, 0), right = newinsn(0, 0, ULLONG_MAX, 0);
    HFTEST(test_merge(left, right, newinsn(0, 0, ULLONG_MAX, 0)));
    left.src.length = 1;
    HFTEST(test_merge(left, right, newinsn(0, 0, ULLONG_MAX, 0)));
    //wow, do I ever need to make a lot more of these tests!
#endif
}

@end

#endif
