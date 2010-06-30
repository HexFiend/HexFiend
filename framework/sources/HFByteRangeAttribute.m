//
//  HFByteSliceAttribute.m
//  HexFiend_2
//
//  Created by Peter Ammon on 8/24/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteRangeAttribute.h>

NSString * const kHFAttributeDiffInsertion = @"HFAttributeDiffInsertion";
NSString * const kHFAttributeFocused = @"HFAttributeFocused";
NSString * const kHFAttributeMagic = @"HFAttributeMagic";
NSString * const kHFAttributeUnmapped = @"HFAttributeUnmapped";
NSString * const kHFAttributeUnreadable = @"HFAttributeUnreadable";
NSString * const kHFAttributeWritable = @"HFAttributeWritable";
NSString * const kHFAttributeExecutable = @"HFAttributeExecutable";
NSString * const kHFAttributeShared = @"HFAttributeShared";


static NSString * const sStaticBookmarkStrings[] = {
    @"HFAttributeBookmark:0",
    @"HFAttributeBookmark:1",
    @"HFAttributeBookmark:2",
    @"HFAttributeBookmark:3",
    @"HFAttributeBookmark:4",
    @"HFAttributeBookmark:5",
    @"HFAttributeBookmark:6",
    @"HFAttributeBookmark:7",
    @"HFAttributeBookmark:8",
    @"HFAttributeBookmark:9"
};

NSString *HFBookmarkAttributeFromBookmark(NSInteger bookmark) {
    HFASSERT(bookmark != NSNotFound);
    if (bookmark >= 0 && bookmark < sizeof sStaticBookmarkStrings / sizeof *sStaticBookmarkStrings) {
	return sStaticBookmarkStrings[bookmark];
    }
    return [NSString stringWithFormat:@"HFAttributeBookmark:%ld", (long)bookmark];
}

NSInteger HFBookmarkFromBookmarkAttribute(NSString *bookmark) {
    if (! [bookmark hasPrefix:@"HFAttributeBookmark:"]) return NSNotFound;
    return [[bookmark substringFromIndex:strlen("HFAttributeBookmark:")] integerValue];
}
