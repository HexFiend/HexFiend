//
//  TavlTreeByteArray.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFTavlTreeByteArray.h>
#import <HexFiend/tavltree.h>
#import <HexFiend/HFByteArrayPiece.h>
#import <HexFiend/HFByteSlice.h>

#define LOCATION_MAGIC_NUMBER 0

//we use the following hack to represent a location instead of a range
//the key type is normally a HFRange
//but if the key's LENGTH is LOCATION_MAGIC_NUMBER, it should be treated as a location instead
//where the location is stored in the location field of the range
#define IS_LOCATION(a) (a->length == LOCATION_MAGIC_NUMBER)


static int compare(void* a, void* b);
static void *key_of(void* obj);
static void *make_item(const void *obj);
static void  free_item(void* obj);
static void *copy_item(void* dst, const void* src);
static void *alloc(size_t);
static void *alloc_gc(size_t);
static void  dealloc(void*);
static void  dealloc_gc(void*);

static const char *tavl_description(TAVL_treeptr tree) __attribute__ ((unused));
static const char *tavl_description(TAVL_treeptr tree) {
    assert(tree);
    NSMutableArray* result = [NSMutableArray array];
    TAVL_nodeptr node = tavl_reset(tree);
    while ((node = tavl_succ(node))) {
	HFByteArrayPiece* arrayPiece = NULL;
	tavl_getdata(tree, node, &arrayPiece);
	if (arrayPiece) [result addObject:[NSString stringWithFormat:@"{%llu - %llu}", [arrayPiece offset], [arrayPiece length]]];
	else [result addObject:@"{NULL}"];
    }
    if (! [result count]) return "(empty tree)";
    return [[result componentsJoinedByString:@" "] UTF8String];
}

@implementation HFTavlTreeByteArray

- init {
    if ((self = [super init])) {
	BOOL gc = objc_collecting_enabled();
        tree = tavl_init(compare, key_of, make_item, free_item, copy_item, (gc ? alloc_gc : alloc), (gc ? dealloc_gc : dealloc));
        if (! tree) {
            [self release];
            [NSException raise:NSMallocException format:@"tavl_init failed: out of memory."];
        }
    }
    return self;
}

- (void)dealloc {
    tavl_destroy(tree);
    [super dealloc];
}

//TODO: perhaps cache this?
- (unsigned long long)length {
    //find the offset of the last node, then add its length
    TAVL_nodeptr node = tavl_pred(tavl_reset(tree));
    if (! node) return 0;
    HFByteArrayPiece* arrayPiece=NULL;
    tavl_getdata(tree, node, &arrayPiece);
    REQUIRE_NOT_NULL(arrayPiece);
    return [arrayPiece offset] + [arrayPiece length];
}

- (BOOL)offsetsAreCorrect {
    unsigned long long offset = 0;
    HFByteArrayPiece* arrayPiece=NULL;
    TAVL_nodeptr node = tavl_reset(tree);
    while ((node = tavl_succ(node))) {
	tavl_getdata(tree, node, &arrayPiece);
	REQUIRE_NOT_NULL(arrayPiece);
	if ([arrayPiece offset] != offset) return NO;
	offset += [arrayPiece length];
    }
    return YES;
}

- (NSArray *)byteSlices {
    NSMutableArray* result = [NSMutableArray array];
    TAVL_nodeptr node = tavl_reset(tree);
    while ((node = tavl_succ(node))) {
	HFByteArrayPiece* arrayPiece = NULL;
	tavl_getdata(tree, node, &arrayPiece);
	REQUIRE_NOT_NULL(arrayPiece);
	[result addObject:[arrayPiece byteSlice]];
    }
    return result;
}

- (NSString*)description { return [NSString stringWithUTF8String:tavl_description(tree)]; }

