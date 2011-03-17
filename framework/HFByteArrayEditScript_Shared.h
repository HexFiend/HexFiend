/* Some private functions shared between our two implemetations of byte array edit script computations. */

#include <stdlib.h>
#include <malloc/malloc.h>

/* HFASSERT macro reproduced here */
#ifndef HFASSERT
  #if ! NDEBUG
    #define HFASSERT(a) assert(a)
  #else
    #define HFASSERT(a)
  #endif
#endif

/* indexes into a caches */
enum {
    SourceForwards,
    SourceBackwards,
    DestForwards,
    DestBackwards,
    
    NUM_CACHES
};

typedef long GraphIndex_t;

/* GrowableArray_t allows indexing in the range [-length, length], and preserves data around its center when reallocated. */
struct GrowableArray_t {
    size_t length;
    GraphIndex_t * __restrict__ ptr;
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
}

/* Deallocate the contents of a growable array */
static void GrowableArray_free(struct GrowableArray_t *array) {
    free(array->ptr - array->length);
}

/* A struct that stores thread local data */
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
    
    /* The list of instructions */
    struct HFEditInstruction_t *insns;
    size_t insnCount;
};

/* Create a cache. */
#define CACHE_AMOUNT (16 * 1024 * 1024)
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



/* A linked list for holding some instructions */

//255 allows the total size of the struct to be < 8192
#define INSTRUCTION_LIST_CHUNK 255
struct InstructionList_t {
    struct InstructionList_t *next;    
    uint32_t count;
    struct HFEditInstruction_t insns[INSTRUCTION_LIST_CHUNK]; 
};


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


static BOOL can_merge_instruction(const struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right) {
    /* We can merge these if one (or both) of the dest ranges are empty, or if they are abutting.  Note that if a destination is empty, we have to copy the location from the other one, because we like to give nonsense locations (-1) to zero length ranges.  src never has a nonsense location. */
    return HFMaxRange(left->src) == right->src.location && (left->dst.length == 0 || right->dst.length == 0 || HFMaxRange(left->dst) == right->dst.location);
}

static BOOL merge_instruction(struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right) {
    BOOL result = NO;
    if (can_merge_instruction(left, right)) {
        left->src.length = HFSum(left->src.length, right->src.length);
        if (left->dst.length == 0) left->dst.location = right->dst.location;
        left->dst.length = HFSum(left->dst.length, right->dst.length);
        result = YES;
    }
    return result;
}

static void merge_instructions(CFMutableDataRef left, CFDataRef right) {
    const size_t insnSize = sizeof(struct HFEditInstruction_t);
    size_t leftSize = CFDataGetLength(left), rightSize = CFDataGetLength(right);
    struct HFEditInstruction_t *leftInsns = (struct HFEditInstruction_t *)CFDataGetMutableBytePtr(left);
    const struct HFEditInstruction_t *rightInsns = (const struct HFEditInstruction_t *)CFDataGetBytePtr(right);
    HFASSERT(leftSize % insnSize == 0 && rightSize % insnSize == 0);
    /* Try to merge the last left with the first right */
    size_t leftInsnCount = leftSize / insnSize;
    if (leftSize > 0 && rightSize > 0 && merge_instruction(leftInsns + leftInsnCount - 1, rightInsns)) {
        /* Successfully merged one instruction */
        rightInsns++;
        rightSize -= insnSize;
    }
    /* Now append whatever's left */
    CFDataAppendBytes(left, (const unsigned char *)rightInsns, rightSize);
}


static inline struct InstructionList_t *append_instruction_to_list(HFByteArrayEditScript *self, struct InstructionList_t *list, HFRange rangeInA, HFRange rangeInB) {
    /* This should only ever be called with the end of a list */
    HFASSERT(list != NULL && list->next == NULL);
    if (rangeInA.length || rangeInB.length) {
        /* Make the new instruction */
        const struct HFEditInstruction_t insn = {.src = rangeInA, .dst = rangeInB};
        
        if (list->count == 0) {
            /* Just append */
            list->insns[0] = insn;
            list->count = 1;
        } else if (merge_instruction(list->insns + list->count - 1, &insn)) {
            /* Merged, nothing to do */
        } else if (list->count < INSTRUCTION_LIST_CHUNK) {
            /* We can append without overflow */
            list->insns[list->count++] = insn;
        } else {
            /* We must make a new list chunk. */
            struct InstructionList_t *newList = (struct InstructionList_t *)malloc(sizeof *newList);
            newList->count = 1;
            newList->insns[0] = insn;
            newList->next = NULL;
            
            /* Append to the tail.  Now we are the tail. */
            list->next = newList;
            list = newList;
        }
    }
    return list;
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


/* SSE optimized versions of difference matching */
#if (defined(__i386__) || defined(__x86_64__))
#include <xmmintrin.h>

/* match_forwards and match_backwards are assumed to be fast enough and to operate on small enough buffers that they don't have to check for cancellation. */
static inline size_t match_forwards(const unsigned char * a, const unsigned char * b, size_t length) {
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

static inline size_t match_backwards(const unsigned char * a, const unsigned char * b, size_t length) {
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
