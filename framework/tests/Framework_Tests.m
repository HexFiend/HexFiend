//
//  HFUnitTests.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <XCTest/XCTest.h>
#include <sys/stat.h>

#import <HexFiend/HexFiend.h>
#import <HexFiend/HFFastMemchr.h>
#import "HFByteArray_Internal.h"
#import "HFTestHashing.h"
#import <HexFiend/HFByteArrayEditScript.h>
#import "HFRandomDataByteSlice.h"

#import "HFTest.h"

@interface HFFrameworkTests : XCTestCase
@end

@implementation HFFrameworkTests

static inline Class preferredByteArrayClass(void) {
    return [HFBTreeByteArray class];
}

static HFByteArray *byteArrayForFile(NSString *path, HFFileReference **outref) {
    HFFileReference *ref = [[HFFileReference alloc] initWithPath:path error:NULL];
    HFFileByteSlice *slice = [[HFFileByteSlice alloc] initWithFile:ref];
    HFByteArray *array = [[preferredByteArrayClass() alloc] init];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    if(outref) *outref = ref;
    return array;
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

static NSString *randTmpFileName(NSString *name) {
    NSUInteger dot = [name rangeOfString:@"." options:NSBackwardsSearch].location;
    if(dot == NSNotFound) {
        return [NSString stringWithFormat:@"/tmp/HexFiendTest_%@_%x", name, arc4random()];
    } else {
        return [NSString stringWithFormat:@"/tmp/HexFiendTest_%@_%x.%@", [name substringToIndex:dot], arc4random(), [name substringFromIndex:dot+1]];
    }
}

- (void)testFastMemchr {
    unsigned char searchChar = 0xAE;
    unsigned char fillerChar = 0x23;
    const NSUInteger baseOffsets[] = {0, 16, 32, 57, 93, 128, 255, 1017, 2297, 3000, 3152, 4092, 4094, 4095};
    const NSUInteger buffLen = 4099;
    unsigned char *buff = malloc(buffLen);
    XCTAssert(buff != NULL);
    [randomDataOfLength(buffLen) getBytes:buff length:buffLen];
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
            unsigned short tempMask = (unsigned short)mask;
            while (tempMask != 0) {
                int lsb = __builtin_ffs(tempMask) - 1;
                buff[baseOffset + lsb] = searchChar;
                tempMask &= (tempMask - 1);
            }
            XCTAssert(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
            memcpy(buff + baseOffset, stored, sizeof stored);
        }
    }
    
    NSUInteger remaining = buffLen;
    while (remaining--) {
        buff[remaining] = searchChar;
        XCTAssert(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
    }
    remaining = buffLen;
    while (remaining--) {
        buff[remaining] = fillerChar;
        XCTAssert(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
    }
}

- (void)testRangeFunctions {
    HFRange range = HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL);
    XCTAssert(range.location == UINT_MAX + 573ULL && range.length == UINT_MAX * 2ULL);
    XCTAssert(range.location == UINT_MAX + 573ULL && range.length == UINT_MAX * 2ULL);
    XCTAssert(HFRangeIsSubrangeOfRange(range, range));
    XCTAssert(HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), range));
    XCTAssert(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length, 0), range));
    XCTAssert(HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), HFRangeMake(range.location, 0)));
    XCTAssert(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), HFRangeMake(range.location + 1, 0)));
    XCTAssert(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + 6, 0), range));
    XCTAssert(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length, 0), range));
    XCTAssert(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length + 1, 0), range));
    XCTAssert(! HFRangeIsSubrangeOfRange(range, HFRangeMake(34, 0)));
    XCTAssert(HFRangeIsSubrangeOfRange(range, HFRangeMake(range.location - 32, range.length + 54)));
    XCTAssert(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, ULLONG_MAX)));
    XCTAssert(! HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 23), HFRangeMake(ULLONG_MAX - 3, 23)));
    XCTAssert(HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 22), HFRangeMake(ULLONG_MAX - 3, 23)));
    
    XCTAssert(HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL)));
    XCTAssert(! HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL + 1)));
    
    XCTAssert(HFIntersectsRange(range, HFRangeMake(UINT_MAX + 3ULL, UINT_MAX * 2ULL + 1)));
    XCTAssert(! HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(3, 0)));
    XCTAssert(! HFIntersectsRange(HFRangeMake(3, 0), HFRangeMake(3, 0)));
    XCTAssert(HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(3, 3)));
    XCTAssert(! HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(6, 0)));
    
    XCTAssert(HFRangeEqualsRange(HFIntersectionRange(range, range), range));
    XCTAssert(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(0, 25), HFRangeMake(10, 11)), HFRangeMake(10, 11)));
    XCTAssert(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(15, 10)), HFRangeMake(15, 6)));
    XCTAssert(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(150, 10)), HFRangeMake(0, 0)));
    XCTAssert(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(0, 25), HFRangeMake(10, 11)), HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(0, 25))));
    XCTAssert(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(15, 10)), HFIntersectionRange(HFRangeMake(15, 10), HFRangeMake(10, 11))));
    XCTAssert(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(150, 10)), HFIntersectionRange(HFRangeMake(150, 10), HFRangeMake(10, 11))));
    
    XCTAssert(HFRangeEqualsRange(HFUnionRange(HFRangeMake(1, 3), HFRangeMake(2, 3)), HFRangeMake(1, 4)));
    XCTAssert(HFRangeEqualsRange(HFUnionRange(HFRangeMake(1, 3), HFRangeMake(4, 4)), HFRangeMake(1, 7)));
    
    XCTAssert(HFSumDoesNotOverflow(ULLONG_MAX, 0));
    XCTAssert(! HFSumDoesNotOverflow(ULLONG_MAX, 1));
    XCTAssert(HFSumDoesNotOverflow(ULLONG_MAX / 2, ULLONG_MAX / 2));
    XCTAssert(HFSumDoesNotOverflow(0, 0));
    XCTAssert(ll2l((unsigned long long)UINT_MAX) == UINT_MAX);
    
    XCTAssert(HFRoundUpToNextMultipleSaturate(0, 2) == 2);
    XCTAssert(HFRoundUpToNextMultipleSaturate(2, 2) == 4);
    XCTAssert(HFRoundUpToNextMultipleSaturate(200, 200) == 400);
    XCTAssert(HFRoundUpToNextMultipleSaturate(1304, 600) == 1800);
    XCTAssert(HFRoundUpToNextMultipleSaturate(ULLONG_MAX - 13, 100) == ULLONG_MAX);
    XCTAssert(HFRoundUpToNextMultipleSaturate(ULLONG_MAX, 100) == ULLONG_MAX);
    
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

