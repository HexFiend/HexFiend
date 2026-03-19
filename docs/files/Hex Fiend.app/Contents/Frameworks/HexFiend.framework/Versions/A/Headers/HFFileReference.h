//
//  HFFileReference.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

/*! @class HFFileReference
    @brief A reference to an open file.
    
    HFFileReference encapsulates a reference to an open file.  Multiple instances of HFFileByteSlice may share an HFFileReference, so that the file only needs to be opened once.
 
    HFFileReference is an abstract class.  You must instantiate either HFUnprivilegedFileReference or HFPrivilegedFileReference.
    
    All HFFileReferences use non-caching IO (F_NOCACHE is set).
*/
@interface HFFileReference : NSObject {
    @protected
    int fileDescriptor;
    dev_t device;
    unsigned long long inode;
    unsigned long long fileLength;
    mode_t fileMode;
    BOOL isWritable;
}


/*! Open a file for reading and writing at the given path.  The permissions mode of any newly created file is 0744.  Returns nil if the file could not be opened, in which case the error parameter (if not nil) will be set. */
- initWritableWithPath:(NSString *)path error:(NSError **)error;

/*! Open a file for reading only at the given path.  Returns nil if the file could not be opened, in which case the error parameter (if not nil) will be set. */
- initWithPath:(NSString *)path error:(NSError **)error;

/*! Closes the file. */
- (void)close;

/*! Reads from the file into a local memory buffer.  The sum of the length and the offset must not exceed the length of the file.
    @param buff The buffer to read into.
    @param length The number of bytes to read.
    @param offset The offset in the file to read.
*/
- (void)readBytes:(unsigned char *)buff length:(NSUInteger)length from:(unsigned long long)offset;

/*! Writes data to the file, which must have been opened writable.
   @param buff The data to write.
   @param length The number of bytes to write.
   @param offset The offset in the file to write to.
   @return 0 on success, or an errno-style error code on failure
*/
- (int)writeBytes:(const unsigned char *)buff length:(NSUInteger)length to:(unsigned long long)offset;

/*! Returns the length of the file, as a 64 bit unsigned long long. */
- (unsigned long long)length;

/*! Changes the length of the file via \c ftruncate.  Returns YES on success, NO on failure; on failure it optionally returns an NSError by reference. */
- (BOOL)setLength:(unsigned long long)length error:(NSError **)error;

/*! isEqual: returns whether two file references both reference the same file, as in have the same inode and device. */
- (BOOL)isEqual:(id)val;

@end

/*! @class HFUnprivilegedFileReference
 @brief A reference to an open file that can be read (and possibly written) using normal C functions
*/
@interface HFUnprivilegedFileReference : HFFileReference
@end

#ifndef HF_NO_PRIVILEGED_FILE_OPERATIONS
/*! @class HFPrivilegedFileReference
 @brief A reference to an open file that can be read (and possibly written) using our privileged helper process
 */
@interface HFPrivilegedFileReference : HFFileReference

/*! Attempts to authenticate, returning an error on failure. */
+ (BOOL)preflightAuthenticationReturningError:(NSError **)error;

@end
#endif
