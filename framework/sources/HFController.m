//
//  HFController.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFController.h>
#import <HexFiend/HFRepresenter_Internal.h>
#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFFullMemoryByteArray.h>
#import <HexFiend/HFFullMemoryByteSlice.h>

@implementation HFController

- (id)init {
    [super init];
    bytesPerLine = 16;
    representers = [[NSMutableArray alloc] init];
    selectedContentsRanges = [[NSMutableArray alloc] initWithObjects:[HFRangeWrapper withRange:HFRangeMake(0, 0)], nil];
    byteArray = [[HFFullMemoryByteArray alloc] init];
    return self;
}

- (void)dealloc {
    [representers makeObjectsPerformSelector:@selector(_setController:) withObject:nil];
    [representers release];
    [selectedContentsRanges release];
    [super dealloc];
}

- (NSArray *)representers {
    return [NSArray arrayWithArray:representers];
}

- (void)notifyRepresentersOfChanges:(HFControllerPropertyBits)bits {
    FOREACH(HFRepresenter*, rep, representers) {
        [rep controllerDidChange:bits];
    }
}

- (void)addRepresenter:(HFRepresenter *)representer {
    REQUIRE_NOT_NULL(representer);
    HFASSERT([representers indexOfObjectIdenticalTo:representer] == NSNotFound);
    HFASSERT([representer controller] == nil);
    [representer _setController:self];
    [representers addObject:representer];
    [representer controllerDidChange: -1];
}

- (void)removeRepresenter:(HFRepresenter *)representer {
    REQUIRE_NOT_NULL(representer);    
    HFASSERT([representers indexOfObjectIdenticalTo:representer] != NSNotFound);
    [representers removeObjectIdenticalTo:representer];
    [representer _setController:nil];
}

- (HFRange)displayedContentsRange {
    return HFRangeMake(0, [self contentsLength]);
}

- (NSArray *)selectedContentsRanges {
#if ! NDEBUG
    HFASSERT(selectedContentsRanges != nil);
    HFASSERT([selectedContentsRanges count] > 0);
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFASSERT(HFRangeIsSubrangeOfRange([wrapper HFRange], HFRangeMake(0, [self contentsLength])));
    }
#endif
    return [NSArray arrayWithArray:selectedContentsRanges];
}

- (unsigned long long)contentsLength {
    if (! byteArray) return 0;
    else return [byteArray length];
}

- (void)copyBytes:(unsigned char *)bytes range:(HFRange)range {
    HFASSERT(range.length <= ULONG_MAX); // it doesn't make sense to ask for a buffer larger than can be stored in memory
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
    [byteArray copyBytes:bytes range:range];
}

- (void)setByteArray:(HFByteArray *)val {
    REQUIRE_NOT_NULL(val);
    [val retain];
    [byteArray release];
    byteArray = val;
    [self notifyRepresentersOfChanges: HFControllerContentValue | HFControllerContentLength];
}

- (HFByteArray *)byteArray {
    return byteArray;
}

- (NSUInteger)bytesPerLine {
    return bytesPerLine;
}

- (void)_updateBytesPerLine {
    NSUInteger newBytesPerLine = ULONG_MAX;
    FOREACH(HFRepresenter*, rep, representers) {
        NSView *view = [rep view];
        CGFloat width = [view frame].size.width;
        NSUInteger repMaxBytesPerLine = [rep maximumBytesPerLineForViewWidth:width];
        newBytesPerLine = MIN(repMaxBytesPerLine, newBytesPerLine);
    }
    if (newBytesPerLine != bytesPerLine) {
        HFASSERT(newBytesPerLine > 0);
        bytesPerLine = newBytesPerLine;
        [self notifyRepresentersOfChanges:HFControllerBytesPerLine];
    }
}

- (void)_updateDisplayedRange {
    NSUInteger maxBytesForViewSize = ULONG_MAX;
    FOREACH(HFRepresenter*, rep, representers) {
        NSView *view = [rep view];
        NSUInteger repMaxBytesPerLine = [rep maximumNumberOfBytesForViewSize:[view frame].size];
        maxBytesForViewSize = MIN(repMaxBytesPerLine, maxBytesForViewSize);
    }
    LongRange proposedNewDisplayRange = HFRangeMake(displayedContentsRange.location, maxBytesForViewSize);
    
}

- (void)representer:(HFRepresenter *)rep changedProperties:(HFControllerPropertyBits)properties {
    USE(rep);
    if (properties & HFControllerBytesPerLine) {
        [self _updateBytesPerLine];
        properties &= ~HFControllerBytesPerLine;
    }
    if (properties & HFControllerDisplayedRange) {
        [self _updateDisplayedRange];
        properties &= ~HFControllerDisplayedRange;
    }
    if (properties) {
        NSLog(@"Unknown properties: %lx", properties);
    }
}

