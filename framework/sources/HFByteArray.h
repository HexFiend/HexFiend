//
//  HFByteArray.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

@class HFByteSlice, HFProgressTracker, HFFileReference, HFByteRangeAttributeArray;

typedef NS_ENUM(NSUInteger, HFByteArrayDataStringType) {
    HFHexDataStringType,
    HFASCIIDataStringType
};


/*! @class HFByteArray
@brief The principal Model class for HexFiend's MVC architecture.

HFByteArray implements the Model portion of HexFiend.framework.  It is logically a mutable, resizable array of bytes, with a 64 bit length.  It is somewhat analagous to a 64 bit version of NSMutableData, except that it is designed to enable efficient (faster than O(n)) implementations of insertion and deletion.

HFByteArray, being an abstract class, will raise an exception if you attempt to instantiate it directly.  For most uses, instantiate HFBTreeByteArray instead, with the usual <tt>[[class alloc] init]</tt>.

HFByteArray also exposes itself as an array of @link HFByteSlice HFByteSlices@endlink, which are logically immutable arrays of bytes.   which is useful for operations such as file saving that need to access the underlying byte slices.

HFByteArray contains a generation count, which is incremented whenever the HFByteArray changes (to allow caches to be implemented on top of it).  It also includes the notion of locking: a locked HFByteArray will raise an exception if written to, but it may still be read.

ByteArrays have the usual threading restrictions for non-concurrent data structures.  It is safe to read an HFByteArray concurrently from multiple threads.  It is not safe to read an HFByteArray while it is being modified from another thread, nor is it safe to modify one simultaneously from two threads.

HFByteArray is an abstract class.  It will raise an exception if you attempt to instantiate it directly.  The principal concrete subclass is HFBTreeByteArray.
*/

@class HFByteRangeAttributeArray;

@interface HFByteArray : NSObject <NSCopying, NSMutableCopying> {
@private
    NSUInteger changeLockCounter;
    NSUInteger changeGenerationCount;
}

/*! @name Initialization
 */
//@{
/*! Initialize to a byte array containing only the given slice. */
- (instancetype)initWithByteSlice:(HFByteSlice *)slice;

/*! Initialize to a byte array containing the slices of the given array. */
- (instancetype)initWithByteArray:(HFByteArray *)array;
//@}


/*! @name Accessing raw data
*/
//@{

/*! Returns the length of the HFByteArray as a 64 bit unsigned long long. This is an abstract method that concrete subclasses must override. */
- (unsigned long long)length;

/*! Copies a range of bytes into a buffer.  This is an abstract method that concrete subclasses must override. */
- (void)copyBytes:(unsigned char *)dst range:(HFRange)range;
//@}

/*! @name Accessing byte slices
    Methods to access the byte slices underlying the HFByteArray.
*/
//@{
/*! Returns the contents of the receiver as an array of byte slices.  This is an abstract method that concrete subclasses must override. */
- (NSArray *)byteSlices;

/*! Returns an NSEnumerator representing the byte slices of the receiver.  This is implemented as enumerating over the result of -byteSlices, but subclasses can override this to be more efficient. */
- (NSEnumerator *)byteSliceEnumerator;

/*! Returns the byte slice containing the byte at the given index, and the actual offset of this slice. */
- (nullable HFByteSlice *)sliceContainingByteAtIndex:(unsigned long long)offset beginningOffset:(unsigned long long *_Nullable)actualOffset;
//@}

/*! @name Modifying the byte array
    Methods to modify the given byte array.
*/
//@{
/*! Insert an HFByteSlice in the given range.  The maximum value of the range must not exceed the length of the subarray.  The length of the given slice is not required to be equal to length of the range - in other words, this method may change the length of the receiver.  This is an abstract method that concrete subclasses must override. */
- (void)insertByteSlice:(HFByteSlice *)slice inRange:(HFRange)lrange;

/*! Insert an HFByteArray in the given range.  This is implemented via calling <tt>insertByteSlice:inRange:</tt> with the byte slices from the given byte array. */
- (void)insertByteArray:(HFByteArray *)array inRange:(HFRange)lrange;

/*! Delete bytes in the given range.  This is implemented on the base class by creating an empty byte array and inserting it in the range to be deleted, via <tt>insertByteSlice:inRange:</tt>. */
- (void)deleteBytesInRange:(HFRange)range;

/*! Returns a new HFByteArray containing the given range.  This is an abstract method that concrete subclasses must override. */
- (HFByteArray *)subarrayWithRange:(HFRange)range;
//@}

/*! @name Write locking and generation count
    Methods to lock and query the lock that prevents writes.
*/
//@{

/*! Increment the change lock.  Until the change lock reaches 0, all modifications to the receiver will raise an exception. */
- (void)incrementChangeLockCounter;