- (void)testTextInsertion {
    dbg_printf("Beginning data insertion test\n");
    NSMutableData *expectedData = [NSMutableData data];
    HFController *controller = [[HFController alloc] init];
    [controller setByteArray:[[HFFullMemoryByteArray alloc] init]];
    NSUndoManager *undoer = [[NSUndoManager alloc] init];
    [undoer setGroupsByEvent:NO];
    [controller setUndoManager:undoer];
    NSMutableArray *expectations = [NSMutableArray arrayWithObject:[NSData data]];
    NSUInteger i, opCount = 5000;
    unsigned long long coalescerActionPoint = ULLONG_MAX;
    for (i=1; i <= opCount; i++) @autoreleasepool {
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
        XCTAssert([[controller selectedContentsRanges] isEqual:[HFRangeWrapper withRanges:&selectedRange count:1]]);
        
        BOOL expectedCoalesced = (shouldCoalesceInsert || shouldCoalesceDelete);
        HFControllerCoalescedUndo *previousUndoCoalescer = [controller valueForKey:@"undoCoalescer"];
        /* If our changes should be coalesced, then we do not add an undo group, because it would just create an empty group that would interfere with our undo/redo tests below */
        if (! expectedCoalesced) [undoer beginUndoGrouping];
        
        [controller insertData:replacementData replacingPreviousBytes:0 allowUndoCoalescing:YES];
        BOOL wasCoalesced = ([controller valueForKey:@"undoCoalescer"] == previousUndoCoalescer);
        XCTAssert(expectedCoalesced == wasCoalesced);
        
        XCTAssert([[controller byteArray] _debugIsEqualToData:expectedData]);
        if (wasCoalesced) [expectations removeLastObject];
        [expectations addObject:[expectedData copy]];
        
        if (! expectedCoalesced) [undoer endUndoGrouping];
        
        coalescerActionPoint = HFSum(replacementRange.location, replacementDataLength);
    }
    
    NSUInteger expectationIndex = [expectations count] - 1;
    
    XCTAssert([[controller byteArray] _debugIsEqualToData:expectations[expectationIndex]]);
    
    for (i=1; i <= opCount; i++) @autoreleasepool {
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
            dbg_printf("About to redo %lu %lu\n", (unsigned long)i, (unsigned long)expectationIndex);
            XCTAssert([undoer canRedo]);
            [undoer redo];
        }
        else {
            dbg_printf("About to undo %lu %ld=u\n", (unsigned long)i, (unsigned long)expectationIndex);
            XCTAssert([undoer canUndo]);
            [undoer undo];
        }
        
        dbg_printf("Index %lu %lu\n", (unsigned long)i, (unsigned long)expectationIndex);
        XCTAssert([[controller byteArray] _debugIsEqualToData:expectations[expectationIndex]]);
    }
    
    dbg_printf("Done!\n");
}

