//
//  ExtendedAttributeDataDocument.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 2/3/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "ExtendedAttributeDataDocument.h"
#import "HFExtendedAttributes.h"

@implementation ExtendedAttributeDataDocument
{
    NSString *_attrName;
}

- (instancetype)initWithAttributeName:(NSString *)name forURL:(NSURL *)url {
    _attrName = name;
    return [super initWithContentsOfURL:url ofType:@"" error:nil];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString * __unused)typeName error:(NSError **)outError {
    HFASSERT(_attrName != nil);
    NSData *data = [HFExtendedAttributes attributeNamed:_attrName atPath:absoluteURL.path error:outError];
    if (!data) {
        return NO;
    }
    HFSharedMemoryByteSlice *byteSlice = [[HFSharedMemoryByteSlice alloc] initWithData:[data mutableCopy]];
    HFByteArray *byteArray = [[HFBTreeByteArray alloc] init];
    [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
    [controller setByteArray:byteArray];
    [controller setEditMode:HFReadOnlyMode];
    controller.savable = NO;
    return YES;
}

@end
