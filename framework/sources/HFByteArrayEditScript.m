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

static void GrowableArray_reallocate(struct GrowableArray_t *array, size_t newLength) {
    /* Don't shrink us.  In practice we shouldn't try to. */
    if (newLength <= array->length) return;
    
    /* We support indexing in the range [-newLength, newLength], which means we need space for 2 * newLength + 1 elements.  And maybe malloc can give us more for free! */
    size_t bufferLength = malloc_good_size((newLength * 2 + 1) * sizeof *array->ptr);
    
    /* Compute the array length backwards from the buffer length: it may be larger if malloc_good_size gave us more. */
    newLength = ((bufferLength / sizeof *array->ptr) - 1) / 2;
    
    /* Allocate our memory */
    GraphIndex_t *newPtr = check_malloc(bufferLength);
    
    /* Offset it so it points at the center */
    newPtr += newLength;
    
    if (array->length > 0) {
	/* Copy the data over the center.  For the source, imagine array->length is 3.  Then the buffer looks like -3, -2, -1, 0, 1, 2, 3 with array->ptr pointing at 0.  Thus we subtract 3 to get to the start of the buffer, and the length is 2 * array->length + 1.  For the destination, backtrack the same amount. */

	memcpy(newPtr - array->length, array->ptr - array->length, 2 * array->length + 1);
	
	/* Free the old pointer.  Maybe this frees NUL, which is fine. */
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

#define READ_AMOUNT 1024
#define CACHE_AMOUNT (64 * READ_AMOUNT)

/* Returns a pointer to bytes in the given range in the given array, whose length is arrayLen.  Here we avoid using HFRange because compilers are not good at optimizing structs. */
static inline const unsigned char *getCachedBytes(HFByteArrayEditScript *self, HFByteArray *array, unsigned long long arrayLen, unsigned long long rangeLocation, unsigned long rangeLength, unsigned int cacheIndex) {
    HFASSERT(rangeLength <= READ_AMOUNT);
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
	NSLog(@"Blown %s cache: desired: {%llu, %lu} current: {%llu, %lu} new: {%llu, %lu}", kNames[cacheIndex], rangeLocation, rangeLength, cacheRangeLocation, cacheRangeLength, newCacheRangeLocation, newCacheRangeLength);
	
#endif
	return rangeLocation - newCacheRangeLocation + self->caches[cacheIndex].buffer;
    }
}

static inline unsigned long compute_forwards_snake_length(HFByteArrayEditScript *self, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len) {
    if (a_len == 0 || b_len == 0) return 0;
    HFASSERT(a_len + a_offset <= sourceLength);
    HFASSERT(b_len + b_offset <= destLength);
    unsigned long i, alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    const unsigned long long byteArrayLengthA = [a length], byteArrayLengthB = [b length];
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = getCachedBytes(self, a, byteArrayLengthA, a_offset + alreadyRead, amountToRead, SourceForwards);
        const unsigned char *b_buff = getCachedBytes(self, b, byteArrayLengthB, b_offset + alreadyRead, amountToRead, DestForwards);
        for (i=0; i < amountToRead; i++) {
            if (a_buff[i] != b_buff[i]) break;
        }
        alreadyRead += i;
        remainingToRead -= i;
        if (i < amountToRead) break;
    }
    return alreadyRead;
}

/* returns the backwards snake of length no more than MIN(a_len, b_len), starting at a_offset, b_offset (exclusive) */
static inline unsigned long compute_backwards_snake_length(HFByteArrayEditScript *self, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len) {
    HFASSERT(a_offset <= sourceLength);
    HFASSERT(b_offset <= destLength);
    HFASSERT(a_len <= a_offset);
    HFASSERT(b_len <= b_offset);
    unsigned long i, alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
	const unsigned char *a_buff = getCachedBytes(self, a, self->sourceLength, a_offset - alreadyRead - amountToRead, amountToRead, SourceBackwards);
	const unsigned char *b_buff = getCachedBytes(self, b, self->destLength, b_offset - alreadyRead - amountToRead, amountToRead, DestBackwards);
        i = amountToRead;
        while (i > 0 && a_buff[i-1] == b_buff[i-1]) {
            i--;
        }
        remainingToRead -= amountToRead - i;
        alreadyRead += amountToRead - i;
        if (i != 0) break; //found some non-matching byte
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
};

