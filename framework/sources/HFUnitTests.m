//
//  HFUnitTests.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#if HFUNIT_TESTS

#import <HexFiend/HexFiend.h>
#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFTestHashing.h>
#import <HexFiend/HFByteArrayEditScript.h>
#import <HFRandomDataByteSlice.h>
#include <sys/stat.h>


@interface HFByteArray (HFUnitTests)
+ (void)_testSearchAlgorithmsLookingForArray:(HFByteArray *)needle inArray:(HFByteArray *)haystack;
@end

@interface HFUnitTests : NSObject
@end

@implementation HFUnitTests

static inline Class preferredByteArrayClass(void) {
    return [HFBTreeByteArray class];
}

#define HFTEST(a) do { if (! (a)) { printf("Test failed on line %u of file %s: %s\n", __LINE__, __FILE__, #a); exit(0); } } while (0)

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
            randBits = (unsigned)random();
            numUsedRandBits = 0;
        }
        unsigned randVal = (unsigned)random() << 1;
        randVal |= (randBits & 1);
        randBits >>= 1;
        numUsedRandBits++;
        word[i] = randVal;
    }
    
    NSUInteger byteIndex = wordCount * sizeof *word;
    while (byteIndex < length) {
        buff[byteIndex++] = random() & 0xFF;
    }
    
    return [NSData dataWithBytesNoCopy:buff length:length freeWhenDone:YES];
}

