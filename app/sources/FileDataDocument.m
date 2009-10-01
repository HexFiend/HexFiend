//
//  FileDataDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 9/6/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "FileDataDocument.h"

static inline Class preferredByteArrayClass(void) {
    return [HFBTreeByteArray class];
}

@implementation FileDataDocument

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    USE(typeName);
    USE(outError);
    BOOL result = NO;
    HFASSERT([absoluteURL isFileURL]);
    HFFileReference *fileReference = [[[HFFileReference alloc] initWithPath:[absoluteURL path] error:outError] autorelease];
    if (fileReference) {
        
        HFFileByteSlice *byteSlice = [[[HFFileByteSlice alloc] initWithFile:fileReference] autorelease];
//        HFByteSlice *byteSlice = [[[NSClassFromString(@"HFRandomDataByteSlice") alloc] initWithRandomDataLength:ULLONG_MAX] autorelease];
        HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [controller setByteArray:byteArray];
        result = YES;
    }
    return result;
}

@end
