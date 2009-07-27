#import <Foundation/Foundation.h>
#import "NaiveArray.h"
#import "HFBTree.h"
#import "TreeEntry.h"

static inline HFBTreeIndex random_value(NSUInteger max) {
    unsigned int result;
    while ((result = (random() % max)) == 0)
        ;
    return result;
}

static void run_for_shark(void) {
    HFBTree *btree = [[HFBTree alloc] init];
    const NSUInteger max = 5000000;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    for (NSUInteger i = 0; i < max; i++) {
        TreeEntry *entry = [[TreeEntry alloc] initWithLength:1 value:@"yay"];
        [btree insertEntry:entry atOffset: (random() % (i + 1))];
        [entry release];
    }
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    printf("Time: %.04f\n", end - start);
    [btree release];
}

static void test_trees(NaiveArray *naiveArray, HFBTree *btree) {
    [btree checkIntegrityOfCachedLengths];
    [btree checkIntegrityOfBTreeStructure];
    
    NSEnumerator *naiveEnumerator = [naiveArray entryEnumerator], *btreeEnumerator = [btree entryEnumerator];
    HFBTreeIndex enumeratedOffset = 0;
    NSUInteger q = 0;
    for (;;) {
        TreeEntry *naiveEntry = [naiveEnumerator nextObject];
        TreeEntry *btreeEntry = [btreeEnumerator nextObject];
        HFASSERT(naiveEntry == btreeEntry);
        if (naiveEntry == nil || btreeEntry == nil) break;
        HFBTreeIndex randomOffsetWithinEntry = enumeratedOffset + (random() % [btreeEntry length]);
        HFBTreeIndex beginningOffset = -1;
#if 0
        TreeEntry *naiveFoundEntry = [naiveArray entryContainingOffset:randomOffsetWithinEntry beginningOffset:&beginningOffset];
        HFASSERT(naiveFoundEntry == naiveEntry);
        HFASSERT(beginningOffset == enumeratedOffset);
#endif        
        
        TreeEntry *btreeFoundEntry = [btree entryContainingOffset:randomOffsetWithinEntry beginningOffset:&beginningOffset];
        HFASSERT(btreeFoundEntry == btreeEntry);
        HFASSERT(beginningOffset == enumeratedOffset);
        enumeratedOffset += [btreeEntry length];
        q++;
    }
}

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    
    BOOL runForShark = NO;
    if (argc >= 2) {
        runForShark = ! strcmp(argv[1], "-shark");
    }
    if (runForShark) {
        run_for_shark();
        [pool drain];
        return 0;
    }
    
    CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
    
    NaiveArray *naiveArray = [[NaiveArray alloc] init];
    HFBTree *btree = [[HFBTree alloc] init];
    
    //insertion
    NSUInteger i, max = 6000;
    for (i=0; i < max; i++) {
        HFBTreeIndex entryLength = random_value(10000);
        char buff[32];
        sprintf(buff, "%lu", (unsigned long)i);
        NSString *string = [[NSString alloc] initWithCString:buff encoding:NSMacOSRomanStringEncoding];
        TreeEntry *entry = [TreeEntry entryWithLength:entryLength value:string];
        [string release];
        
        HFBTreeIndex offset = [naiveArray randomOffset];
        
//        printf("%s:\t%llu, %llu\n", buff, offset, entryLength);
        
        [naiveArray insertEntry:entry atOffset:offset];
        [btree insertEntry:entry atOffset:offset];
        
        test_trees(naiveArray, btree);
        
        /* Test a copy of the tree too */
        HFBTree *copiedTree = [btree mutableCopy];
        [copiedTree checkIntegrityOfBTreeStructure];
        [copiedTree checkIntegrityOfCachedLengths];
        [copiedTree release];
    }
    
    //deletion
    for (i=0; i < max; i++) {
        HFBTreeIndex offset = [naiveArray randomOffsetExcludingLast];
        [naiveArray removeEntryAtOffset:offset];
        [btree removeEntryAtOffset:offset];
        test_trees(naiveArray, btree);
        
        /* Test a copy of the tree too */
        HFBTree *copiedTree = [btree mutableCopy];
        [copiedTree checkIntegrityOfBTreeStructure];
        [copiedTree checkIntegrityOfCachedLengths];
        [copiedTree release];
    }
    
    [pool drain];
    pool = [[NSAutoreleasePool alloc] init];
    
    puts("Testing randomized insertion/deletion");
    //both
    NSUInteger nodeCount = 0;
    for (i=0; i < 50000; i++) {
        BOOL insert;
        if (nodeCount == 0) {
            insert = YES;
        }
        else {
            insert = ((random() % 5) >= 2);
        }
        if (i % 100 == 0) printf("%lu -> %lu nodes\n", (unsigned long)i, (unsigned long)nodeCount);
        if (insert) {
            HFBTreeIndex entryLength = random_value(10000);
            char buff[32];
            sprintf(buff, "%lu", (unsigned long)i);
            NSString *string = [[NSString alloc] initWithCString:buff encoding:NSMacOSRomanStringEncoding];
            TreeEntry *entry = [TreeEntry entryWithLength:entryLength value:string];
            [string release];            
            HFBTreeIndex offset = [naiveArray randomOffset];
            [naiveArray insertEntry:entry atOffset:offset];
            [btree insertEntry:entry atOffset:offset];            
            nodeCount++;
        }
        else {
            HFBTreeIndex offset = [naiveArray randomOffsetExcludingLast];
            [naiveArray removeEntryAtOffset:offset];
            [btree removeEntryAtOffset:offset];            
            nodeCount--;
        }
        test_trees(naiveArray, btree);
    }
    
    
    [pool drain];
    
    CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
    printf("TIME: %f\n", endTime - startTime);
    
    return 0;
}