- (void)copyBytes:(unsigned char *)dst range:(HFRange)range {
    HFASSERT(range.length == 0 || dst != NULL);
    HFASSERT(HFMaxRange(range) <= [self length]);
    if (range.length == 0) return;
    
    HFRange key = HFRangeMake(range.location, LOCATION_MAGIC_NUMBER);
    HFByteArrayPiece* arrayPiece=NULL;
    
    TAVL_nodeptr node = tavl_find(tree, &key);
    REQUIRE_NOT_NULL(node);
    tavl_getdata(tree, node, &arrayPiece);
    REQUIRE_NOT_NULL(arrayPiece);
    while (range.length) {
	unsigned long long offsetIntoPiece = range.location - [arrayPiece offset];
	HFASSERT(offsetIntoPiece < [arrayPiece length]);
	unsigned long long numBytesToCopy = llmin(range.length, [arrayPiece length] - offsetIntoPiece);
	HFByteSlice *slice = [arrayPiece byteSlice];
	[slice copyBytes:dst range:HFRangeMake(offsetIntoPiece, numBytesToCopy)];
	range.length -= numBytesToCopy;
	range.location += numBytesToCopy;
	dst += numBytesToCopy;
	if (range.length) {
	    node = tavl_succ(node);
	    REQUIRE_NOT_NULL(node);
	    tavl_getdata(tree, node, &arrayPiece);
	    REQUIRE_NOT_NULL(arrayPiece);
	}
    }
}

#ifndef NDEBUG
- (void)checkOffsets {
    if (! [self offsetsAreCorrect]) {
	puts("Invalid offsets!");
	puts(tavl_description(tree));
	exit(EXIT_FAILURE);
    }
}
#endif

