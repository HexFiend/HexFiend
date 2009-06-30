//
//  HFControllerCoalescedUndo.h
//  HexFiend_2
//
//  Created by Peter Ammon on 12/30/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFTypes.h>

@class HFByteArray;

/* A class to track the following operation - replace the data within rangeToReplace with the replacementByteArray */
@interface HFControllerCoalescedUndo : NSObject {
    unsigned long long anchorPoint;
    unsigned long long actionPoint;
    HFByteArray *deletedData;
    BOOL byteArrayWasCopied;
}

/* replacedData may be nil if it should be considered empty */
- initWithReplacedData:(HFByteArray *)replacedData atAnchorLocation:(unsigned long long)anchor;

- initWithOverwrittenData:(HFByteArray *)overwrittenData atAnchorLocation:(unsigned long long)anchor;

- (BOOL)canCoalesceAppendInRange:(HFRange)range;
- (BOOL)canCoalesceDeleteInRange:(HFRange)range;
- (BOOL)canCoalesceOverwriteAtLocation:(unsigned long long)location;

- (void)appendDataOfLength:(unsigned long long)length;
- (void)deleteDataOfLength:(unsigned long long)length withByteArray:(HFByteArray *)array;
- (void)overwriteDataInRange:(HFRange)overwriteRange withByteArray:(HFByteArray *)array;

- (HFRange)rangeToReplace;
- (HFByteArray *)deletedData;

- (HFControllerCoalescedUndo *)invertWithByteArray:(HFByteArray *)byteArray;

@end
