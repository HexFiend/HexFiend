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


static NSString * const sStaticBookmarkStrings[][3] = {
    {@"HFAttributeBookmarkStart:0", @"HFAttributeBookmarkMiddle:0", @"HFAttributeBookmarkEnd:0"},
    {@"HFAttributeBookmarkStart:1", @"HFAttributeBookmarkMiddle:1", @"HFAttributeBookmarkEnd:1"},
    {@"HFAttributeBookmarkStart:2", @"HFAttributeBookmarkMiddle:2", @"HFAttributeBookmarkEnd:2"},
    {@"HFAttributeBookmarkStart:3", @"HFAttributeBookmarkMiddle:3", @"HFAttributeBookmarkEnd:3"},
    {@"HFAttributeBookmarkStart:4", @"HFAttributeBookmarkMiddle:4", @"HFAttributeBookmarkEnd:4"},
    {@"HFAttributeBookmarkStart:5", @"HFAttributeBookmarkMiddle:5", @"HFAttributeBookmarkEnd:5"},
    {@"HFAttributeBookmarkStart:6", @"HFAttributeBookmarkMiddle:6", @"HFAttributeBookmarkEnd:6"},
    {@"HFAttributeBookmarkStart:7", @"HFAttributeBookmarkMiddle:7", @"HFAttributeBookmarkEnd:7"},
    {@"HFAttributeBookmarkStart:8", @"HFAttributeBookmarkMiddle:8", @"HFAttributeBookmarkEnd:8"},
    {@"HFAttributeBookmarkStart:9", @"HFAttributeBookmarkMiddle:9", @"HFAttributeBookmarkEnd:9"}
};

NSArray *HFBookmarkAttributesFromBookmark(NSInteger bookmark) {
    HFASSERT(bookmark != NSNotFound);
    if (bookmark >= 0 && bookmark < sizeof sStaticBookmarkStrings / sizeof *sStaticBookmarkStrings) {
	return [NSArray arrayWithObjects:sStaticBookmarkStrings[bookmark] count:3];
    }
    else {
	NSString *strings[3];
	strings[0] = [NSString stringWithFormat:@"HFAttributeBookmarkStart:%ld", (long)bookmark];
	strings[1] = [NSString stringWithFormat:@"HFAttributeBookmarkMiddle:%ld", (long)bookmark];
	strings[2] = [NSString stringWithFormat:@"HFAttributeBookmarkEnd:%ld", (long)bookmark];
	return [NSArray arrayWithObjects:strings count:3];
    }
}

static NSInteger parseBookmarkAttribute(NSString *bookmark, NSString *prefix) {
    if (! [bookmark hasPrefix:prefix]) return NSNotFound;
    return [[bookmark substringFromIndex:[prefix length]] integerValue];
}

extern NSInteger HFBookmarkFromBookmarkStartAttribute(NSString *string) {
    return parseBookmarkAttribute(string, @"HFAttributeBookmarkStart:");
}

extern NSInteger HFBookmarkFromBookmarkMiddleAttribute(NSString *string) {
    return parseBookmarkAttribute(string, @"HFAttributeBookmarkMiddle:");
}

extern NSInteger HFBookmarkFromBookmarkEndAttribute(NSString *string) {
    return parseBookmarkAttribute(string, @"HFAttributeBookmarkEnd:");
}