- (void)testByteArray {
    dbg_printf("Beginning TAVL Tree test:\n");
    HFByteArray* first = [[HFFullMemoryByteArray alloc] init];
    HFBTreeByteArray* second = [[HFBTreeByteArray alloc] init];
    
    unsigned opCount = 50000;
    unsigned long long expectedLength = 0;
    unsigned i;
    for (i=1; i <= opCount; i++) @autoreleasepool {
        NSUInteger op;
        const unsigned long long length = [first length];
        unsigned long long offset;
        unsigned long long number;
        switch ((op = (random()%2))) {
            case 0: { //insert
                NSData *data = randomDataOfLength(1 + random()%1000);
                offset = random() % (1 + length);
                HFByteSlice* slice = [[HFFullMemoryByteSlice alloc] initWithData:data];
                dbg_printf("%u)\tInserting %llu bytes at %llu...", i, [slice length], offset);
                [first insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
                [second insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
                expectedLength += [data length];
                break;
            }
            case 1: { //delete
                if (length > 0) {
                    offset = random() % length;
                    number = 1 + random() % (length - offset);
                    dbg_printf("%u)\tDeleting at %llu for %llu...", i, offset, number);
                    [first deleteBytesInRange:HFRangeMake(offset, number)];
                    [second deleteBytesInRange:HFRangeMake(offset, number)];
                    expectedLength -= number;
                }
                else dbg_printf("%u)\tLength of zero, no delete...", i);
                break;
            }
        }
        fflush(NULL);
        XCTAssert([first _debugIsEqual:second], @"Expected length: %llu mem length: %llu tavl length:%llu desc: %s\n", expectedLength, [first length], [second length], [[second description] UTF8String]);
        dbg_printf("Pass, length: %llu\t%s\n", [second length], [[second description] UTF8String]);
    }
    dbg_printf("Done!\n");
    dbg_printf("%s\n", [[second description] UTF8String]);
}

- (void)testByteArrayEditScripts {
    NSMutableArray *byteArrays = [NSMutableArray array];
    unsigned long i, arrayCount = 4;
    
    HFByteArray *base = [[HFBTreeByteArray alloc] init];
    [byteArrays addObject:base];
    HFByteSlice *slice = [[HFRandomDataByteSlice alloc] initWithRandomDataLength:32 * 1024];
    [base insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    unsigned long long baseLength = [base length];
    
    for (i=1; i < arrayCount; i++) @autoreleasepool {
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
                    HFByteSlice* mslice = [[HFRandomDataByteSlice alloc] initWithRandomDataLength:number];
                    dbg_printf("%lu)\tInserting %llu bytes at %llu...", i, [mslice length], offset);
                    [modified insertByteSlice:mslice inRange:HFRangeMake(offset, 0)];
                    length += number;
                    
                    break;
                }
                case 1: { //delete
                    if (length > 0) {
                        offset = random() % length;
                        number = 1 + (unsigned long long)sqrt(random() % (length - offset));
                        dbg_printf("%lu)\tDeleting at %llu for %llu...", i, offset, number);
                        [modified deleteBytesInRange:HFRangeMake(offset, number)];
                        length -= number;
                    }
                    else dbg_printf("%lu)\tLength of zero, no delete...", i);
                    break;
                }
            }
        }
        
        [byteArrays addObject:modified];
    }
    
    for (i=0; i < arrayCount; i++) {
        HFByteArray *src = byteArrays[i];
        NSUInteger j;
        for (j=0; j < arrayCount; j++) {
            HFByteArray *dst = byteArrays[j];
            dbg_printf("Tested %lu / %lu (lengths are %llu, %llu)\n", i * arrayCount + j, arrayCount * arrayCount, [src length], [dst length]);
            HFByteArrayEditScript *script = [[HFByteArrayEditScript alloc] initWithDifferenceFromSource:src toDestination:dst onlyReplace:NO skipOneByteMatches:NO trackingProgress:nil];
            HFByteArray *guineaPig = [src mutableCopy];
            [script applyToByteArray:guineaPig];

            XCTAssert([dst _debugIsEqual:guineaPig], @"Edit script failure with length %llu\n", [dst length]);
            dbg_printf("Edit script success with length %llu\n", [dst length]);
            
            if (i == j) {
                /* Comparing an array to itself should always produce a 0 length script */
                XCTAssert([script numberOfInstructions] == 0);
            }
        }
    }
}