static struct Snake_t computeMiddleSnake(HFByteArrayEditScript *self, HFRange rangeInA, HFRange rangeInB, struct GrowableArray_t * restrict forwardsArray, struct GrowableArray_t * restrict backwardsArray) {
    HFASSERT(rangeInA.length > 0);
    HFASSERT(rangeInB.length > 0);
    
    HFASSERT(HFMaxRange(rangeInA) <= [self->source length]);
    HFASSERT(HFMaxRange(rangeInB) <= [self->destination length]);
    
    HFByteArray * const a = self->source, * const b = self->destination;    
    long aLen = ll2l(rangeInA.length), bLen = ll2l(rangeInB.length);
    long aStart = ll2l(rangeInA.location), bStart = ll2l(rangeInB.location);
    
    //maxD = ceil((M + N) / 2)
    long maxD = ll2l((HFSum(rangeInA.length, rangeInB.length) + 1) / 2);
    
    /* Adding delta to k in the forwards direction gives you k in the backwards direction */
    const long delta = bLen - aLen;
    const BOOL oddDelta = (delta & 1);
    
    GraphIndex_t *restrict forwardsVector = forwardsArray->ptr;
    GraphIndex_t *restrict backwardsVector = backwardsArray->ptr;
    
    /* The length of the array is always big enough to write at index 1. */
    forwardsVector[1] = 0;
    backwardsVector[1] = 0;
    
    /* Keep track of the maximum snake length */
    long maxSnakeLength = 0;
    
