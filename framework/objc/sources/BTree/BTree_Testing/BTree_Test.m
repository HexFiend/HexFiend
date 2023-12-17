#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "NaiveArray.h"
#import "HFBTree.h"
#import "TreeEntry.h"

#import "HFTest.h"

@interface HFBTreeTests : XCTestCase
@end

@implementation HFBTreeTests

- (void)testPerformance {
    [self measureBlock:^{
        @autoreleasepool {
            HFBTree *btree = [[HFBTree alloc] init];
            const NSUInteger max = 1234567;
            for (NSUInteger i = 0; i < max; i++) {
                TreeEntry *entry = [[TreeEntry alloc] initWithLength:1 value:@"yay"];
                [btree insertEntry:entry atOffset: ((unsigned)random() % (i + 1))];
            }
        }
    }];
}

static void test_trees(XCTestCase *self, NaiveArray *naiveArray, HFBTree *btree) {
    [btree checkIntegrityOfCachedLengths];
    [btree checkIntegrityOfBTreeStructure];
    
    NSEnumerator *naiveEnumerator = [naiveArray entryEnumerator], *btreeEnumerator = [btree entryEnumerator];
    HFBTreeIndex enumeratedOffset = 0;
    NSUInteger q = 0;
    for (;;) {
        TreeEntry *naiveEntry = [naiveEnumerator nextObject];
        TreeEntry *btreeEntry = [btreeEnumerator nextObject];
        XCTAssert(naiveEntry == btreeEntry);
        if (naiveEntry == nil || btreeEntry == nil) break;
        HFBTreeIndex randomOffsetWithinEntry = enumeratedOffset + ((unsigned)random() % [btreeEntry length]);
        HFBTreeIndex beginningOffset = (HFBTreeIndex)-1;

        if(q % 100 == 0) {
            TreeEntry *naiveFoundEntry = [naiveArray entryContainingOffset:randomOffsetWithinEntry beginningOffset:&beginningOffset];
            XCTAssert(naiveFoundEntry == naiveEntry);
            XCTAssert(beginningOffset == enumeratedOffset);
        }
        
        TreeEntry *btreeFoundEntry = [btree entryContainingOffset:randomOffsetWithinEntry beginningOffset:&beginningOffset];
        XCTAssert(btreeFoundEntry == btreeEntry);
        XCTAssert(beginningOffset == enumeratedOffset);
        enumeratedOffset += [btreeEntry length];
        q++;
    }
}

- (void)testFillUnfill {
    NaiveArray *naiveArray = [[NaiveArray alloc] init];
    HFBTree *btree = [[HFBTree alloc] init];
    
    //insertion
    NSUInteger max = 4321;
    for (NSUInteger i=0; i < max; i++) {
        HFBTreeIndex entryLength = random()%10000+1;
        char buff[32];
        sprintf(buff, "%lu", (unsigned long)i);
        NSString *string = [[NSString alloc] initWithCString:buff encoding:NSMacOSRomanStringEncoding];
        TreeEntry *entry = [TreeEntry entryWithLength:entryLength value:string];
        
        HFBTreeIndex offset = [naiveArray randomOffset];
        
        dbg_printf("%s:\t%llu, %llu\n", buff, offset, entryLength);
        
        [naiveArray insertEntry:entry atOffset:offset];
        [btree insertEntry:entry atOffset:offset];
        
        test_trees(self, naiveArray, btree);
        
        /* Test a copy of the tree too */
        HFBTree *copiedTree = [btree mutableCopy];
        [copiedTree checkIntegrityOfBTreeStructure];
        [copiedTree checkIntegrityOfCachedLengths];
    }
    
    //deletion
    for (NSUInteger i=0; i < max; i++) {
        HFBTreeIndex offset = [naiveArray randomOffsetExcludingLast];
        [naiveArray removeEntryAtOffset:offset];
        [btree removeEntryAtOffset:offset];
        test_trees(self, naiveArray, btree);
        
        /* Test a copy of the tree too */
        HFBTree *copiedTree = [btree mutableCopy];
        [copiedTree checkIntegrityOfBTreeStructure];
        [copiedTree checkIntegrityOfCachedLengths];
    }
}

-(void)testRandom {
    NaiveArray *naiveArray = [[NaiveArray alloc] init];
    HFBTree *btree = [[HFBTree alloc] init];

    NSUInteger nodeCount = 0;
    for (NSUInteger i=0; i < 23456; i++) {
        BOOL insert = nodeCount == 0 ? YES : ((random() % 5) >= 2);
        if (i % 100 == 0) dbg_printf("%lu -> %lu nodes\n", (unsigned long)i, (unsigned long)nodeCount);
        if (insert) {
            HFBTreeIndex entryLength = random()%10000+1;
            char buff[32];
            sprintf(buff, "%lu", (unsigned long)i);
            NSString *string = [[NSString alloc] initWithCString:buff encoding:NSMacOSRomanStringEncoding];
            TreeEntry *entry = [TreeEntry entryWithLength:entryLength value:string];
            HFBTreeIndex offset = [naiveArray randomOffset];
            [naiveArray insertEntry:entry atOffset:offset];
            [btree insertEntry:entry atOffset:offset];            
            nodeCount++;
        } else {
            HFBTreeIndex offset = [naiveArray randomOffsetExcludingLast];
            [naiveArray removeEntryAtOffset:offset];
            [btree removeEntryAtOffset:offset];            
            nodeCount--;
        }
        test_trees(self, naiveArray, btree);
    }
}

- (void)setUp {
    [super setUp];
    srandom(0xBEBAFECA);
}

- (void)tearDown {
    [super tearDown];
}

@end