- (void)testRandomOperationFileWriting {
    NSData *data = randomDataOfLength(1 << 16);
    NSURL *fileURL = [NSURL fileURLWithPath:randTmpFileName(@"File.data")];
    NSURL *asideFileURL = [NSURL fileURLWithPath:randTmpFileName(@"External.data")];
    if (! [data writeToURL:fileURL atomically:NO]) {
        [NSException raise:NSGenericException format:@"Unable to write test data to %@", fileURL];
    }
    
    HFFileReference *ref;
    HFByteArray *array = byteArrayForFile([fileURL path], &ref);
    XCTAssert([ref length] == [data length]);
    XCTAssert([HFHashByteArray(array) isEqual:HFHashFile(fileURL)]);
    
    NSUInteger i, op, opCount = 20;
    unsigned long long expectedLength = [data length];
    for (i=0; i < opCount; i++) {
        XCTAssert([array length] == expectedLength);
        HFRange replacementRange;
        replacementRange.location = random_upto(expectedLength);
        replacementRange.length = random_upto(expectedLength - replacementRange.location);
        switch (op = (random() % 8)) {
            case 0: {
                /* insert */
                HFByteSlice *slice = [[HFSharedMemoryByteSlice alloc] initWithUnsharedData:randomDataOfLength(random_upto(1000))];
                [array insertByteSlice:slice inRange:replacementRange];
                expectedLength = expectedLength + [slice length] - replacementRange.length;
                dbg_printf("%lu inserting %llu in {%llu, %llu}\n", (unsigned long)i, [slice length], replacementRange.location, replacementRange.length);
                break;
            }
            case 1: {
                /* delete */
                [array deleteBytesInRange:replacementRange];
                expectedLength -= replacementRange.length;
                dbg_printf("%lu deleting in {%llu, %llu}\n", (unsigned long)i, replacementRange.location, replacementRange.length);
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
                dbg_printf("%lu moving {%llu, %llu} to {%llu, %llu}\n", (unsigned long)i, sourceRange.location, sourceRange.length, replacementRange.location, replacementRange.length);
                break;
            }
        }
    }
    
    //[array insertByteSlice:[[[HFSharedMemoryByteSlice alloc] initWithUnsharedData:[NSData dataWithBytes:"Z" length:1]] autorelease] inRange:HFRangeMake(0, 0)];
    
    NSData *arrayHash = HFHashByteArray(array);
    
    XCTAssert([array writeToFile:asideFileURL trackingProgress:NULL error:NULL]);
    XCTAssert([arrayHash isEqual:HFHashFile(asideFileURL)]);
    
    XCTAssert([array writeToFile:fileURL trackingProgress:NULL error:NULL]);
    XCTAssert([arrayHash isEqual:HFHashFile(fileURL)]);
    
    [[NSFileManager defaultManager] removeItemAtURL:fileURL error:NULL];
}

