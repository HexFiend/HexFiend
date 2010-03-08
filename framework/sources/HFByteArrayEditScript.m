//
//  HFByteArrayEditScript.m
//  HexFiend_2
//
//  Created by Peter Ammon on 3/7/10.
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArrayEditScript.h>
#import <HexFiend/HFByteArray.h>

@implementation HFByteArrayEditScript

struct DPath_t {
    struct DPath_t *next;
    long D;
    long *V;
    long array_base[];
};

struct HFEditInstruction_t {
    HFRange range;
    unsigned long long offsetInDestinationForInsertion;
    BOOL isInsertion;
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

#define READ_AMOUNT 1024
#define CACHE_AMOUNT (2 * READ_AMOUNT)

static const unsigned char *getCachedBytes(HFByteArray *array, unsigned long arrayLen, HFRange range, NSMutableData *data, HFRange *cacheRange) {
    HFASSERT(range.length <= READ_AMOUNT);
    HFRange newCacheRange = *cacheRange;
    if (! HFRangeIsSubrangeOfRange(range, *cacheRange)) {
        newCacheRange.location = range.location - MIN(range.location, READ_AMOUNT);
        newCacheRange.length = MIN(CACHE_AMOUNT, arrayLen - newCacheRange.location);
        [array copyBytes:[data mutableBytes] range:newCacheRange];
        *cacheRange = newCacheRange;
        HFASSERT(HFRangeIsSubrangeOfRange(range, *cacheRange));
    }
    return range.location - cacheRange->location + (const unsigned char *)[data bytes];
}

static unsigned long compute_forwards_snake_length(HFByteArrayEditScript *self, HFByteArray *a, unsigned long a_offset, unsigned long a_len, HFByteArray *b, unsigned long b_offset, unsigned long b_len) {
    if (a_offset >= a_len || b_offset >= b_len) return 0;
    unsigned long i, alreadyRead = 0, remainingToRead = MIN(a_len - a_offset, b_len - b_offset);
    while (remainingToRead > 0) {
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
        const unsigned char *a_buff = getCachedBytes(a, a_len, HFRangeMake(a_offset + alreadyRead, amountToRead), self->sourceCache, &self->sourceCacheRange);
        const unsigned char *b_buff = getCachedBytes(b, b_len, HFRangeMake(b_offset + alreadyRead, amountToRead), self->destCache, &self->destCacheRange);
        for (i=0; i < amountToRead; i++) {
            if (a_buff[i] != b_buff[i]) break;
        }
        alreadyRead += i;
        remainingToRead -= i;
        if (i < amountToRead) break;
    }
    return alreadyRead;
}

static unsigned long compute_backwards_snake_length(HFByteArray *a, unsigned long a_offset, HFByteArray *b, unsigned long b_offset) {
    NSCParameterAssert(a_offset <= [a length]);
    NSCParameterAssert(b_offset <= [b length]);
    unsigned long i, alreadyRead = 0, remainingToRead = MIN(a_offset, b_offset);
    while (remainingToRead > 0) {
        unsigned char a_buff[READ_AMOUNT], b_buff[READ_AMOUNT];
        unsigned long amountToRead = MIN(READ_AMOUNT, remainingToRead);
        [a copyBytes:a_buff range:HFRangeMake(a_offset - alreadyRead - amountToRead, amountToRead)];
        [b copyBytes:b_buff range:HFRangeMake(b_offset - alreadyRead - amountToRead, amountToRead)];
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

- (long)computeGraph:(struct DPath_t **)outPaths {
    HFByteArray * const a = source, * const b = destination;
    if (! can_compute_diff([a length], [b length])) {
        [NSException raise:NSInvalidArgumentException format:@"Cannot compute diff between %@ and %@: it would require too much memory!", a, b];
    }
    
    const long a_len = (long)[a length], b_len = (long)[b length];
    const long max = a_len + b_len;
    long * const array_base = malloc((2 * max + 1) * sizeof *array_base);
    long * const V = array_base + max;
    int finished = 0;
    
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
        }
    }
DONE:
    free(array_base);
    if (outPaths) {
        *outPaths = path_list;
    }
    printf("Done!\n");
    return D;
}

- (void)generateInstructions:(const struct DPath_t *)pathsHead count:(long)instructionMaxCount diagonal:(long)diagonal {
    if (pathsHead == NULL || pathsHead->D == 0) return;
    insns = NSAllocateCollectable(instructionMaxCount * sizeof *insns, 0); //not scanned, not collectable
    size_t insnIndex = 0;
    const struct DPath_t *paths = pathsHead;
    while (paths) {
        assert((diagonal >= -paths->D) && (diagonal <= paths->D));
        long X = paths->V[diagonal];
        long Y = X - diagonal;
        
        assert(X >= 0);
        assert(Y >= 0);
        /* Follow the "snake" backwards as far as we can */
        unsigned long snakeLength = compute_backwards_snake_length(source, X, destination, Y);
        X -= snakeLength;
        Y -= snakeLength;
        
        if (X == 0 && Y == 0) {
            /* We are done */
            break;
        }
        
        /* Determine if we are the result of a vertical movement or a horizontal movement */
        const struct DPath_t *next = paths->next;
        long xCoordForVertical = (diagonal + 1 <= next->D ? next->V[diagonal + 1] : -2);
        long xCoordForHorizontal = (diagonal - 1 >= - next->D ? next->V[diagonal - 1] : -2);
        
        if (xCoordForVertical == X) {
            /* It was vertical */
            diagonal += 1;
            insns[insnIndex++] = (struct HFEditInstruction_t){.range = HFRangeMake(Y - 1, 1), .offsetInDestinationForInsertion = Y - 1, .isInsertion = YES};
            printf("Insert 1 at offset %lu\n", Y - 1);
        }
        else {
            /* It was horizontal */
            diagonal -= 1;
            insns[insnIndex++] = (struct HFEditInstruction_t){.range = HFRangeMake(X - 1, 1), .offsetInDestinationForInsertion = -1, .isInsertion = NO};
            printf("Delete 1 from offset %lu\n", X - 1);
        }
        paths = paths->next;
    }
    insnCount = insnIndex;
}

static int compare_instructions(const void *ap, const void *bp) {
    const struct HFEditInstruction_t *a = ap, *b = bp;
    if (a->range.location != b->range.location) {
        /* Sort lower locations to the front */
        return (a->range.location > b->range.location) - (b->range.location > a->range.location);
    }
    else {
        /* If the locations are equal, sort insertions first */
        return b->isInsertion - a->isInsertion;
    }
}

static BOOL merge_instruction(struct HFEditInstruction_t *left, const struct HFEditInstruction_t *right) {
    if (left->isInsertion == right->isInsertion && HFMaxRange(left->range) == right->range.location) {
        left->range.length += right->range.length;
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
    insnCount = trailing + 1;
    insns = NSReallocateCollectable(insns, insnCount * sizeof *insns, 0);
}

- (void)convertInstructionsToIncrementalForm {
    long accumulatedLengthChange = 0;
    size_t idx;
    for (idx = 0; idx < insnCount; idx++) {
        insns[idx].range.location += accumulatedLengthChange;
        if (insns[idx].isInsertion) accumulatedLengthChange += insns[idx].range.length;
        else accumulatedLengthChange -= insns[idx].range.length;
    }
}

- (void)_dumpDebug {
    printf("Dumping %p:\n", self);
    size_t i;
    for (i=0; i < insnCount; i++) {
        const struct HFEditInstruction_t *isn = insns + i;
        if (isn->isInsertion) {
            printf("\tInsert %llu at %llu (from %llu)\n", isn->range.length, isn->range.location, isn->offsetInDestinationForInsertion);
        }
        else {
            printf("\tDelete %llu from %llu\n", isn->range.length, isn->range.location);
        }
    }
}

- (void)computeDifference {
    struct DPath_t *paths;
    long D = [self computeGraph:&paths];
    [self generateInstructions:paths count:D diagonal:(long)[source length] - (long)[destination length]];
    free_paths(paths);
    mergesort(insns, insnCount, sizeof *insns, compare_instructions); //sort the instructions in ascending order
    [self mergeInstructions];
    [self _dumpDebug];
    [self convertInstructionsToIncrementalForm];
    [self _dumpDebug];
}

- (id)initWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst {
    [super init];
    source = [src retain];
    destination = [dst retain];
    sourceCache = [[NSMutableData alloc] initWithLength:CACHE_AMOUNT];
    destCache = [[NSMutableData alloc] initWithLength:CACHE_AMOUNT];
    NSLog(@"Initializing with %llu + %llu = %llu", [src length], [dst length], [src length] + [dst length]);
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

+ (id)scriptWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst {
    return [[[self alloc] initWithDifferenceFromSource:src toDestination:dst] autorelease];
}

- (void)applyToByteArray:(HFByteArray *)target {
    size_t i;
    for (i=0; i < insnCount; i++) {
        const struct HFEditInstruction_t *isn = insns + i;
        if (isn->isInsertion) {
            HFByteArray *sub = [destination subarrayWithRange:HFRangeMake(isn->offsetInDestinationForInsertion, isn->range.length)];
            [target insertByteArray:sub inRange:HFRangeMake(isn->range.location, 0)];
            NSLog(@"Insert %llu at %llu (from %llu)", isn->range.length, isn->range.location, isn->offsetInDestinationForInsertion);
        }
        else {
            /* Deletion */
            [target deleteBytesInRange:isn->range];
            NSLog(@"Delete %llu from %llu", isn->range.length, isn->range.location);
        }
    }
}

@end
