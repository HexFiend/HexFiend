//
//  HFFileByteSlice.h
//  HexFiend_2
//
//  Created by Peter Ammon on 1/23/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteSlice.h>

@class HFFileReference;

/*! @class HFFileByteSlice
    @brief A subclass of HFByteSlice for working data stored in files.
    
    HFFileByteSlice is a subclass of HFByteSlice that represents a portion of data from a file.  The file is specified as an HFFileReference; since the HFFileReference encapsulates the file descriptor, multiple HFFileByteSlices may all reference the same file without risking overrunning the limit on open files.
*/
@interface HFFileByteSlice : HFByteSlice {
    HFFileReference *fileReference;
    unsigned long long offset;
    unsigned long long length;
}

/*! Initialize an HFByteSlice from a file.  The receiver represents the entire extent of the file. */
- initWithFile:(HFFileReference *)file;

/*! Initialize an HFByteSlice from a portion of a file, specified as an offset and length.  The sum of the offset and length must not exceed the length of the file.  This is the designated initializer. */
- initWithFile:(HFFileReference *)file offset:(unsigned long long)offset length:(unsigned long long)length;

@end