- (void)testBadPermissionsFileWriting {
    NSString *pathObj = randTmpFileName(@"BadPerms.data");
    const char *path = [pathObj fileSystemRepresentation];
    NSURL *url = [NSURL fileURLWithPath:pathObj isDirectory:NO];
    NSData *data = randomDataOfLength(4 * 1024);
    [data writeToURL:url atomically:NO];
    chmod(path, 0400); //set permissions to read only, and only for owner
    
    // Try doubling the file.  Writing this should fail because it is read only.
    HFFileReference *ref = [[HFFileReference alloc] initWithPath:pathObj error:NULL];
    HFByteSlice *slice = [[HFFileByteSlice alloc] initWithFile:ref];
    HFByteArray *array = [[HFBTreeByteArray alloc] init];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    
    NSError *error = nil;
    BOOL writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    XCTAssert(writeResult == NO);
    XCTAssert(error != nil);
    XCTAssert([[error domain] isEqual:NSCocoaErrorDomain]);
    XCTAssert([error code] == NSFileReadNoPermissionError);
    
    chmod(path, 0644);
    error = nil;
    writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    XCTAssert(writeResult == YES);
    XCTAssert(error == nil);
    
    unlink(path);
    
    [pathObj self]; //make sure this sticks around under GC for its filesystemRepresentation
}

- (void)testBadLengthFileWriting {
    NSString *pathObj = randTmpFileName(@"BadLength.data");
    const char *path = [pathObj fileSystemRepresentation];
    NSURL *url = [NSURL fileURLWithPath:pathObj isDirectory:NO];
    NSData *data = randomDataOfLength(4 * 1024);
    [data writeToURL:url atomically:NO];
    
    HFByteSlice *slice = [[HFRandomDataByteSlice alloc] initWithRandomDataLength:(1ULL << 42 /* 4 terabytes*/)];
    HFByteArray *array = [[HFBTreeByteArray alloc] init];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    
    NSError *error = nil;
    BOOL writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    XCTAssert(writeResult == NO);
    XCTAssert(error != nil);
    XCTAssert([[error domain] isEqual:NSCocoaErrorDomain]);
    XCTAssert([error code] == NSFileWriteOutOfSpaceError);
    
    unlink(path);
}


- (void)testPermutationFileWriting {
    NSUInteger iteration = 10;
    
    while (iteration--) @autoreleasepool {
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
        NSURL *fileURL = [NSURL fileURLWithPath:randTmpFileName(@"File.data")];
        NSURL *asideFileURL = [NSURL fileURLWithPath:randTmpFileName(@"External.data")];
        if (! [data writeToURL:fileURL atomically:NO]) {
            [NSException raise:NSGenericException format:@"Unable to write test data to %@", fileURL];
        }
        HFFileReference *ref = [[HFFileReference alloc] initWithPath:[fileURL path] error:NULL];
        XCTAssert([ref length] == [data length]);
        
        HFByteSlice *slice = [[HFFileByteSlice alloc] initWithFile:ref];
        HFByteArray *array = [[preferredByteArrayClass() alloc] init];
        
        for (p=0; p < BLOCK_COUNT; p++) {
            NSUInteger index = permutation[p];
            HFByteSlice *subslice = [slice subsliceWithRange:HFRangeMake(index * BLOCK_SIZE, BLOCK_SIZE)];
            [array insertByteSlice:subslice inRange:HFRangeMake([array length], 0)];
        }
        NSData *arrayHash = HFHashByteArray(array);
        
        XCTAssert([array writeToFile:asideFileURL trackingProgress:NULL error:NULL]);
        XCTAssert([arrayHash isEqual:HFHashFile(asideFileURL)]);
        
        XCTAssert([array writeToFile:fileURL trackingProgress:NULL error:NULL]);
        XCTAssert([arrayHash isEqual:HFHashFile(fileURL)]);
        
        [[NSFileManager defaultManager] removeItemAtURL:fileURL error:NULL];
    }
}