    for (long D=0; D <= maxD; D++) {
	/* We will be indexing from -D to D, so reallocate if necessary.  It's a little sketchy that we check both forwardsArray->length and backwardsArray->length, which are usually the same size: this is just in case malloc_good_size returns something different for them. */
	if ((size_t)D > forwardsArray->length || (size_t)D > backwardsArray->length) {
	    GrowableArray_reallocate(forwardsArray, D);
	    forwardsVector = forwardsArray->ptr;
	    
	    GrowableArray_reallocate(backwardsArray, D);
	    backwardsVector = backwardsArray->ptr;
	}
	
	for (long k = -D; k <= D; k += 2) {
	    /* Forward path */
	    long x, y;
	    
	    /* k-1 represents considering a movement from the left, while k + 1 represents considering a movement from above */
	    if (k == -D || (k != D && forwardsVector[k-1] < forwardsVector[k+1])) {
		x = forwardsVector[k + 1]; // down
	    } else {
		x = forwardsVector[k - 1] + 1; // right
	    }
	    y = x - k;
	    	    
	    // find the end of the furthest reaching forward D-path in diagonal k.  We require x >= 0, but we don't need to check for it since it's guaranteed by the algorithm.
	    long snakeLength = 0;
	    HFASSERT(x >= 0);
	    if (y >= 0 && x < aLen && y < bLen) {
		snakeLength = compute_forwards_snake_length(self, a, aStart + x, aLen - x, b, bStart + y, bLen - y);
	    }
	    maxSnakeLength = MAX(maxSnakeLength, snakeLength);
	    x += snakeLength;
            y += snakeLength;
            forwardsVector[k] = x;
	    
	    // check for overlap
	    if (oddDelta) {
		/* The forward diagonals increase in the up / right direction, and the reverse diagonals increase in the down/left direction. Compute the reverse diagonal corresponding to the forward diagonal k. */
		long kInReverse = -(k + delta);
		
		/* At this point, the reverse path has only had time to explore diagonals -(D-1) through (D-1) */
		if (kInReverse >= -(D-1) && kInReverse <= (D-1)) {
		    if (forwardsVector[k] + backwardsVector[kInReverse] >= aLen) {
			struct Snake_t result;
			result.startX = aStart + forwardsVector[k] - snakeLength;
			result.startY = bStart + forwardsVector[k] - snakeLength - k;
			result.middleSnakeLength = snakeLength;
			result.maxSnakeLength = maxSnakeLength;
			return result;			
		    }
		}
	    }

	    
	    /* Reverse path.  Here k = 0 corresponds to the lower right corner. */
	    for (long k = -D; k <= D; k += 2) {
		//printf("%ld / %ld\n", k, D);
		long x, y;
		
		/* k - 1 represents considering a movement from the right, while k+1 represents a movement from below */
		if (k == -D || (k != D && backwardsVector[k-1] < backwardsVector[k+1])) {
		    x = backwardsVector[k + 1]; // up
		}
		else {
		    x = backwardsVector[k - 1] + 1; // left
		}
		y = x - k;
		
		long snakeLength = 0;
		/* We want to compute the backwards snake.  x = 0 corresponds to the lower right. We require that x >= 0, but don't need to check for that since that's required by the algorithm. */
		HFASSERT(x >= 0);
		if (y >= 0 && x < aLen && y < bLen) {
		    snakeLength = compute_backwards_snake_length(self, a, aStart + aLen - x, aLen - x, b, bStart + bLen - y, bLen - y);
		}
		HFASSERT(snakeLength == 0 || (snakeLength <= aLen - x && snakeLength <= bLen - y));
		maxSnakeLength = MAX(maxSnakeLength, snakeLength);
		x += snakeLength;
		y += snakeLength;
		backwardsVector[k] = x;
		
		// check for overlap
		if (! oddDelta) {
		    /* At this point, the forward path has explored values [D, D], in its own coordinate space.  If our k is 0, then it corresponds to diagonal k - delta in the forward direction. */
		    long kInForwards = -(k + delta);
		    if (kInForwards >= -D && kInForwards <= D) {
			/* It's OK to check kInForwards */
			if (backwardsVector[k] + forwardsVector[kInForwards] >= aLen) {
			    /* Success.  Here, x is the "negative delta" from the max of rangeInA */
			    struct Snake_t result;
			    result.startX = HFMaxRange(rangeInA) - backwardsVector[k];
			    result.startY = HFMaxRange(rangeInB) - (backwardsVector[k] - k);
			    result.middleSnakeLength = snakeLength;
			    result.maxSnakeLength = maxSnakeLength;
			    return result;			    
			}
		    }
		    
		}
	    }
	}
    }
    NSLog(@"Aw nuts");
    [NSException raise:NSInternalInconsistencyException format:@"Diff algorithm terminated unexpectedly"];
    return (struct Snake_t){0, 0, 0, 0};
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
    
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInA, HFRangeMake(0, [source length])));
    HFASSERT(HFRangeIsSubrangeOfRange(rangeInB, HFRangeMake(0, [destination length])));
    if (rangeInA.length == 0 || rangeInB.length == 0) {
	appendInstruction(self, rangeInA, rangeInB);
	return;
    }
    
    unsigned long prefix = compute_forwards_snake_length(self, source, rangeInA.location, rangeInA.length, destination, rangeInB.location, rangeInB.length);
    HFASSERT(prefix <= rangeInA.length && prefix <= rangeInB.length);
    rangeInA.location += prefix;
    rangeInA.length -= prefix;
    rangeInB.location += prefix;
    rangeInB.length -= prefix;
    HFAtomicAdd64(prefix, self->currentProgress);
    if (rangeInA.length == 0 || rangeInB.length == 0) {
	appendInstruction(self, rangeInA, rangeInB);
	/* We consumed these instructions, so update our progress */
	HFAtomicAdd64(rangeInA.length + rangeInB.length, self->currentProgress);
	return;
    }
    
    unsigned long suffix = compute_backwards_snake_length(self, source, HFMaxRange(rangeInA), rangeInA.length, destination, HFMaxRange(rangeInB), rangeInB.length);
    HFASSERT(suffix <= rangeInA.length && suffix <= rangeInB.length);
    rangeInA.length -= suffix;
    rangeInB.length -= suffix;
    HFAtomicAdd64(suffix, self->currentProgress);
    if (rangeInA.length == 0 || rangeInB.length == 0) {
	appendInstruction(self, rangeInA, rangeInB);
	/* We consumed these instructions, so update our progress */
	HFAtomicAdd64(rangeInA.length + rangeInB.length, self->currentProgress);
	return;
    }
    
    //NSLog(@"Compute snake from %@ to %@", HFRangeToString(rangeInA), HFRangeToString(rangeInB));    
    struct Snake_t middleSnake = computeMiddleSnake(self, rangeInA, rangeInB, forwardsArray, backwardsArray);
    
    HFAtomicAdd64(rangeInA.length + rangeInB.length, self->currentProgress);
    
    HFASSERT(middleSnake.middleSnakeLength >= 0);
    HFASSERT(middleSnake.startX >= rangeInA.location);
    HFASSERT(middleSnake.startY >= rangeInB.location);
    HFASSERT(HFSum(middleSnake.startX, middleSnake.middleSnakeLength) <= HFMaxRange(rangeInA));
    HFASSERT(HFSum(middleSnake.startY, middleSnake.middleSnakeLength) <= HFMaxRange(rangeInB));
    //NSLog(@"Middle snake: %lu -> %lu, %lu -> %lu", middleSnake.startX, middleSnake.startX + middleSnake.middleSnakeLength, middleSnake.startY, middleSnake.startY + middleSnake.middleSnakeLength);
    
    if (0 && middleSnake.maxSnakeLength == 0) {
	/* There were no non-empty snakes at all, so the entire range must be a diff */
	appendInstruction(self, rangeInA, rangeInB);
	return;
    }
    
    /* Since we "consumed" the middle snake, add it to our progress */
    HFAtomicAdd64(middleSnake.middleSnakeLength, self->currentProgress);
    
    HFRange prefixRangeA, prefixRangeB, suffixRangeA, suffixRangeB;

    prefixRangeA = HFRangeMake(rangeInA.location, middleSnake.startX - rangeInA.location);
    prefixRangeB = HFRangeMake(rangeInB.location, middleSnake.startY - rangeInB.location);
    
    suffixRangeA.location = HFSum(middleSnake.startX, middleSnake.middleSnakeLength);
    suffixRangeA.length = HFMaxRange(rangeInA) - suffixRangeA.location;
    
    suffixRangeB.location = HFSum(middleSnake.startY, middleSnake.middleSnakeLength);
    suffixRangeB.length = HFMaxRange(rangeInB) - suffixRangeB.location;
    
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
		snakeLength = compute_forwards_snake_length(self, a, X, a_len - X, b, Y, b_len - Y);
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
    GrowableArray_reallocate(&forwardsArray, 1024);
    GrowableArray_reallocate(&backwardsArray, 1024);
    
    /* Compute the longest common subsequence. */
    altInsns = [[NSMutableData alloc] init];
    computeLongestCommonSubsequence(self, HFRangeMake(0, [source length]), HFRangeMake(0, [destination length]), &forwardsArray, &backwardsArray);
    
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