- (void)deleteBytesInRange:(const HFRange)range {
    [self _raiseIfLockedForSelector:_cmd];
    if (range.length == 0) return; //nothing to delete
    HFASSERT(HFMaxRange(range) <= [self length]);
    
    //fast path for deleting everything
    if (range.location == 0 && range.length == [self length]) {
	tavl_delete_all(tree);
	return;
    }
    
    //if our range doesn't fall on the edges of a ByteArrayPiece, then we need to construct a piece before and/or after to replace the piece we're getting rid of
    //be careful not to autorelease these - it can block us from taking the fast path (since the reference won't be decremented until the autorelease pool flushes)
    HFByteArrayPiece *first = nil, * last = nil;
    
    unsigned long long offset, length;
    HFByteArrayPiece* arrayPiece=NULL;
    HFRange key;
    TAVL_nodeptr firstNode, lastNode, node;
    
    key = HFRangeMake(range.location, LOCATION_MAGIC_NUMBER);
    firstNode = tavl_find(tree, &key);
    REQUIRE_NOT_NULL(firstNode);
    
    tavl_getdata(tree, firstNode, &arrayPiece);
    REQUIRE_NOT_NULL(arrayPiece);
    
    //construct the first part
    offset = [arrayPiece offset];
    HFASSERT(offset <= range.location);
    if (offset < range.location) {
	HFByteSlice *slice = [arrayPiece byteSlice];
	slice = [slice subsliceWithRange:HFRangeMake(0, range.location - offset)];
	first = [[HFByteArrayPiece alloc] initWithSlice:slice offset:offset];
    }
    
    //construct the last part by finding the last byte in the range
    key = HFRangeMake(range.location + range.length - 1, LOCATION_MAGIC_NUMBER);
    lastNode = tavl_find(tree, &key);
    REQUIRE_NOT_NULL(lastNode);
    
    tavl_getdata(tree, lastNode, &arrayPiece);
    REQUIRE_NOT_NULL(arrayPiece);
    
    offset = [arrayPiece offset];
    length = [arrayPiece length];
    HFASSERT(offset + length > offset);
    HFASSERT(range.location + range.length > offset);
    HFASSERT(offset + length >= range.location + range.length);
    if (offset + length > range.location + range.length) {
	HFByteSlice *slice = [arrayPiece byteSlice];
	unsigned long long offsetIntoPiece = range.location + range.length - offset;
	slice = [slice subsliceWithRange:HFRangeMake(offsetIntoPiece, length - offsetIntoPiece)];
	
	unsigned long long offsetForLastPiece = range.location;
	if (first) offsetForLastPiece = [first offset] + [first length];
	
	last = [[HFByteArrayPiece alloc] initWithSlice:slice offset:offsetForLastPiece];
    }
    
    //delete everything that overlaps our range
    HFRange deletionRange = range;
    while (deletionRange.length > 0) {
	key.location = deletionRange.location;
	
	//find and remember the offset of our next node
	TAVL_nodeptr node = tavl_find(tree, &key);
	REQUIRE_NOT_NULL(node);
	unsigned long long nextOffset = 0;
	tavl_getdata(tree, node, &arrayPiece);
	REQUIRE_NOT_NULL(arrayPiece);
	nextOffset = [arrayPiece offset] + [arrayPiece length];
	HFASSERT(nextOffset > deletionRange.location);
	
	int tavlDeleteSuccess = tavl_delete(tree, &key);
	HFASSERT(tavlDeleteSuccess);
	
	deletionRange.length -= llmin(deletionRange.length, nextOffset - deletionRange.location);
	deletionRange.location = nextOffset;
    }
    
    //insert remaining pieces and fix up offsets
    node = NULL;
    offset = range.location;
    if (first) {
	node = tavl_insert(tree, first, 0);
	if (! node) {
	    [NSException raise:NSMallocException format:@"Out of memory calling tavl_insert"];
	}
	offset = [first offset] + [first length];
    }
    
    if (last) {
	node = tavl_insert(tree, last, 0);
	if (! node) {
	    [NSException raise:NSMallocException format:@"Out of memory calling tavl_insert"];
	}
	offset = HFSum([last offset], [last length]);
    }
    
    [first release];
    first = nil;
    [last release];
    last = nil;
    
    //find the node at the end of our range, and update it and all of its successors to have the right offset
    if (! node) {
	//we didn't have a first or last remainder node, so look for the node at the end of our range
	key.location = range.location + range.length;
	node = tavl_find(tree, &key);
    }
    else {
	//we did have a first or last remainder node, so look to the node one past it
	node = tavl_succ(node);
    }
    while (node) {
	HFByteArrayPiece* updatingPiece=NULL;
	tavl_getdata(tree, node, &updatingPiece);
	REQUIRE_NOT_NULL(updatingPiece);
	[updatingPiece setOffset:offset];
	offset += [updatingPiece length];
	node = tavl_succ(node);
    }
    
#ifndef NDEBUG
    [self checkOffsets];
#endif
}