+ (void)_testFastMemchr {
    unsigned char searchChar = 0xAE;
    unsigned char fillerChar = 0x23;
    const NSUInteger baseOffsets[] = {0, 16, 32, 57, 93, 128, 255, 1017, 2297, 3000, 3152, 4092, 4094, 4095};
    const NSUInteger buffLen = 4099;
    unsigned char *buff = malloc(buffLen);
    HFTEST(buff != NULL);
    [randomDataOfLength(buffLen) getBytes:buff];
    /* Replace instances of searchChar with fillerChar */
    for (NSUInteger i=0; i < buffLen; i++) {
        if (buff[i] == searchChar) buff[i] = fillerChar;
    }
    
    for (NSUInteger i=0; i < sizeof baseOffsets / sizeof *baseOffsets; i++) {
        NSUInteger baseOffset = baseOffsets[i];
        unsigned char stored[16];
        memcpy(stored, buff + baseOffset, sizeof stored);
        for (unsigned int mask = 0; mask <= USHRT_MAX; mask++) {
            /* For each bit set in mask, set the corresponding byte to searchChar */
            unsigned short tempMask = mask;
            while (tempMask != 0) {
                int lsb = __builtin_ffs(tempMask) - 1;
                buff[baseOffset + lsb] = searchChar;
                tempMask &= (tempMask - 1);
            }
            HFTEST(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
            memcpy(buff + baseOffset, stored, sizeof stored);
        }
    }
    
    NSUInteger remaining = buffLen;
    while (remaining--) {
        buff[remaining] = searchChar;
        HFTEST(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
    }
    remaining = buffLen;
    while (remaining--) {
        buff[remaining] = fillerChar;
        HFTEST(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
    }
}

+ (void)_testRangeFunctions {
    HFRange range = HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL);
    HFTEST(range.location == UINT_MAX + 573ULL && range.length == UINT_MAX * 2ULL);
    HFTEST(range.location == UINT_MAX + 573ULL && range.length == UINT_MAX * 2ULL);
    HFTEST(HFRangeIsSubrangeOfRange(range, range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length, 0), range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), HFRangeMake(range.location, 0)));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), HFRangeMake(range.location + 1, 0)));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + 6, 0), range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length, 0), range));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length + 1, 0), range));
    HFTEST(! HFRangeIsSubrangeOfRange(range, HFRangeMake(34, 0)));
    HFTEST(HFRangeIsSubrangeOfRange(range, HFRangeMake(range.location - 32, range.length + 54)));
    HFTEST(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, ULLONG_MAX)));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 23), HFRangeMake(ULLONG_MAX - 3, 23)));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 22), HFRangeMake(ULLONG_MAX - 3, 23)));
    
    HFTEST(HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL)));
    HFTEST(! HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL + 1)));
    
    HFTEST(HFIntersectsRange(range, HFRangeMake(UINT_MAX + 3ULL, UINT_MAX * 2ULL + 1)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(3, 0)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 0), HFRangeMake(3, 0)));
    HFTEST(HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(3, 3)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(6, 0)));
    
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(range, range), range));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(0, 25), HFRangeMake(10, 11)), HFRangeMake(10, 11)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(15, 10)), HFRangeMake(15, 6)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(150, 10)), HFRangeMake(0, 0)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(0, 25), HFRangeMake(10, 11)), HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(0, 25))));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(15, 10)), HFIntersectionRange(HFRangeMake(15, 10), HFRangeMake(10, 11))));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(150, 10)), HFIntersectionRange(HFRangeMake(150, 10), HFRangeMake(10, 11))));
    
    HFTEST(HFRangeEqualsRange(HFUnionRange(HFRangeMake(1, 3), HFRangeMake(2, 3)), HFRangeMake(1, 4)));
    HFTEST(HFRangeEqualsRange(HFUnionRange(HFRangeMake(1, 3), HFRangeMake(4, 4)), HFRangeMake(1, 7)));
    
    HFTEST(HFSumDoesNotOverflow(ULLONG_MAX, 0));
    HFTEST(! HFSumDoesNotOverflow(ULLONG_MAX, 1));
    HFTEST(HFSumDoesNotOverflow(ULLONG_MAX / 2, ULLONG_MAX / 2));
    HFTEST(HFSumDoesNotOverflow(0, 0));
    HFTEST(ll2l((unsigned long long)UINT_MAX) == UINT_MAX);
    
    HFTEST(HFRoundUpToNextMultipleSaturate(0, 2) == 2);
    HFTEST(HFRoundUpToNextMultipleSaturate(2, 2) == 4);
    HFTEST(HFRoundUpToNextMultipleSaturate(200, 200) == 400);
    HFTEST(HFRoundUpToNextMultipleSaturate(1304, 600) == 1800);
    HFTEST(HFRoundUpToNextMultipleSaturate(ULLONG_MAX - 13, 100) == ULLONG_MAX);
    HFTEST(HFRoundUpToNextMultipleSaturate(ULLONG_MAX, 100) == ULLONG_MAX);
    
    const HFRange dirtyRanges1[] = { {4, 6}, {6, 2}, {7, 3} };
    const HFRange cleanedRanges1[] = { {4, 6} };
    
    const HFRange dirtyRanges2[] = { {4, 6}, {6, 2}, {50, 5}, {7, 3}, {50, 1}};
    const HFRange cleanedRanges2[] = { {4, 6}, {50, 5} };
    
    const HFRange dirtyRanges3[] = { {40, 50}, {10, 20} };
    const HFRange cleanedRanges3[] = { {10, 20}, {40, 50} };
    
    const HFRange dirtyRanges4[] = { {11, 3}, {5, 6}, {23, 54} };
    const HFRange cleanedRanges4[] = { {5, 9}, {23, 54} };
    
    
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges1 count:sizeof dirtyRanges1 / sizeof *dirtyRanges1]] isEqual:[HFRangeWrapper withRanges:cleanedRanges1 count:sizeof cleanedRanges1 / sizeof *cleanedRanges1]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges2 count:sizeof dirtyRanges2 / sizeof *dirtyRanges2]] isEqual:[HFRangeWrapper withRanges:cleanedRanges2 count:sizeof cleanedRanges2 / sizeof *cleanedRanges2]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges3 count:sizeof dirtyRanges3 / sizeof *dirtyRanges3]] isEqual:[HFRangeWrapper withRanges:cleanedRanges3 count:sizeof cleanedRanges3 / sizeof *cleanedRanges3]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges4 count:sizeof dirtyRanges4 / sizeof *dirtyRanges4]] isEqual:[HFRangeWrapper withRanges:cleanedRanges4 count:sizeof cleanedRanges4 / sizeof *cleanedRanges4]]);
    //NSLog(@"%@", [HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges4 count:sizeof dirtyRanges4 / sizeof *dirtyRanges4]]);
}

static NSUInteger random_upto(unsigned long long val) {
    if (val == 0) return 0;
    else return ll2l(random() % val);
}

