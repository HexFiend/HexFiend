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

@end
