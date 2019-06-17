//
//  HFControllerCoalescedUndo.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTypes.h>

NS_ASSUME_NONNULL_BEGIN

@class HFByteArray, HFFileReference;

/* A class to track the following operation - replace the data within rangeToReplace with the replacementByteArray */
@interface HFControllerCoalescedUndo : NSObject {
    unsigned long long anchorPoint;
    unsigned long long actionPoint;
    HFByteArray *deletedData;
    BOOL byteArrayWasCopied;
}

/* replacedData may be nil if it should be considered empty */
- (instancetype)initWithReplacedData:(nullable HFByteArray *)replacedData atAnchorLocation:(unsigned long long)anchor;

- (instancetype)initWithOverwrittenData:(HFByteArray *)overwrittenData atAnchorLocation:(unsigned long long)anchor;

- (BOOL)canCoalesceAppendInRange:(HFRange)range;
- (BOOL)canCoalesceDeleteInRange:(HFRange)range;
- (BOOL)canCoalesceOverwriteAtLocation:(unsigned long long)location;

- (void)appendDataOfLength:(unsigned long long)length;
- (void)deleteDataOfLength:(unsigned long long)length withByteArray:(HFByteArray *)array;
- (void)overwriteDataInRange:(HFRange)overwriteRange withByteArray:(HFByteArray *)array;

- (HFRange)rangeToReplace;
- (nullable HFByteArray *)deletedData;

- (HFControllerCoalescedUndo *)invertWithByteArray:(HFByteArray *)byteArray;

- (BOOL)clearDependenciesOnRanges:(NSArray *)ranges inFile:(HFFileReference *)reference hint:(nullable NSMutableDictionary *)hint;
- (void)invalidate;

@end

/* A class to track the following operation - replace the data within replacementRanges with byteArrays and perform the given selectionAction */
@interface HFControllerMultiRangeUndo : NSObject {
    NSArray *byteArrays; //retained
    NSArray *replacementRanges; //retained
    HFControllerSelectAction selectionAction;
}

- (instancetype)initForInsertingByteArrays:(NSArray *)arrays inRanges:(NSArray *)ranges withSelectionAction:(HFControllerSelectAction)selectionAction;

- (nullable NSArray *)byteArrays;
- (nullable NSArray *)replacementRanges;
- (HFControllerSelectAction)selectionAction;

- (BOOL)clearDependenciesOnRanges:(NSArray *)ranges inFile:(HFFileReference *)reference hint:(nullable NSMutableDictionary *)hint;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END