#define DEBUG if (should_debug)  
+ (void)_testTextInsertion {
    const BOOL should_debug = NO;
    DEBUG puts("Beginning data insertion test");
    NSMutableData *expectedData = [NSMutableData data];
    HFController *controller = [[[HFController alloc] init] autorelease];
    [controller setByteArray:[[[HFFullMemoryByteArray alloc] init] autorelease]];
    NSUndoManager *undoer = [[[NSUndoManager alloc] init] autorelease];
    [undoer setGroupsByEvent:NO];
    [controller setUndoManager:undoer];
    NSMutableArray *expectations = [NSMutableArray arrayWithObject:[NSData data]];
    NSUInteger i, opCount = 5000;
    unsigned long long coalescerActionPoint = ULLONG_MAX;
    for (i=1; i <= opCount; i++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        const NSUInteger length = ll2l([controller contentsLength]);
        
        NSRange replacementRange = {0, 0};
        NSUInteger replacementDataLength = 0;
        while (replacementRange.length == 0 && replacementDataLength == 0) {
            replacementRange.location = random_upto(length);
            replacementRange.length = random_upto(length - replacementRange.location);
            replacementDataLength = random_upto(20);
        }
        NSData *replacementData = randomDataOfLength(replacementDataLength);
        [expectedData replaceBytesInRange:replacementRange withBytes:[replacementData bytes] length:[replacementData length]];
        
        HFRange selectedRange = HFRangeMake(replacementRange.location, replacementRange.length);
        
        BOOL shouldCoalesceDelete = (replacementDataLength == 0 && HFMaxRange(selectedRange) == coalescerActionPoint);
        BOOL shouldCoalesceInsert = (replacementRange.length == 0 && selectedRange.location == coalescerActionPoint);
        
        [controller setSelectedContentsRanges:[HFRangeWrapper withRanges:&selectedRange count:1]];
        HFTEST([[controller selectedContentsRanges] isEqual:[HFRangeWrapper withRanges:&selectedRange count:1]]);
        
        BOOL expectedCoalesced = (shouldCoalesceInsert || shouldCoalesceDelete);
        HFControllerCoalescedUndo *previousUndoCoalescer = [controller valueForKey:@"undoCoalescer"];
        /* If our changes should be coalesced, then we do not add an undo group, because it would just create an empty group that would interfere with our undo/redo tests below */
        if (! expectedCoalesced) [undoer beginUndoGrouping];
        
        [controller insertData:replacementData replacingPreviousBytes:0 allowUndoCoalescing:YES];
        BOOL wasCoalesced = ([controller valueForKey:@"undoCoalescer"] == previousUndoCoalescer);
        HFTEST(expectedCoalesced == wasCoalesced);
        
        HFTEST([[controller byteArray] _debugIsEqualToData:expectedData]);
        if (wasCoalesced) [expectations removeLastObject];
        [expectations addObject:[[expectedData copy] autorelease]];
        
        if (! expectedCoalesced) [undoer endUndoGrouping];
        
        [pool drain];
        
        coalescerActionPoint = HFSum(replacementRange.location, replacementDataLength);
    }
    
    NSUInteger expectationIndex = [expectations count] - 1;
    
    HFTEST([[controller byteArray] _debugIsEqualToData:[expectations objectAtIndex:expectationIndex]]);
    
    for (i=1; i <= opCount; i++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        NSInteger expectationIndexChange;
        if (expectationIndex == [expectations count] - 1) {
            expectationIndexChange = -1;
        }
        else if (expectationIndex == 0) {
            expectationIndexChange = 1;
        }
        else {
            expectationIndexChange = ((random() & 1) ? -1 : 1);
        }
        expectationIndex += expectationIndexChange;
        if (expectationIndexChange > 0) {
            DEBUG printf("About to redo %lu %lu\n", (unsigned long)i, (unsigned long)expectationIndex);
            HFTEST([undoer canRedo]);
            [undoer redo];
        }
        else {
            DEBUG printf("About to undo %lu %ld=u\n", (unsigned long)i, (unsigned long)expectationIndex);
            HFTEST([undoer canUndo]);
            [undoer undo]; 
        }
        
        DEBUG printf("Index %lu %lu\n", (unsigned long)i, (unsigned long)expectationIndex);
        HFTEST([[controller byteArray] _debugIsEqualToData:[expectations objectAtIndex:expectationIndex]]);
        
        [pool drain];
    }
    
    DEBUG puts("Done!");
}