- (BOOL)computeDifferencesTrackingProgress:(HFProgressTracker *)tracker {
    /* Allocate memory for our caches.  Do it in one big chunk. */
    const NSUInteger numCaches = sizeof caches / sizeof *caches;
    unsigned char *basePtr = malloc(CACHE_AMOUNT * numCaches);
    for (NSUInteger i=0; i < numCaches; i++) {
	HFASSERT(caches[i].buffer == NULL);
	caches[i].buffer = basePtr + CACHE_AMOUNT * i;
    }
    
    const int localCancelRequested = 0;
    unsigned long long localCurrentProgress = 0;
    
    /* Remember our progress tracker (if any) */
    if (tracker) {
	[tracker retain];
	
	/* Tell our progress tracker how much work to expect.  Here we treat the amount of work as the sum of the horizontal and vertical.  Note: this sum may overflow!  Ugh! */
	[tracker setMaxProgress:[source length] + [destination length]];
	
	/* Stash away pointers to its direct-write variables */
	cancelRequested = &tracker->cancelRequested;
	currentProgress = (int64_t *)&tracker->currentProgress;
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
    
    return result;
}

- (id)initWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst {
    [self initWithSource:src toDestination:dst];
    [self computeDifferencesTrackingProgress:nil];
    return self;
}

+ (HFByteArrayEditScript *)editScriptFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst trackingProgress:(HFProgressTracker *)progressTracker {
    HFByteArrayEditScript *result = [[self alloc] initWithDifferenceFromSource:src toDestination:dst];
    BOOL success = [result computeDifferencesTrackingProgress:progressTracker];
    if (! success) {
	/* Cancelled */
	[result release];
	result = nil;
    }
    return [result autorelease];
    
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
