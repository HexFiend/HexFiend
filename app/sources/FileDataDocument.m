//
//  FileDataDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 9/6/09.
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
    HFFileReference *fileReference = [[[HFFileReference alloc] initWithPath:path error:&localError] autorelease];
    if (localError && [[localError domain] isEqualToString:NSCocoaErrorDomain] && [localError code] == NSFileReadNoPermissionError) {
        /* Try again with a privileged file reference */
#ifndef HF_NO_PRIVILEGED_FILE_OPERATIONS
        
        localError = nil;
        BOOL canConnect = [HFPrivilegedFileReference preflightAuthenticationReturningError:&localError];
        if (canConnect) {   
            fileReference = [[[HFPrivilegedFileReference alloc] initWithPath:path error:&localError] autorelease];
        }
#endif
    }
    if (fileReference == nil) {
        if (outError) *outError = localError;
    }
    else {
        HFFileByteSlice *byteSlice = [[[HFFileByteSlice alloc] initWithFile:fileReference] autorelease];
        HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [controller setByteArray:byteArray];
        result = YES;
    }
    return result;
}

@end