/*! Decrement the change lock.  If the change lock reaches 0, modifications will be allowed again. */
- (void)decrementChangeLockCounter;

/*! Query if the changes are locked.  This method is KVO compliant. */
- (BOOL)changesAreLocked;
//@}

/* @name Generation count
   Manipulate the generation count */
// @{
/*! Increments the generation count, unless the receiver is locked, in which case it raises an exception.  All subclasses of HFByteArray should call this method at the beginning of any overridden method that may modify the receiver.
  @param sel The selector that would modify the receiver (e.g. <tt>deleteBytesInRange:</tt>).  This is usually <tt>_cmd</tt>. */
- (void)incrementGenerationOrRaiseIfLockedForSelector:(SEL)sel;

/*! Return the change generation count.  Every change to the ByteArray increments this by one or more.  This can be used for caching layers on top of HFByteArray, to known when to expire their cache. */
- (NSUInteger)changeGenerationCount;

//@}



/*! @name Searching
*/
//@{
/*! Searches the receiver for a byte array matching findBytes within the given range, and returns the index that it was found. This is a concrete method on HFByteArray.
    @param findBytes The HFByteArray containing the data to be found (the needle to the receiver's haystack).
    @param range The range of the receiver in which to search.  The end of the range must not exceed the receiver's length.
    @param forwards If this is YES, then the first match within the range is returned.  Otherwise the last is returned.
    @param progressTracker An HFProgressTracker to allow progress reporting and cancelleation for the search operation.
    @return The index in the receiver of bytes equal to <tt>findBytes</tt>, or ULLONG_MAX if the byte array was not found (or the operation was cancelled)
*/
- (unsigned long long)indexOfBytesEqualToBytes:(HFByteArray *)findBytes inRange:(HFRange)range searchingForwards:(BOOL)forwards trackingProgress:(nullable HFProgressTracker *)progressTracker;
//@}

@end


/*! @category HFByteArray(HFFileWriting)
    @brief HFByteArray methods for writing to files, and preparing other HFByteArrays for potentially destructive file writes.
*/
@interface HFByteArray (HFFileWriting)
/*! Attempts to write the receiver to a file.  This is a concrete method on HFByteArray.
   @param targetURL A URL to the file to be written to.  It is OK for the receiver to contain one or more instances of HFByteSlice that are sourced from the file.
   @param progressTracker An HFProgressTracker to allow progress reporting and cancelleation for the write operation.
   @param error An out NSError parameter.
   @return YES if the write succeeded, NO if it failed.
*/
- (BOOL)writeToFile:(NSURL *)targetURL trackingProgress:(nullable HFProgressTracker *)progressTracker error:(NSError **)error;

/*! Returns the ranges of the file that would be modified, if the receiver were written to it.  This is useful (for example) in determining if the clipboard can be preserved after a save operation. This is a concrete method on HFByteArray.
   @param reference An HFFileReference to the file to be modified
   @return An array of @link HFRangeWrapper HFRangeWrappers@endlink, representing the ranges of the file that would be affected.  If no range would be affected, the result is an empty array.
*/
- (NSArray *)rangesOfFileModifiedIfSavedToFile:(HFFileReference *)reference;

/*! Attempts to modify the receiver so that it no longer depends on any of the HFRanges in the array within the given file.  It is not necessary to perform this operation on the byte array that is being written to the file.
   @param ranges An array of HFRangeWrappers, representing ranges in the given file that the receiver should no longer depend on.
   @param reference The HFFileReference that the receiver should no longer depend on.
   @param hint A dictionary that can be used to improve the efficiency of the operation, by allowing multiple byte arrays to share the same state.  If you plan to call this method on multiple byte arrays, pass the first one an empty NSMutableDictionary, and pass the same dictionary to subsequent calls.
   @return A YES return indicates the operation was successful, and the receiver no longer contains byte slices that source data from any of the ranges of the given file (or never did).  A NO return indicates that breaking the dependencies would require too much memory, and so the receiver still depends on some of those ranges.
*/
- (BOOL)clearDependenciesOnRanges:(NSArray *)ranges inFile:(HFFileReference *)reference hint:(nullable NSMutableDictionary *)hint;

@end


/*! @category HFByteArray(HFAttributes)
    @brief HFByteArray methods for attributes of byte arrays.
*/
@interface HFByteArray (HFAttributes)

/*! Returns a byte range attribute array for the bytes in the given range. */
- (HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range;

/*! Returns the HFByteArray level byte range attribute array. Default is to return nil. */
- (nullable HFByteRangeAttributeArray *)byteRangeAttributeArray;

@end

NS_ASSUME_NONNULL_END
