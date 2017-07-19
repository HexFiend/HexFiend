//
//  FileDataDocument.m
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "FileDataDocument.h"

static inline Class preferredByteArrayClass(void) {
    return [HFAttributedByteArray class];
}

@implementation FileDataDocument

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    USE(typeName);
    USE(outError);
    BOOL result = NO;
    HFASSERT([absoluteURL isFileURL]);
    NSError *localError = nil;
    NSString *path = [absoluteURL path];
    HFFileReference *fileReference = [[HFFileReference alloc] initWithPath:path error:&localError];
    if (fileReference == nil) {
        if (outError) *outError = localError;
    } else {
        HFFileByteSlice *byteSlice = [[HFFileByteSlice alloc] initWithFile:fileReference];
        HFByteArray *byteArray = [[preferredByteArrayClass() alloc] init];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [controller setByteArray:byteArray];
        result = YES;

        if ([fileReference isPrivileged])
            [controller setEditMode:HFReadOnlyMode];
        else {
            [controller setEditMode:[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultEditMode"]];
        }
    }

    requiresOverwriteMode = [fileReference isFixedLength];

    return result;
}

- (BOOL)requiresOverwriteMode
{
    return requiresOverwriteMode;
}

@end
