//
//  HFByteArrayEditScript.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/7/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArrayEditScript.h>
#import <HexFiend/HFByteArray.h>
#include <malloc/malloc.h>

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


#define READ_AMOUNT 1024
#define CACHE_AMOUNT (2 * READ_AMOUNT)

static inline const unsigned char *getCachedBytes(HFByteArray *array, unsigned long arrayLen, HFRange range, NSMutableData *data, HFRange *cacheRange) {
    HFASSERT(range.length <= READ_AMOUNT);
    if (! HFRangeIsSubrangeOfRange(range, *cacheRange)) {
	
	/* Compute how to extend the cached range around the given range */
	unsigned long remainingCacheAmount = CACHE_AMOUNT, rightExtension, leftExtension;
	rightExtension = MIN(remainingCacheAmount, arrayLen - range.location);
	remainingCacheAmount -= rightExtension;
	leftExtension = MIN(remainingCacheAmount, range.location);
	remainingCacheAmount -= leftExtension;
	
	cacheRange->location = range.location - leftExtension;
	cacheRange->length = leftExtension + rightExtension;
	
	NSLog(@"Blown cache: %@ / %@", HFRangeToString(range), HFRangeToString(*cacheRange));
        [array copyBytes:[data mutableBytes] range:*cacheRange];
        HFASSERT(HFRangeIsSubrangeOfRange(range, *cacheRange));
    }
    return range.location - cacheRange->location + (const unsigned char *)[data bytes];
}

