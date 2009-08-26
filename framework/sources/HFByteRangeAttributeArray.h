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

- (NSArray *)attributesAtIndex:(NSUInteger)index range:(NSRange *)range;
- (void)addAttribute:(NSString *)attributeName range:(NSRange)range;

@end