#ifndef NDEBUG
#define HFTEST(a) do { if (! (a)) { printf("Test failed on line %u of file %s: %s\n", __LINE__, __FILE__, #a); exit(0); } } while (0)
+ (void)_testRangeFunctions {
    HFRange range = HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL);
    HFTEST(range.location == UINT_MAX + 573ULL && range.length == UINT_MAX * 2ULL);
    HFTEST(HFRangeIsSubrangeOfRange(range, range));
    HFTEST(! HFRangeIsSubrangeOfRange(range, HFRangeMake(34, 0)));
    HFTEST(HFRangeIsSubrangeOfRange(range, HFRangeMake(range.location - 32, range.length + 54)));
    HFTEST(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, ULLONG_MAX)));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 23), HFRangeMake(ULLONG_MAX - 3, 23)));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 22), HFRangeMake(ULLONG_MAX - 3, 23)));
    HFTEST(HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL)));
    HFTEST(HFSumDoesNotOverflow(ULLONG_MAX, 0));
    HFTEST(! HFSumDoesNotOverflow(ULLONG_MAX, 1));
    HFTEST(HFSumDoesNotOverflow(ULLONG_MAX / 2, ULLONG_MAX / 2));
    HFTEST(HFSumDoesNotOverflow(0, 0));
    HFTEST(ll2l((unsigned long long)UINT_MAX) == UINT_MAX);
}

static NSData *randomDataOfLength(NSUInteger length) {
    if (! length) return [NSData data];
    
    unsigned char* buff = check_malloc(length);
    
    unsigned* word = (unsigned*)buff;
    NSUInteger wordCount = length / sizeof *word;
    NSUInteger i;
    unsigned randBits = 0;
    unsigned numUsedRandBits = 31;
    for (i=0; i < wordCount; i++) {
        if (numUsedRandBits >= 31) {
            randBits = random();
            numUsedRandBits = 0;
        }
        unsigned randVal = random() << 1;
        randVal |= (randBits & 1);
        randBits >>= 1;
        numUsedRandBits++;
        word[i] = randVal;
    }
    
    unsigned byteIndex = wordCount * sizeof *word;
    while (byteIndex < length) {
        buff[byteIndex++] = random() & 0xFF;
    }
    
    return [NSData dataWithBytesNoCopy:buff length:length freeWhenDone:YES];
}

+ (void)_testByteArray {
    const BOOL should_debug = NO;
#define DEBUG if (should_debug)  
    DEBUG puts("Beginning TAVL Tree test:");
    HFByteArray* first = [[[HFFullMemoryByteArray alloc] init] autorelease];
    HFByteArray* second = [[[HFFullMemoryByteArray alloc] init] autorelease];
    
    //srandom(time(NULL));
    
    unsigned opCount = 5000;
    unsigned long long expectedLength = 0;
    unsigned i;
    for (i=1; i <= opCount; i++) {
	NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
	unsigned op;
	const unsigned long long length = [first length];
	unsigned long long offset;
	unsigned long long number;
	switch ((op = (random()%2))) {
	    case 0: { //insert
		NSData *data = randomDataOfLength(1 + random()%1000);
		offset = random() % (1 + length);
		HFByteSlice* slice = [[HFFullMemoryByteSlice alloc] initWithData:data];
		DEBUG printf("%u)\tInserting %llu bytes at %llu...", i, [slice length], offset);
		[first insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
		[second insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
		expectedLength += [data length];
		[slice release];
		break;
	    }
	    case 1: { //delete
		if (length > 0) {
		    offset = random() % length;
		    number = 1 + random() % (length - offset);
		    DEBUG printf("%u)\tDeleting at %llu for %llu...", i, offset, number);
		    [first deleteBytesInRange:HFRangeMake(offset, number)];
		    [second deleteBytesInRange:HFRangeMake(offset, number)];
		    expectedLength -= number;
		}
		else DEBUG printf("%u)\tLength of zero, no delete...", i);
		break;
	    }
	}
	[pool release];
	fflush(NULL);
	if ([first _debugIsEqual:second]) {
	    DEBUG printf("OK! Length: %llu\t%s\n", [second length], [[second description] UTF8String]);
	}
	else {
	    DEBUG printf("Error! expected length: %llu mem length: %llu tavl length:%llu desc: %s\n", expectedLength, [first length], [second length], [[second description] UTF8String]);
	    exit(EXIT_FAILURE);
	}
    }
    DEBUG puts("Done!");
    DEBUG printf("%s\n", [[second description] UTF8String]);
}

+ (void)_runAllTests {
    [self _testRangeFunctions];
    [self _testByteArray];

}
#endif

#ifndef NDEBUG
+ (void)initialize {
    if (self == [HFController class]) {
        [self _runAllTests];
    }
}
#endif

@end
