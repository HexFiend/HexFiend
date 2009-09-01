//
//  HFByteRangeAttributeArray.h
//  HexFiend_2
//
//  Created by Peter Ammon on 8/24/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFByteRangeAttributeArray : NSObject {
    NSMutableArray *attributeRuns;
}

- (NSSet *)attributesAtIndex:(unsigned long long)index length:(unsigned long long *)length;
- (void)addAttribute:(NSString *)attributeName range:(HFRange)range;
- (void)transferAttributesFromAttributeArray:(HFByteRangeAttributeArray *)array baseOffset:(unsigned long long)baseOffset;

@end