- (void)insertByteSlice:(HFByteSlice *)slice atOffset:(unsigned long long)offset {
    [self _raiseIfLockedForSelector:_cmd];
    REQUIRE_NOT_NULL(slice);
    HFByteArrayPiece *first = nil, *second = nil;
    //find the node containing that offset
    //note that offset can equal our length, in which case no node should contain it
    
    HFRange key = HFRangeMake(offset, LOCATION_MAGIC_NUMBER);
    
    const unsigned long long sliceLength = [slice length];
    
    TAVL_nodeptr insert_result;
    
    TAVL_nodeptr node = tavl_find(tree, &key);
    if (node) {
	
#if USE_FAST_PATH
    {
	TAVL_nodeptr prev_node = tavl_pred(node);
	if (prev_node) {
	    HFByteArrayPiece* prev_piece=NULL;
	    tavl_getdata(myTree, prev_node, &prev_piece);
	    REQUIRE_NOT_NULL(prev_piece);
	    
	    BOOL fp_result = [prev_piece fastPathAppendByteSlice:slice atLocation:offset];
	    if (fp_result) {
		//update following offsets
		TAVL_nodeptr offset_updating_node = node;
		unsigned long long new_offset = [prev_piece offset] + [prev_piece length];
		do {
		    HFByteArrayPiece* offset_piece=NULL;
		    tavl_getdata(myTree, offset_updating_node, &offset_piece);
		    REQUIRE_NOT_NULL(offset_piece);
		    [offset_piece setOffset:new_offset];
		    new_offset += [offset_piece length];
		} while ((offset_updating_node = tavl_succ(offset_updating_node)));
		return; //fast path successful
	    }
	}
#ifndef NDEBUG
	[self checkOffsets];
#endif
    }
#endif
	
	HFByteArrayPiece* arrayPiece=NULL;
	tavl_getdata(tree, node, &arrayPiece);
	REQUIRE_NOT_NULL(arrayPiece);
	
	const unsigned long long arrOffset = [arrayPiece offset];
	const unsigned long long arrLength = [arrayPiece length];
	HFASSERT(offset >= arrOffset && offset - arrOffset < arrLength);
	
	[arrayPiece constructNewArrayPiecesAboutRange:key first:&first second:&second];
	
	if (second) [second setOffset:[second offset] + sliceLength];
	
	//update all the following offsets
	TAVL_nodeptr succ = node;
	unsigned long long startingOffset = arrOffset + arrLength + sliceLength;
	while ((succ = tavl_succ(succ))) {
	    HFByteArrayPiece* piece=NULL;
	    tavl_getdata(tree, succ, &piece);
	    REQUIRE_NOT_NULL(piece);
	    [piece setOffset:startingOffset];
	    startingOffset += [piece length];
	}
	
	//delete the existing node
	int delete_result = tavl_delete(tree, [arrayPiece tavl_key]);
	HFASSERT(delete_result == 1);
	
	if (first) {
	    insert_result = tavl_insert(tree, first, 0);
	    HFASSERT(insert_result);
	}
	if (second) {
	    insert_result = tavl_insert(tree, second, 0);
	    HFASSERT(insert_result);	
	}
    }
#if USE_FAST_PATH
    //fast path for the end of the tree
    else {
	TAVL_nodeptr end = tavl_pred(tavl_reset(myTree));
	if (end) {
	    HFByteArrayPiece* piece=NULL;
	    tavl_getdata(myTree, end, &piece);
	    HFASSERT(piece);
	    BOOL fp_result = [piece fastPathAppendByteSlice:slice atLocation:offset];
	    if (fp_result) {
		return;
	    }
	}
    }
#endif
    
    //insert the data; we may be at the end of the tree
    HFByteArrayPiece* insertingPiece = [[HFByteArrayPiece alloc] initWithSlice:slice offset:offset];
    insert_result = tavl_insert(tree, insertingPiece, 0);
    [insertingPiece release];
    HFASSERT(insert_result);
    
#ifndef NDEBUG
    [self checkOffsets];
#endif
}


- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange {
    [self _raiseIfLockedForSelector:_cmd];
    //TODO: optimize this
    if (lrange.length > 0) {
	[self deleteBytesInRange:lrange];
    }
    if ([slice length] > 0) [self insertByteSlice:slice atOffset:lrange.location];
}

