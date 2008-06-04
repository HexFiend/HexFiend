//
//  HFPasteboardOwner.m
//  HexFiend_2
//
//  Created by Peter Ammon on 1/12/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "HFPasteboardOwner.h"

NSString *const HFPrivateByteArrayPboardType = @"HFPrivateByteArrayPboardType";

@implementation HFPasteboardOwner

- initWithPasteboard:(NSPasteboard *)pboard forByteArray:(HFByteArray *)array withTypes:(NSArray *)types {
    REQUIRE_NOT_NULL(pboard);
    REQUIRE_NOT_NULL(array);
    REQUIRE_NOT_NULL(types);
    [super init];
    byteArray = [array retain];
    pasteboard = pboard;
    [pasteboard declareTypes:types owner:self];
    return self;
}

+ ownPasteboard:(NSPasteboard *)pboard forByteArray:(HFByteArray *)array withTypes:(NSArray *)types {
    return [[[self alloc] initWithPasteboard:pboard forByteArray:array withTypes:types] autorelease];
}

- (void)dealloc {
    [byteArray release];
    [super dealloc];
}



- (void)pasteboardChangedOwner:(NSPasteboard *)pboard {
    HFASSERT(pasteboard == pboard);
}

- (HFByteArray *)byteArray {
    return byteArray;
}

- (void)pasteboard:(NSPasteboard *)pboard provideDataForType:(NSString *)type {
    HFASSERT([type isEqual:HFPrivateByteArrayPboardType]);
    NSLog(@"Provide data for %@", type);
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithUnsignedLong:(unsigned long)byteArray], @"HFByteArray",
        [[self class] uuid], @"HFUUID",
        nil];
    [pboard setPropertyList:dict forType:type];
}

- (void)setBytesPerLine:(NSUInteger)val { bytesPerLine = val; }
- (NSUInteger)bytesPerLine { return bytesPerLine; }

+ (NSString *)uuid {
    static NSString *uuid;
    if (! uuid) {
        CFUUIDRef uuidRef = CFUUIDCreate(NULL);
        uuid = (NSString *)CFUUIDCreateString(NULL, uuidRef);
        CFRelease(uuidRef);
    }
    return uuid;
}

+ (HFByteArray *)_unpackByteArrayFromDictionary:(NSDictionary *)byteArrayDictionary {
    HFByteArray *result = nil;
    if (byteArrayDictionary) {
        NSString *uuid = [byteArrayDictionary objectForKey:@"HFUUID"];
        if ([uuid isEqual:[self uuid]]) {
            result = (HFByteArray *)[[byteArrayDictionary objectForKey:@"HFByteArray"] unsignedLongValue];
        }
    }
    return result;
}

+ (HFByteArray *)unpackByteArrayFromPasteboard:(NSPasteboard *)pasteboard {
    REQUIRE_NOT_NULL(pasteboard);
    HFByteArray *result = [self _unpackByteArrayFromDictionary:[pasteboard propertyListForType:HFPrivateByteArrayPboardType]];
    return result;
}

- (unsigned long long)amountToCopyForDataLength:(unsigned long long)numBytes stringLength:(unsigned long long)stringLength {
    unsigned long long result = ULLONG_MAX;
    NSInteger alertReturn = NSIntegerMax;
    const unsigned long long copyOption1 = MAXIMUM_PASTEBOARD_SIZE_TO_EXPORT;
    const unsigned long long copyOption2 = MINIMUM_PASTEBOARD_SIZE_TO_WARN_ABOUT;
    NSString *option1String = HFDescribeByteCount(copyOption1);
    NSString *option2String = HFDescribeByteCount(copyOption2);
    NSString* dataSizeDescription = HFDescribeByteCount(numBytes);
    if (numBytes >= MAXIMUM_PASTEBOARD_SIZE_TO_EXPORT) {
	NSString *option1 = [@"Copy " stringByAppendingString:option1String];
	NSString *option2 = [@"Copy " stringByAppendingString:option2String];
	alertReturn = NSRunAlertPanel(@"Large Clipboard", @"The copied data would occupy %@ if written to the clipboard.  This is larger than the system clipboard supports.  Do you want to copy only part of the data?", @"Cancel",  option1, option2, dataSizeDescription);
    }
    else if (numBytes >= MINIMUM_PASTEBOARD_SIZE_TO_WARN_ABOUT) {
	
    }
    
}

@end