static void HFByteArray_testSearchAlgorithms(XCTestCase *self, HFByteArray *needle, HFByteArray *haystack) {
    HFRange fullRange = HFRangeMake(0, [haystack length]);
    HFRange partialRange = HFRangeMake(fullRange.location + 10, fullRange.length - 10);
    unsigned long long result1, result2;
    
    result1 = [haystack _byteSearchBoyerMoore:needle inRange:fullRange forwards:YES trackingProgress:nil];
    result2 = [haystack _byteSearchRollingHash:needle inRange:fullRange forwards:YES trackingProgress:nil];
    XCTAssert(result1 == result2);
    
    result1 = [haystack _byteSearchBoyerMoore:needle inRange:fullRange forwards:NO trackingProgress:nil];
    result2 = [haystack _byteSearchRollingHash:needle inRange:fullRange forwards:NO trackingProgress:nil];
    XCTAssert(result1 == result2);
    
    result1 = [haystack _byteSearchBoyerMoore:needle inRange:partialRange forwards:YES trackingProgress:nil];
    result2 = [haystack _byteSearchRollingHash:needle inRange:partialRange forwards:YES trackingProgress:nil];
    XCTAssert(result1 == result2);
    
    result1 = [haystack _byteSearchBoyerMoore:needle inRange:partialRange forwards:NO trackingProgress:nil];
    result2 = [haystack _byteSearchRollingHash:needle inRange:partialRange forwards:NO trackingProgress:nil];
    XCTAssert(result1 == result2);
}

- (void)testByteSearching {
    NSUInteger round;
    for (round = 0; round < 24; round++) @autoreleasepool {
        HFByteArray *byteArray = [[preferredByteArrayClass() alloc] init];
        HFByteSlice *rootSlice = [[HFRepeatingDataByteSlice alloc] initWithRepeatingDataLength: 1 << 20];
        [byteArray insertByteSlice:rootSlice inRange:HFRangeMake(0, 0)];
        
        NSData *needleData = randomDataOfLength(32 + random_upto(63));
        HFByteSlice *needleSlice = [[HFSharedMemoryByteSlice alloc] initWithUnsharedData:needleData];
        HFByteArray *needle = [[preferredByteArrayClass() alloc] init];
        [needle insertByteSlice:needleSlice inRange:HFRangeMake(0, 0)];
        
        HFByteArray_testSearchAlgorithms(self, needle, byteArray);
        
        [byteArray insertByteSlice:needleSlice inRange:HFRangeMake(random_upto(1 << 15), 0)];
        HFByteArray_testSearchAlgorithms(self, needle, byteArray);
        
        [byteArray insertByteSlice:needleSlice inRange:HFRangeMake([byteArray length] - random_upto(1 << 15), 0)];
        HFByteArray_testSearchAlgorithms(self, needle, byteArray);
    }
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

- (void)testAnnotatedTree {
    HFByteRangeAttributeArray *naiveTree = [[HFNaiveByteRangeAttributeArray alloc] init];
    HFAnnotatedTreeByteRangeAttributeArray *smartTree = [[HFAnnotatedTreeByteRangeAttributeArray alloc] init];
    
    NSString * const attributes[3] = {@"Alpha", @"Beta", @"Gamma"};
    BOOL log = NO;
    unsigned long round;
    for (round = 0; round < 128 * 6; round++) {
        NSString *attribute = attributes[random() % (sizeof attributes / sizeof *attributes)];
        //if (round % 128 == 0) printf("%s %lu\n", sel_getName(_cmd), round);
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
        
        /* Test replacements */
        HFRange range1 = randomRange(4096);
        uint32_t length1 = (uint32_t)(random() % 4096);
        [naiveTree byteRange:range1 wasReplacedByBytesOfLength:length1];
        [smartTree byteRange:range1 wasReplacedByBytesOfLength:length1];
        HFASSERT([naiveTree isEqual:smartTree]);
    }
}

- (void)testObjectGraph {
    /* HFObjectGraph runs its own tests */
    [NSClassFromString(@"HFObjectGraph") runHFUnitTests:^(const char *file, NSUInteger line, NSString *expr, NSString *msg) {
        _XCTPreformattedFailureHandler(self, YES, @(file), line, expr, msg);
    }];
}

- (void)setUp {
    [super setUp];
    srandom(0xBEBAFECA);
}

- (void)tearDown {
    [super tearDown];
}


@end
