//
//  HFByteSliceAttribute.m
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteRangeAttribute.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>

NSString * const kHFAttributeDiffInsertion = @"HFAttributeDiffInsertion";
NSString * const kHFAttributeFocused = @"HFAttributeFocused";
NSString * const kHFAttributeMagic = @"HFAttributeMagic";
NSString * const kHFAttributeUnmapped = @"HFAttributeUnmapped";
NSString * const kHFAttributeUnreadable = @"HFAttributeUnreadable";
NSString * const kHFAttributeWritable = @"HFAttributeWritable";
NSString * const kHFAttributeExecutable = @"HFAttributeExecutable";
NSString * const kHFAttributeShared = @"HFAttributeShared";

#define BOOKMARK_PREFIX @"HFAttributeBookmark:"

static NSString * const sStaticBookmarkStrings[] = {
    BOOKMARK_PREFIX @"0",
    BOOKMARK_PREFIX @"1",
    BOOKMARK_PREFIX @"2",
    BOOKMARK_PREFIX @"3",
    BOOKMARK_PREFIX @"4",
    BOOKMARK_PREFIX @"5",
    BOOKMARK_PREFIX @"6",
    BOOKMARK_PREFIX @"7",
    BOOKMARK_PREFIX @"8",
    BOOKMARK_PREFIX @"9"
};

NSString *HFBookmarkAttributeFromBookmark(NSInteger bookmark) {
    HFASSERT(bookmark != NSNotFound);
    if (bookmark >= 0 && (NSUInteger)bookmark < sizeof sStaticBookmarkStrings / sizeof *sStaticBookmarkStrings) {
        return sStaticBookmarkStrings[bookmark];
    }
    else {
        return [NSString stringWithFormat:BOOKMARK_PREFIX @"%ld", (long)bookmark];
    }
}

NSInteger HFBookmarkFromBookmarkAttribute(NSString *attribute) {
    if (! [attribute hasPrefix:BOOKMARK_PREFIX]) return NSNotFound;
    return [[attribute substringFromIndex:[BOOKMARK_PREFIX length]] integerValue];
}
