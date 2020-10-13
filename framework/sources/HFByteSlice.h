//
//  HFByteSlice.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

@class HFFileReference, HFByteRangeAttributeArray;

/*! @class HFByteSlice
@brief A class representing a source of data for an HFByteArray.

HFByteSlice is an abstract class encapsulating primitive data sources (files, memory buffers, etc.).  Each source must support random access reads, and have a well defined length.  All HFByteSlices are \b immutable.

The two principal subclasses of HFByteSlice are HFSharedMemoryByteSlice and HFFileByteSlice, which respectively encapsulate data from memory and from a file.
*/
@interface HFByteSlice : NSObject

/*! Return the length of the byte slice as a 64 bit value.  This is an abstract method that concrete subclasses must override. */
- (unsigned long long)length;

/*! Copies a range of data from the byte slice into an in-memory buffer.  This is an abstract method that concrete subclasses must override. */
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range;

/*! Returns a new slice containing a subrange of the given slice.  This is an abstract method that concrete subclasses must override. */
- (HFByteSlice *)subsliceWithRange:(HFRange)range;

/*! Attempts to create a new byte slice by appending one byte slice to another.  This does not modify the receiver or the slice argument (after all, both are immutable).  This is provided as an optimization, and is allowed to return nil if the appending cannot be done efficiently.  The default implementation returns nil.
*/
- (nullable HFByteSlice *)byteSliceByAppendingSlice:(HFByteSlice *)slice;

/*! Returns YES if the receiver is sourced from a file.  The default implementation returns NO.  This is used to estimate cost when writing to a file.
*/
- (BOOL)isSourcedFromFile;

/*! For a given file reference, returns the range within the file that the receiver is sourced from.  If the receiver is not sourced from this file, returns {ULLONG_MAX, ULLONG_MAX}.  The default implementation returns {ULLONG_MAX, ULLONG_MAX}.  This is used during file saving to to determine how to properly overwrite a given file.
*/
- (HFRange)sourceRangeForFile:(HFFileReference *)reference;

@end

/*! @category HFByteSlice(HFAttributes)
    @brief Methods for querying attributes of individual byte slices. */
@interface HFByteSlice (HFAttributes)

/*!  Returns the attributes for the bytes in the given range. */
- (nullable HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range;

@end

NS_ASSUME_NONNULL_END