static unsigned long compute_forwards_snake_length(HFByteArrayEditScript *self, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len) {
    if (a_len == 0 || b_len == 0) return 0;
    unsigned long i, alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = getCachedBytes(a, [a length], HFRangeMake(a_offset + alreadyRead, amountToRead), self->sourceCache, &self->sourceCacheRange);
        const unsigned char *b_buff = getCachedBytes(b, [b length], HFRangeMake(b_offset + alreadyRead, amountToRead), self->destCache, &self->destCacheRange);
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
static unsigned long compute_backwards_snake_length(HFByteArrayEditScript *self, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len) {
    HFASSERT(a_len <= a_offset);
    HFASSERT(b_len <= b_offset);
    unsigned long i, alreadyRead = 0, remainingToRead = MIN(a_len, b_len);
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
	const unsigned char *a_buff = getCachedBytes(a, a_len, HFRangeMake(a_offset - alreadyRead - amountToRead, amountToRead), self->sourceCache, &self->sourceCacheRange);
	const unsigned char *b_buff = getCachedBytes(b, b_len, HFRangeMake(b_offset - alreadyRead - amountToRead, amountToRead), self->destCache, &self->destCacheRange);
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

- (struct Snake_t)computeMiddleSnakeFromRangeInA:(HFRange)rangeInA toRangeInB:(HFRange)rangeInB {
    NSLog(@"Computing middle snake from range in A: %@ to range in B: %@", HFRangeToString(rangeInA), HFRangeToString(rangeInB));
    
    HFASSERT(rangeInA.length > 0);
    HFASSERT(rangeInB.length > 0);
    
    HFASSERT(HFMaxRange(rangeInA) <= [source length]);
    HFASSERT(HFMaxRange(rangeInB) <= [destination length]);
    
    HFByteArray * const a = source, * const b = destination;    
    long aLen = ll2l(rangeInA.length), bLen = ll2l(rangeInB.length);
    long aStart = ll2l(rangeInA.location), bStart = ll2l(rangeInB.location);
    
    //maxD = ceil((M + N) / 2)
    long maxD = ll2l((HFSum(rangeInA.length, rangeInB.length) + 1) / 2);
    
    /* Adding delta to k in the forwards direction gives you k in the backwards direction */
    const long delta = bLen - aLen;
    const BOOL oddDelta = (delta & 1);
    
    forwardsVector[1] = 0;
    backwardsVector[1] = 0;
    
    long maxSnakeLength = 0;
    
    for (long D=0; D <= maxD; D++) {
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
	    	    
	    // find the end of the furthest reaching forward D-path in diagonal k.
	    long snakeLength = 0;
	    if (x < aLen && y < bLen) {
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
			result.startY = result.startX - k;
			result.middleSnakeLength = snakeLength;
			result.maxSnakeLength = maxSnakeLength;
			return result;			
		    }
		}
	    }

	    
	    /* Reverse path.  Here k = 0 corresponds to the lower right corner. */
	    for (long k = -D; k <= D; k += 2) {
		//printf("%ld / %ld\n", k, upK + D);
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
		if (x < aLen && y < bLen) {
		    /* We want to compute the backwards snake.  x = 0 corresponds to the lower right. */
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
	NSLog(@"Adding instruction %@ -> %@", HFRangeToString(rangeInA), HFRangeToString(rangeInB));
	struct HFEditInstruction_t insn = {.src = rangeInA, .dst = rangeInB};
	[self->altInsns appendBytes:&insn length:sizeof insn];
    }
}

- (void)computeLongestCommonSubsequenceFromRangeInA:(HFRange)rangeInA toRangeInB:(HFRange)rangeInB {
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
    if (rangeInA.length == 0 || rangeInB.length == 0) {
	appendInstruction(self, rangeInA, rangeInB);
	return;
    }
    
    unsigned long suffix = compute_backwards_snake_length(self, source, HFMaxRange(rangeInA), rangeInA.length, destination, HFMaxRange(rangeInB), rangeInB.length);
    HFASSERT(suffix <= rangeInA.length && suffix <= rangeInB.length);
    rangeInA.length -= suffix;
    rangeInB.length -= suffix;
    if (rangeInA.length == 0 || rangeInB.length == 0) {
	appendInstruction(self, rangeInA, rangeInB);
	return;
    }
    
    NSLog(@"Compute snake from %@ to %@", HFRangeToString(rangeInA), HFRangeToString(rangeInB));
    struct Snake_t middleSnake = [self computeMiddleSnakeFromRangeInA:rangeInA toRangeInB:rangeInB];
    
    HFASSERT(middleSnake.middleSnakeLength >= 0);
    HFASSERT(middleSnake.startX >= rangeInA.location);
    HFASSERT(middleSnake.startY >= rangeInB.location);
    HFASSERT(HFSum(middleSnake.startX, middleSnake.middleSnakeLength) <= HFMaxRange(rangeInA));
    HFASSERT(HFSum(middleSnake.startY, middleSnake.middleSnakeLength) <= HFMaxRange(rangeInB));
    NSLog(@"Middle snake: %lu -> %lu, %lu -> %lu", middleSnake.startX, middleSnake.startX + middleSnake.middleSnakeLength, middleSnake.startY, middleSnake.startY + middleSnake.middleSnakeLength);
    
    if (0 && middleSnake.maxSnakeLength == 0) {
	/* There were no non-empty snakes at all, so the entire range must be a diff */
	appendInstruction(self, rangeInA, rangeInB);
	return;
    }
    
    HFRange prefixRangeA, prefixRangeB, suffixRangeA, suffixRangeB;

    prefixRangeA = HFRangeMake(rangeInA.location, middleSnake.startX - rangeInA.location);
    prefixRangeB = HFRangeMake(rangeInB.location, middleSnake.startY - rangeInB.location);
    
    suffixRangeA.location = HFSum(middleSnake.startX, middleSnake.middleSnakeLength);
    suffixRangeA.length = HFMaxRange(rangeInA) - suffixRangeA.location;
    
    suffixRangeB.location = HFSum(middleSnake.startY, middleSnake.middleSnakeLength);
    suffixRangeB.length = HFMaxRange(rangeInB) - suffixRangeB.location;
    
    if (prefixRangeA.length > 0 || prefixRangeB.length > 0) {
	[self computeLongestCommonSubsequenceFromRangeInA:prefixRangeA toRangeInB:prefixRangeB];
    }
    if (suffixRangeA.length > 0 || suffixRangeB.length > 0) {
	[self computeLongestCommonSubsequenceFromRangeInA:suffixRangeA toRangeInB:suffixRangeB];
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
            unsigned long snakeLength = compute_forwards_snake_length(self, a, X, a_len, b, Y, b_len);
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
DONE:
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

/* This function can be used if we want each instruction to be either insert or delete (no replaces) */
static BOOL merge_instruction_old(struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right) {
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

- (void)computeDifference {
    printf("Computing %llu + %llu = %llu\n", [source length], [destination length], [source length] + [destination length]);
    
    const long a_len = (long)[source length], b_len = (long)[destination length];
    const long max = a_len + b_len;
    long *baseForwardsVector = malloc((2 * max + 1) * sizeof *baseForwardsVector);
    long *baseBackwardsVector = malloc((2 * max + 1) * sizeof *baseBackwardsVector);
    
    forwardsVector = baseForwardsVector + max;
    backwardsVector = baseBackwardsVector + max;
#if 0
    size_t numIsns = [self computeGraph:&paths];
    [self generateInstructions:paths count:numIsns diagonal:(long)[source length] - (long)[destination length]];
    free_paths(paths);
#else
    altInsns = [[NSMutableData alloc] init];
    [self computeLongestCommonSubsequenceFromRangeInA:HFRangeMake(0, a_len) toRangeInB:HFRangeMake(0, b_len)];
    insnCount = [altInsns length] / sizeof *insns;
    insns = NSAllocateCollectable(insnCount * sizeof *insns, 0);//not scanned, collectable
    [altInsns getBytes:insns];
    [altInsns release];
    altInsns = nil;
#endif
    [self mergeInstructions];
    
    forwardsVector = NULL;
    backwardsVector = NULL;
    
    free(baseForwardsVector);
    free(baseBackwardsVector);
    
//    [self _dumpDebug];
//    [self convertInstructionsToIncrementalForm];
//    [self _dumpDebug];
}

- (id)initWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst {
    [super init];
    source = [src retain];
    destination = [dst retain];
    sourceCache = [[NSMutableData alloc] initWithLength:CACHE_AMOUNT];
    destCache = [[NSMutableData alloc] initWithLength:CACHE_AMOUNT];
    [self computeDifference];
    return self;
}

- (void)dealloc {
    [source release];
    [destination release];
    [sourceCache release];
    [destCache release];
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