+ (void)_testByteArray {
    const BOOL should_debug = NO;
    DEBUG puts("Beginning TAVL Tree test:");
    HFByteArray* first = [[[HFFullMemoryByteArray alloc] init] autorelease];
    HFBTreeByteArray* second = [[[HFBTreeByteArray alloc] init] autorelease];    
    
    //srandom(time(NULL));
    
    unsigned opCount = 50000;
    unsigned long long expectedLength = 0;
    unsigned i;
    for (i=1; i <= opCount; i++) {
        NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
        NSUInteger op;
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
        [pool drain];
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

static HFByteArray *byteArrayForFile(NSString *path) {
    HFFileReference *ref = [[[HFFileReference alloc] initWithPath:path error:NULL] autorelease];
    HFFileByteSlice *slice = [[[HFFileByteSlice alloc] initWithFile:ref] autorelease];
    HFByteArray *array = [[[HFBTreeByteArray alloc] init] autorelease];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    return array;
}

+ (void)_testByteArrayEditScripts {
    
    const BOOL should_debug = NO;
    NSMutableArray *byteArrays = [NSMutableArray array];
    unsigned long i, arrayCount = 4;
    
    HFByteArray *base = [[HFBTreeByteArray alloc] init];
    [byteArrays addObject:base];
    [base release];
    HFByteSlice *slice = [[HFRandomDataByteSlice alloc] initWithRandomDataLength:32 * 1024];
    [base insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    [slice release];
    unsigned long long baseLength = [base length];
    
    for (i=1; i < arrayCount; i++) {
        NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        HFByteArray *modified = [base mutableCopy];
        unsigned long long length = baseLength;
        
        NSUInteger j, opCount = 256;
        for (j=0; j < opCount; j++) {
            unsigned long long offset;
            unsigned long long number;
            NSUInteger op;
            switch ((op = (random()%2))) {
                case 0: { //insert
                    number = 1 + random() % 64;
                    offset = random() % (1 + length);
                    HFByteSlice* slice = [[HFRandomDataByteSlice alloc] initWithRandomDataLength:number];
                    DEBUG printf("%lu)\tInserting %llu bytes at %llu...", i, [slice length], offset);
                    [modified insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
                    [slice release];
                    length += number;
                    
                    break;
                }
                case 1: { //delete
                    if (length > 0) {
                        offset = random() % length;
                        number = 1 + (unsigned long long)sqrt(random() % (length - offset));
                        DEBUG printf("%lu)\tDeleting at %llu for %llu...", i, offset, number);
                        [modified deleteBytesInRange:HFRangeMake(offset, number)];
                        length -= number;
                    }
                    else DEBUG printf("%lu)\tLength of zero, no delete...", i);
                    break;
                }
            }
        }
        
        [byteArrays addObject:modified];
        [modified release];
        
        [pool drain];        
    }
    
    for (i=0; i < arrayCount; i++) {
        HFByteArray *src = [byteArrays objectAtIndex:i];
        NSUInteger j;
        for (j=0; j < arrayCount; j++) {
            HFByteArray *dst = [byteArrays objectAtIndex:j];
            printf("Tested %lu / %lu (lengths are %llu, %llu)\n", i * arrayCount + j, arrayCount * arrayCount, [src length], [dst length]);
            HFByteArrayEditScript *script = [[HFByteArrayEditScript alloc] initWithDifferenceFromSource:src toDestination:dst trackingProgress:nil];
            HFByteArray *guineaPig = [src mutableCopy];
            [script applyToByteArray:guineaPig];
            if ([dst _debugIsEqual:guineaPig]) {
                DEBUG printf("Edit script success with length %llu\n", [dst length]);
            }
            else {
                DEBUG printf("Error! Edit script failure with length %llu\n", [dst length]);
                exit(EXIT_FAILURE);
            }
            if (i == j) {
                /* Comparing an array to itself should always produce a 0 length script */
                HFTEST([script numberOfInstructions] == 0);
            }
            [script release];
            [guineaPig release];
        }
    }
}


+ (void)_testRandomOperationFileWriting {
    const BOOL should_debug = NO;
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    NSData *data = randomDataOfLength(1 << 16);
    NSURL *fileURL = [NSURL fileURLWithPath:@"/tmp/HexFiendTestFile.data"];
    NSURL *asideFileURL = [NSURL fileURLWithPath:@"/tmp/HexFiendTestFile_External.data"];
    if (! [data writeToURL:fileURL atomically:NO]) {
        [NSException raise:NSGenericException format:@"Unable to write test data to %@", fileURL];
    }
    HFFileReference *ref = [[[HFFileReference alloc] initWithPath:[fileURL path] error:NULL] autorelease];
    HFTEST([ref length] == [data length]);
    
    HFByteSlice *slice = [[[HFFileByteSlice alloc] initWithFile:ref] autorelease];
    
    HFByteArray *array = [[[preferredByteArrayClass() alloc] init] autorelease];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    HFTEST([HFHashByteArray(array) isEqual:HFHashFile(fileURL)]);
    
    NSUInteger i, op, opCount = 20;
    unsigned long long expectedLength = [data length];
    for (i=0; i < opCount; i++) {
        HFTEST([array length] == expectedLength);
        HFRange replacementRange;
        replacementRange.location = random_upto(expectedLength);
        replacementRange.length = random_upto(expectedLength - replacementRange.location);
        switch (op = (random() % 8)) {
            case 0: {
                /* insert */
                HFByteSlice *slice = [[[HFSharedMemoryByteSlice alloc] initWithUnsharedData:randomDataOfLength(random_upto(1000))] autorelease];
                [array insertByteSlice:slice inRange:replacementRange];
                expectedLength = expectedLength + [slice length] - replacementRange.length;
                DEBUG printf("%lu inserting %llu in {%llu, %llu}\n", (unsigned long)i, [slice length], replacementRange.location, replacementRange.length);
                break;
            }
            case 1: {
                /* delete */
                [array deleteBytesInRange:replacementRange];
                expectedLength -= replacementRange.length;
                DEBUG printf("%lu deleting in {%llu, %llu}\n", (unsigned long)i, replacementRange.location, replacementRange.length);
                break;
            }
            default: {
                /* transfer/delete */
                HFRange sourceRange;
                sourceRange.location = random_upto(expectedLength);
                sourceRange.length = random_upto(expectedLength - sourceRange.location);
                HFByteArray *subarray = [array subarrayWithRange:sourceRange];
                [array insertByteArray:subarray inRange:replacementRange];
                expectedLength = expectedLength + sourceRange.length - replacementRange.length;
                DEBUG printf("%lu moving {%llu, %llu} to {%llu, %llu}\n", (unsigned long)i, sourceRange.location, sourceRange.length, replacementRange.location, replacementRange.length);
                break;
            }
        }
    }
    
    //[array insertByteSlice:[[[HFSharedMemoryByteSlice alloc] initWithUnsharedData:[NSData dataWithBytes:"Z" length:1]] autorelease] inRange:HFRangeMake(0, 0)];
    
    NSData *arrayHash = HFHashByteArray(array);
    
    HFTEST([array writeToFile:asideFileURL trackingProgress:NULL error:NULL]);
    HFTEST([arrayHash isEqual:HFHashFile(asideFileURL)]);
    
    HFTEST([array writeToFile:fileURL trackingProgress:NULL error:NULL]);
    HFTEST([arrayHash isEqual:HFHashFile(fileURL)]);
    
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:NULL];
    [pool drain];
}

+ (void)_testBadPermissionsFileWriting {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    NSString *pathObj = @"/tmp/HexFiendErroneousData_Permissions.data";
    const char *path = [pathObj fileSystemRepresentation];
    NSURL *url = [NSURL fileURLWithPath:pathObj isDirectory:NO];
    NSData *data = randomDataOfLength(4 * 1024);
    [data writeToURL:url atomically:NO];
    chmod(path, 0400); //set permissions to read only, and only for owner
    
    // Try doubling the file.  Writing this should fail because it is read only.
    HFFileReference *ref = [[[HFFileReference alloc] initWithPath:pathObj error:NULL] autorelease];
    HFByteSlice *slice = [[[HFFileByteSlice alloc] initWithFile:ref] autorelease];
    HFByteArray *array = [[[HFBTreeByteArray alloc] init] autorelease];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    
    NSError *error = nil;
    BOOL writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    HFTEST(writeResult == NO);
    HFTEST(error != nil);
    HFTEST([[error domain] isEqual:NSCocoaErrorDomain]);
    HFTEST([error code] == NSFileReadNoPermissionError);
    
    chmod(path, 0644);
    error = nil;
    writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    HFTEST(writeResult == YES);
    HFTEST(error == nil);
    
    unlink(path);
    
    [pathObj self]; //make sure this sticks around under GC for its filesystemRepresentation
    [pool drain];
}

+ (void)_testBadLengthFileWriting {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    NSString *pathObj = @"/tmp/HexFiendErroneousData_Length.data";
    const char *path = [pathObj fileSystemRepresentation];
    NSURL *url = [NSURL fileURLWithPath:pathObj isDirectory:NO];
    NSData *data = randomDataOfLength(4 * 1024);
    [data writeToURL:url atomically:NO];
    
    HFByteSlice *slice = [[[HFRandomDataByteSlice alloc] initWithRandomDataLength:(1ULL << 42 /* 4 terabytes*/)] autorelease];
    HFByteArray *array = [[[HFBTreeByteArray alloc] init] autorelease];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    
    NSError *error = nil;
    BOOL writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    HFTEST(writeResult == NO);
    HFTEST(error != nil);
    HFTEST([[error domain] isEqual:NSCocoaErrorDomain]);
    HFTEST([error code] == NSFileWriteOutOfSpaceError);
    
    unlink(path);
    
    [pathObj self]; //make sure this sticks around under GC for its filesystemRepresentation
    [pool drain];
}


+ (void)_testPermutationFileWriting {
    const BOOL should_debug = NO;
    
    NSUInteger iteration = 10;
    
    while (iteration--) {
        NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
        
#define BLOCK_SIZE (16 * 1024)
#define BLOCK_COUNT 64
        
        /* Construct an enumeration */
        NSUInteger permutation[BLOCK_COUNT];
        NSUInteger p;
        for (p=0; p < BLOCK_COUNT; p++) permutation[p] = p;
        while (p > 1) {
            p--;
            NSUInteger k = random() % (p + 1);
            NSUInteger tmp = permutation[k];
            permutation[k] = permutation[p];
            permutation[p] = tmp;
        }
        
        NSData *data = randomDataOfLength(BLOCK_COUNT * BLOCK_SIZE);
        NSURL *fileURL = [NSURL fileURLWithPath:@"/tmp/HexFiendTestFile.data"];
        NSURL *asideFileURL = [NSURL fileURLWithPath:@"/tmp/HexFiendTestFile_External.data"];
        if (! [data writeToURL:fileURL atomically:NO]) {
            [NSException raise:NSGenericException format:@"Unable to write test data to %@", fileURL];
        }
        HFFileReference *ref = [[[HFFileReference alloc] initWithPath:[fileURL path] error:NULL] autorelease];
        HFTEST([ref length] == [data length]);
        
        HFByteSlice *slice = [[[HFFileByteSlice alloc] initWithFile:ref] autorelease];
        
        HFByteArray *array = [[[preferredByteArrayClass() alloc] init] autorelease];
        
        for (p=0; p < BLOCK_COUNT; p++) {
            NSUInteger index = permutation[p];
            HFByteSlice *subslice = [slice subsliceWithRange:HFRangeMake(index * BLOCK_SIZE, BLOCK_SIZE)];
            [array insertByteSlice:subslice inRange:HFRangeMake([array length], 0)];
        }
        NSData *arrayHash = HFHashByteArray(array);
        
        HFTEST([array writeToFile:asideFileURL trackingProgress:NULL error:NULL]);
        HFTEST([arrayHash isEqual:HFHashFile(asideFileURL)]);
        
        HFTEST([array writeToFile:fileURL trackingProgress:NULL error:NULL]);
        NSDate *startDate = [NSDate date];
        HFTEST([arrayHash isEqual:HFHashFile(fileURL)]);	
        NSTimeInterval diff = [startDate timeIntervalSinceNow];
        
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:NULL];
        
        [pool drain];
    }
}

+ (void)_testByteSearching {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSUInteger round;
    for (round = 0; round < 24; round++) {
        HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
        HFByteSlice *rootSlice = [[[HFRepeatingDataByteSlice alloc] initWithRepeatingDataLength: 1 << 20] autorelease];
        [byteArray insertByteSlice:rootSlice inRange:HFRangeMake(0, 0)];
        
        NSData *needleData = randomDataOfLength(32 + random_upto(63));
        HFByteSlice *needleSlice = [[[HFSharedMemoryByteSlice alloc] initWithUnsharedData:needleData] autorelease];
        HFByteArray *needle = [[[preferredByteArrayClass() alloc] init] autorelease];
        [needle insertByteSlice:needleSlice inRange:HFRangeMake(0, 0)];
        
        [HFByteArray _testSearchAlgorithmsLookingForArray:needle inArray:byteArray];
        
        [byteArray insertByteSlice:needleSlice inRange:HFRangeMake(random_upto(1 << 15), 0)];
        [HFByteArray _testSearchAlgorithmsLookingForArray:needle inArray:byteArray];
        
        [byteArray insertByteSlice:needleSlice inRange:HFRangeMake([byteArray length] - random_upto(1 << 15), 0)];
        [HFByteArray _testSearchAlgorithmsLookingForArray:needle inArray:byteArray];
        
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
    }
    [pool drain];
}

+ (void)_testIndexSet {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSMutableIndexSet *nsindexset = [[NSMutableIndexSet alloc] init];
    HFMutableIndexSet *hfindexset = [[HFMutableIndexSet alloc] init];
    unsigned long round, roundCount = 4096 * 4;
    const NSUInteger supportedIndexEnd = NSNotFound;
    for (round = 0; round < 4096 * 4; round++) {
        if (round % (roundCount / 8) == 0) printf("Index set test %lu / %lu\n", round, roundCount);
        BOOL insert = ([nsindexset count] == 0 || (random() % 2));
        NSUInteger end = 1 + (random() % supportedIndexEnd);
        NSUInteger start = 1 + (random() % supportedIndexEnd);
        if (end < start) {
            NSUInteger temp = end;
            end = start;
            start = temp;
        }
        if (insert) {
            [nsindexset addIndexesInRange:NSMakeRange(start, end - start)];
            [hfindexset addIndexesInRange:HFRangeMake(start, end - start)];
        }
        else {
            [nsindexset removeIndexesInRange:NSMakeRange(start, end - start)];
            [hfindexset removeIndexesInRange:HFRangeMake(start, end - start)];	    
        }
        
        [hfindexset verifyIntegrity];
        HFASSERT([hfindexset isEqualToNSIndexSet:nsindexset]);
        
        if ([nsindexset count] > 0) {
            NSInteger amountToShift;
            NSUInteger indexToShift;
            if (random() % 2 && [nsindexset firstIndex] > 0) {
                /* Shift left */
                amountToShift = (1 + random() % [nsindexset firstIndex]);
                indexToShift = amountToShift + (random() % (supportedIndexEnd - amountToShift));
                
                [nsindexset shiftIndexesStartingAtIndex:indexToShift by:-amountToShift];
                [hfindexset shiftValuesLeftByAmount:amountToShift startingAtValue:indexToShift];
            }
            else if ([nsindexset lastIndex] + 1 < supportedIndexEnd) {
                /* Shift right */
                NSUInteger maxAmountToShift = (supportedIndexEnd - 1 - [nsindexset lastIndex]);
                amountToShift = (1 + random() % maxAmountToShift);
                indexToShift = random() % (1 + [nsindexset lastIndex]);
                
                [nsindexset shiftIndexesStartingAtIndex:indexToShift by:amountToShift];
                [hfindexset shiftValuesRightByAmount:amountToShift startingAtValue:indexToShift];
            }
        }
        
        HFASSERT([hfindexset isEqualToNSIndexSet:nsindexset]);
    }
    [pool drain];
}

static HFRange randomRange(uint32_t max) {
    HFASSERT(max <= RAND_MAX);
    uint32_t start, end;
    do {
        start = (uint32_t)(random() % max);
        end = (uint32_t)(random() % max);
    } while (start == end);
    if (end < start) {
        uint32_t tmp = end;
        end = start;
        start = tmp;
    }
    return HFRangeMake(start, end - start);
}

+ (void)_testAnnotatedTree {
    HFByteRangeAttributeArray *naiveTree = [[HFNaiveByteRangeAttributeArray alloc] init];
    HFAnnotatedTreeByteRangeAttributeArray *smartTree = [[HFAnnotatedTreeByteRangeAttributeArray alloc] init];
    
    NSString * const attributes[3] = {@"Alpha", @"Beta", @"Gamma"};
    BOOL log = NO;
    unsigned long round;
    for (round = 0; round < 128 * 6; round++) {
        NSString *attribute = attributes[random() % (sizeof attributes / sizeof *attributes)];
        if (round % 128 == 0) printf("%s %lu\n", sel_getName(_cmd), round);
        BOOL insert = ([smartTree isEmpty] || (random() % 2));

        HFRange range = randomRange(4096);
        
        if (log) NSLog(@"Round %lu", round);
        if (insert) {
            if (log) NSLog(@"Add %@ in %@", attribute, HFRangeToString(range));
            [naiveTree addAttribute:attribute range:range];
            [smartTree addAttribute:attribute range:range];
        }
        else {
            if (log) NSLog(@"Remove %@ in %@", attribute, HFRangeToString(range));
            [naiveTree removeAttribute:attribute range:range];
            [smartTree removeAttribute:attribute range:range];
        }
        HFASSERT([naiveTree isEqual:smartTree]);
        
        /* Test copying */
        id copied = [smartTree mutableCopy];
        HFASSERT([copied isEqual:smartTree]);
        [copied release];
        
        /* Test replacements */
        HFRange range1 = randomRange(4096);
        uint32_t length1 = (uint32_t)(random() % 4096);
        [naiveTree byteRange:range1 wasReplacedByBytesOfLength:length1];
        [smartTree byteRange:range1 wasReplacedByBytesOfLength:length1];
        HFASSERT([naiveTree isEqual:smartTree]);
    }
    
    [naiveTree release];
    [smartTree release];
}

+ (void)_testObjectGraph {
    /* HFObjectGraph runs its own tests */
    [NSClassFromString(@"HFObjectGraph") self];
}

static void exception_thrown(const char *methodName, NSException *exception) {
    printf("Test %s threw exception %s\n", methodName, [[exception description] UTF8String]);
    puts("I'm bailing out.  Better luck next time.");
    exit(0);
}

+ (void)_runTest:(const char *)test {
    printf("Running %s...", test);
    fflush(0);
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    @try {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [self performSelector:sel_registerName(test)];
        [pool drain];
    }
    @catch (NSException *localException) {
        exception_thrown(test, localException);
    }
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    printf("done in %.02f seconds.\n", end - start);
}

+ (void)runAllTests {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    BOOL enableTest = YES;
    if (enableTest) [self _runTest:"_testFastMemchr"];
    if (enableTest) [self _runTest:"_testRangeFunctions"];
    if (enableTest) [self _runTest:"_testByteArray"];
    if (enableTest) [self _runTest:"_testByteArrayEditScripts"];
    if (enableTest) [self _runTest:"_testTextInsertion"];
    if (enableTest) [self _runTest:"_testTextInsertion"];
    if (enableTest) [self _runTest:"_testObjectGraph"];
    if (enableTest) [self _runTest:"_testRandomOperationFileWriting"];
    if (enableTest) [self _runTest:"_testPermutationFileWriting"];
    if (enableTest) [self _runTest:"_testBadPermissionsFileWriting"];
    if (enableTest) [self _runTest:"_testBadLengthFileWriting"];
    if (enableTest) [self _runTest:"_testByteSearching"];
    if (enableTest) [self _runTest:"_testIndexSet"];
    if (enableTest) [self _runTest:"_testAnnotatedTree"];
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    printf("Unit tests completed in %.02f seconds\n", end - start);
}


@end

#endif
