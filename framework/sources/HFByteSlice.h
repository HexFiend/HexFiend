//
//  HFByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/4/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFFileReference;

@interface HFByteSlice : NSObject {
}

- (unsigned long long)length;
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range;
- (HFByteSlice *)subsliceWithRange:(HFRange)range;

/* Attempts to append a given byte slice and return a new one.  This does not modify the receiver or the slice parameter.  This may return nil if the appending cannot be done efficiently (in which case, it should be done at the byte array level).
*/
- byteSliceByAppendingSlice:(HFByteSlice *)slice;

/* Used for file writing.  For a given file reference, returns the range within the file that it is sourced from; if it is not sourced from this file, returns {ULLONG_MAX, ULLONG_MAX}
*/
- (BOOL)isSourcedFromFile;
- (HFRange)sourceRangeForFile:(HFFileReference *)reference;

@end