- subarrayWithRange:(HFRange)range {
    HFASSERT(HFMaxRange(range) <= [self length]);

    HFTavlTreeByteArray* result = [[[[self class] alloc] init] autorelease];
    
    if (! range.length) return result;
    
    HFRange key = HFRangeMake(range.location, LOCATION_MAGIC_NUMBER);
    HFByteArrayPiece* arrayPiece=NULL;
    
    TAVL_nodeptr node = tavl_find(tree, &key);
    REQUIRE_NOT_NULL(node);
    tavl_getdata(tree, node, &arrayPiece);
    
    unsigned long long targetOffset = 0;
    while (targetOffset < range.length) {
	REQUIRE_NOT_NULL(arrayPiece);
	HFByteSlice* slice = [arrayPiece byteSlice];
	const unsigned long long arrayOffset = [arrayPiece offset];
	const unsigned long long arrayLength = [arrayPiece length];
	unsigned long long beforeLength;
	if (range.location < arrayOffset) beforeLength = 0;
	else beforeLength = range.location - arrayOffset;
	
	unsigned long long afterLength;
	if (range.location + range.length > arrayOffset + arrayLength) afterLength = 0;
	else afterLength = arrayOffset + arrayLength - range.location - range.length;
	
	unsigned long long bytesFromThisPieceToCopy = arrayLength - beforeLength - afterLength;
	
	HFByteSlice* targetSlice;
	//optimize the common case
	if (beforeLength == 0 && bytesFromThisPieceToCopy == arrayLength) targetSlice = slice;
	else targetSlice = [slice subsliceWithRange:HFRangeMake(beforeLength, bytesFromThisPieceToCopy)];
	
	[result insertByteSlice:targetSlice inRange:HFRangeMake(targetOffset, 0)];
	targetOffset += bytesFromThisPieceToCopy;
	
	node = tavl_succ(node);
	arrayPiece = nil;
	if (node) tavl_getdata(tree, node, &arrayPiece);
    }
    HFASSERT([result length]==range.length);
    return result;
}

@end


#ifndef NDEBUG
static int compare(void* ap, void* bp) {
    const HFRange* a = ap, * b = bp;
    REQUIRE_NOT_NULL(a);
    REQUIRE_NOT_NULL(b);
    BOOL is_loc_a = IS_LOCATION(a);
    BOOL is_loc_b = IS_LOCATION(b);
    if (is_loc_a && is_loc_b) {
	NSLog(@"Warning: two locations being compared against one another!");
	if (a->location < b->location) return -1;
	else if (a->location == b->location) return 0;
	else return 1;
    }
    else if (is_loc_a) { //&& ! is_loc_b
	if (a->location < b->location) return -1;
	else if (a->location >= b->location && a->location - b->location < b->length) return 0;
	else return 1;
    }
    else if (is_loc_b) { // && ! is_loc_a
	if (b->location < a->location) return 1;
	else if (b->location >= a->location && b->location - a->location < a->length) return 0;
	else return -1;
    }
    else { // ! (is_loc_a || is_loc_b)
	   //ensure there's no overlap, since that wouldn't make sense
	assert(a==b || ! HFIntersectsRange(*a, *b));
	if (a->location < b->location) return -1;
	else if (a->location == b->location) return 0;
	else return 1;
    }
}
#else
static int compare(void* ap, void* bp) {
    const HFRange* a = ap, * b = bp;
    if (a->location < b->location) {
	if (b->location - a->location < a->length) return 0;
	else return -1;
    }
    else if (a->location > b->location) {
	if (a->location - b->location < b->length) return 0;
	else return 1;
    }
    else return 0;
}
#endif

static void *key_of(void* obj) {
    REQUIRE_NOT_NULL(obj);
    return &((HFByteArrayPiece *)obj)->pieceRange;
}

static void *make_item(const void *obj) {
    REQUIRE_NOT_NULL(obj);
    return [(HFByteArrayPiece *)obj retain];
}

static void free_item(void* obj) {
    REQUIRE_NOT_NULL(obj);
    [(HFByteArrayPiece *)obj release];
}

static void *copy_item(void* dst, const void* src) {
    REQUIRE_NOT_NULL(dst);
    REQUIRE_NOT_NULL(src);
    *(__strong id*)dst = (id)src;
    return dst;
}

static void *alloc(size_t val) {
    return malloc(val);
}

static void *alloc_gc(size_t val) {
    return NSAllocateCollectable(val, NSScannedOption);
}

static void dealloc(void* obj) {
    free(obj);
}

static void dealloc_gc(void* obj) {
    USE(obj);
    /* Nothing to do under GC */
}
