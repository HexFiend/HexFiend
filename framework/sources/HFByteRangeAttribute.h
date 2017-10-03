#import <Foundation/NSString.h>

NS_ASSUME_NONNULL_BEGIN

/* Attributes used to illustrate diffs. */
extern NSString * const kHFAttributeDiffInsertion;

/* Attribute used for illustrating a focused range of characters. */
extern NSString * const kHFAttributeFocused;

/* Attributes used for address spaces of other processes. */
extern NSString * const kHFAttributeUnmapped;   /* A range that is not allocated, used to describe sparse data sets (e.g. a virtual address space). */
extern NSString * const kHFAttributeUnreadable; /* A range that is allocated but is not readable. */
extern NSString * const kHFAttributeWritable;   /* A range that is writable. */
extern NSString * const kHFAttributeExecutable; /* A range that is executable. */
extern NSString * const kHFAttributeShared;     /* A range that is shared memory. */

extern NSString * const kHFAttributeMagic; /* For testing. */

/* Bookmark attribute.  Pass an integer (the bookmark) and get back a string that can be used as an attribute. */
extern NSString *HFBookmarkAttributeFromBookmark(NSInteger bookmark);

/* Given a bookmark string, return the bookmark index for it, or NSNotFound if the string does not represent a bookmark attribute. */
extern NSInteger HFBookmarkFromBookmarkAttribute(NSString *bookmark);

NS_ASSUME_NONNULL_END
