//
//  HFControllerCoalescedUndo.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFTypes.h>

@class HFByteArray, HFFileReference;

/* A class to track the following operation - replace the data within rangeToReplace with the replacementByteArray */
@interface HFControllerCoalescedUndo : NSObject {
    unsigned long long anchorPoint;
    unsigned long long actionPoint;
    HFByteArray *deletedData;
    uint32_t hashOrRC;
    BOOL byteArrayWasCopied;
}

/* replacedData may be nil if it should be considered empty */
- (id)initWithReplacedData:(HFByteArray *)replacedData atAnchorLocation:(unsigned long long)anchor;

- (id)initWithOverwrittenData:(HFByteArray *)overwrittenData atAnchorLocation:(unsigned long long)anchor;

- (BOOL)canCoalesceAppendInRange:(HFRange)range;
- (BOOL)canCoalesceDeleteInRange:(HFRange)range;
- (BOOL)canCoalesceOverwriteAtLocation:(unsigned long long)location;

- (void)appendDataOfLength:(unsigned long long)length;
- (void)deleteDataOfLength:(unsigned long long)length withByteArray:(HFByteArray *)array;
- (void)overwriteDataInRange:(HFRange)overwriteRange withByteArray:(HFByteArray *)array;

- (HFRange)rangeToReplace;
- (HFByteArray *)deletedData;

- (HFControllerCoalescedUndo *)invertWithByteArray:(HFByteArray *)byteArray;

- (BOOL)clearDependenciesOnRanges:(NSArray *)ranges inFile:(HFFileReference *)reference hint:(NSMutableDictionary *)hint;
- (void)invalidate;

@end

/* A class to track the following operation - replace the data within replacementRanges with byteArrays and perform the given selectionAction */
@interface HFControllerMultiRangeUndo : NSObject {
    NSArray *byteArrays; //retained
    NSArray *replacementRanges; //retained
    int selectionAction;
    uint32_t hashOrRC;    
}

- (id)initForInsertingByteArrays:(NSArray *)arrays inRanges:(NSArray *)ranges withSelectionAction:(int)selectionAction;

- (NSArray *)byteArrays;
- (NSArray *)replacementRanges;
- (int)selectionAction;

- (BOOL)clearDependenciesOnRanges:(NSArray *)ranges inFile:(HFFileReference *)reference hint:(NSMutableDictionary *)hint;
- (void)invalidate;

@end
