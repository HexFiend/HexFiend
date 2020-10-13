//
//  HFController.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>

NS_ASSUME_NONNULL_BEGIN

/*! @header HFController
    @abstract The HFController.h header contains the HFController class, which is a central class in Hex Fiend. 
*/

@class HFRepresenter, HFByteArray, HFFileReference, HFControllerCoalescedUndo, HFByteRangeAttributeArray, HFColorRange;

/*! @enum HFControllerPropertyBits
    The HFControllerPropertyBits bitmask is used to inform the HFRepresenters of a change in the current state that they may need to react to.  A bitmask of the changed properties is passed to representerChangedProperties:.  It is common for multiple properties to be included in such a bitmask.        
*/
typedef NS_OPTIONS(NSUInteger, HFControllerPropertyBits) {
    HFControllerContentValue = 1 << 0,		/*!< Indicates that the contents of the ByteArray has changed within the document.  There is no indication as to what the change is.  If redisplaying everything is expensive, Representers should cache their displayed data and compute any changes manually. */
    HFControllerContentLength = 1 << 1,		/*!< Indicates that the length of the ByteArray has changed. */
    HFControllerDisplayedLineRange = 1 << 2,	/*!< Indicates that the displayedLineRange property of the document has changed (e.g. the user scrolled). */
    HFControllerSelectedRanges = 1 << 3,	/*!< Indicates that the selectedContentsRanges property of the document has changed (e.g. the user selected some other range). */    
    HFControllerSelectionPulseAmount = 1 << 4,	/*!< Indicates that the amount of "pulse" to show in the Find pulse indicator has changed. */    
    HFControllerBytesPerLine = 1 << 5,		/*!< Indicates that the number of bytes to show per line has changed. */        
    HFControllerBytesPerColumn = 1 << 6,	/*!< Indicates that the number of bytes per column (byte grouping) has changed. */
    HFControllerEditable = 1 << 7,		/*!< Indicates that the document has become (or is no longer) editable. */
    HFControllerFont = 1 << 8,			/*!< Indicates that the font property has changed. */
    HFControllerAntialias = 1 << 9,		/*!< Indicates that the shouldAntialias property has changed. */
    HFControllerLineHeight = 1 << 10,		/*!< Indicates that the lineHeight property has changed. */
    HFControllerViewSizeRatios = 1 << 11,	/*!< Indicates that the optimum size for each view may have changed; used by HFLayoutController after font changes. */
    HFControllerByteRangeAttributes = 1 << 12,  /*!< Indicates that some attributes of the ByteArray has changed within the document.  There is no indication as to what the change is. */
    HFControllerByteGranularity = 1 << 13,       /*!< Indicates that the byte granularity has changed.  For example, when moving from ASCII to UTF-16, the byte granularity increases from 1 to 2. */
    HFControllerBookmarks = 1 << 14,       /*!< Indicates that a bookmark has been added or removed. */
    HFControllerColorBytes = 1 << 15,   /*!< Indicates that the shouldColorBytes property has changed. */
    HFControllerShowCallouts = 1 << 16, /*!< Indicates that the shouldShowCallouts property has changed. */
    HFControllerHideNullBytes = 1 << 17, /*!< Indicates that the shouldHideNullBytes property has changed. */
    HFControllerColorRanges = 1 << 18, /*!< Indicates that the colorRanges property has changed. */
    HFControllerSavable = 1 << 19, /*!< Indicates that the document has become (or is no longer) savable. */
};

/*! @enum HFControllerMovementDirection
    
The HFControllerMovementDirection enum is used to specify a direction (either left or right) in various text editing APIs.  HexFiend does not support left-to-right languages.
*/
typedef NS_ENUM(NSInteger, HFControllerMovementDirection) {
    HFControllerDirectionLeft,
    HFControllerDirectionRight
};

/*! @enum HFControllerSelectionTransformation
    
The HFControllerSelectionTransformation enum is used to specify what happens to the selection in various APIs.  This is mainly interesting for text-editing style Representers.
*/
typedef NS_ENUM(NSInteger, HFControllerSelectionTransformation) {
    HFControllerDiscardSelection,   /*!< The selection should be discarded. */
    HFControllerShiftSelection,	    /*!< The selection should be moved, without changing its length. */
    HFControllerExtendSelection	    /*!< The selection should be extended, changing its length. */
};

/*! @enum HFControllerMovementGranularity
    
The HFControllerMovementGranularity enum is used to specify the granularity of text movement in various APIs.  This is mainly interesting for text-editing style Representers.
*/
typedef NS_ENUM(NSInteger, HFControllerMovementGranularity) {
    HFControllerMovementByte, /*!< Move by individual bytes */
    HFControllerMovementColumn, /*!< Move by a column */
    HFControllerMovementLine, /*!< Move by lines */
    HFControllerMovementPage, /*!< Move by pages */
    HFControllerMovementDocument /*!< Move by the whole document */
};

/*! @enum HFEditMode
 
HFEditMode enumerates the different edit modes that a document might be in.
 */
typedef NS_ENUM(NSInteger, HFEditMode) {
    HFInsertMode,
    HFOverwriteMode,
    HFReadOnlyMode,
} ;

/*! @class HFController
@brief A central class that acts as the controller layer for HexFiend.framework

HFController acts as the controller layer in the MVC architecture of HexFiend.  The HFController plays several significant central roles, including:
 - Mediating between the data itself (in the HFByteArray) and the views of the data (the @link HFRepresenter HFRepresenters@endlink).
 - Propagating changes to the views.
 - Storing properties common to all Representers, such as the currently displayed range, the currently selected range(s), the font, etc.
 - Handling text editing actions, such as selection changes or insertions/deletions.

An HFController is the top point of ownership for a HexFiend object graph.  It retains both its ByteArray (model) and its array of Representers (views).

You create an HFController via <tt>[[HFController alloc] init]</tt>.  After that, give it an HFByteArray via setByteArray:, and some Representers via addRepresenter:.  Then insert the Representers' views in a window, and you're done.

*/
@interface HFController : NSObject <NSCoding> {
@private
    NSMutableArray *representers;
    HFByteArray *byteArray;
    NSMutableArray *selectedContentsRanges;
    NSMutableArray<HFColorRange*> *_colorRanges;
    HFRange displayedContentsRange;
    HFFPRange displayedLineRange;
    NSUInteger bytesPerLine;
    NSUInteger bytesPerColumn;
    CGFloat lineHeight;
    
    NSUInteger currentPropertyChangeToken;
    NSMutableArray *additionalPendingTransactions;
    HFControllerPropertyBits propertiesToUpdateInCurrentTransaction;
    
    NSUndoManager *undoManager;
    NSMutableSet *undoOperations;
    HFControllerCoalescedUndo *undoCoalescer;
    
    unsigned long long selectionAnchor;
    HFRange selectionAnchorRange;
    
    CFAbsoluteTime pulseSelectionStartTime, pulseSelectionCurrentTime;
    NSTimer *pulseSelectionTimer;
    
    /* Basic cache support */
    HFRange cachedRange;
    NSData *cachedData;
    NSUInteger cachedGenerationIndex;
    
    struct {
        BOOL antialias;
        BOOL colorbytes;
        BOOL showcallouts;
        BOOL hideNullBytes;
        HFEditMode editMode;
        BOOL editable;
        BOOL selectable;
        BOOL selectionInProgress;
        BOOL shiftExtendSelection;
        BOOL commandExtendSelection;
        BOOL livereload;
        BOOL savable;
    } _hfflags;
}

/*! @name Representer handling.
   Methods for modifying the list of HFRepresenters attached to a controller.  Attached representers receive the controllerDidChange: message when various properties of the controller change.  A representer may only be attached to one controller at a time.  Representers are retained by the controller.
*/
//@{ 
/// Gets the current array of representers attached to this controller.
@property (readonly, copy) NSArray *representers;

/// Adds a new representer to this controller.
- (void)addRepresenter:(HFRepresenter *)representer;

/// Removes an existing representer from this controller.  The representer must be present in the array of representers.
- (void)removeRepresenter:(HFRepresenter *)representer;

//@}

/*! @name Property transactions
   Methods for temporarily delaying notifying representers of property changes.  There is a property transaction stack, and all property changes are collected until the last token is popped off the stack, at which point all representers are notified of all collected changes via representerChangedProperties:.  To use this, call beginPropertyChangeTransaction, and record the token that is returned.  Pass it to endPropertyChangeTransaction: to notify representers of all changed properties in bulk.

  Tokens cannot be popped out of order - they are used only as a correctness check.
*/
//@{
/*! Begins delaying property change transactions.  Returns a token that should be passed to endPropertyChangeTransactions:. */
- (NSUInteger)beginPropertyChangeTransaction;

/*! Pass a token returned from beginPropertyChangeTransaction to this method to pop the transaction off the stack and, if the stack is empty, to notify Representers of all collected changes.  Tokens cannot be popped out of order - they are used strictly as a correctness check. */
- (void)endPropertyChangeTransaction:(NSUInteger)token;
//@}

/*! @name Byte array
   Set and get the byte array. */
//@{ 

/*! The byte array must be non-nil.  In general, HFRepresenters should not use this to determine what bytes to display.  Instead they should use copyBytes:range: or dataForRange: below. */
@property (nonatomic, strong) HFByteArray *byteArray;

/*! Replaces the entire byte array with a new one, preserving as much of the selection as possible.  Unlike setByteArray:, this method is undoable, and intended to be used from representers that make a global change (such as Replace All). */
- (void)replaceByteArray:(HFByteArray *)newArray;
//@}

/*! @name Properties shared between all representers
    The following properties are considered global among all HFRepresenters attached to the receiver.
*/
//@{ 
/*! Returns the number of lines on which the cursor may be placed.  This is always at least 1, and is equivalent to (unsigned long long)(HFRoundUpToNextMultiple(contentsLength, bytesPerLine) / bytesPerLine) */
- (unsigned long long)totalLineCount;

/*! Indicates the number of bytes per line, which is a global property among all the line-oriented representers. */
- (NSUInteger)bytesPerLine;

/*! Returns the height of a line, in points.  This is generally determined by the font.  Representers that wish to align things to lines should use this. */
- (CGFloat)lineHeight;

//@}

/*! @name Selection pulsing
    Used to show the current selection after a change, similar to Find in Safari
*/
//{@

/*! Begins selection pulsing (e.g. following a successful Find operation). Representers will receive callbacks indicating that HFControllerSelectionPulseAmount has changed. */
- (void)pulseSelection;

/*! Return the amount that the "Find pulse indicator" should show.  0 means no pulse, 1 means maximum pulse.  This is useful for Representers that support find and replace. */
- (double)selectionPulseAmount;
//@}

/*! @name Selection handling
    Methods for manipulating the current selected ranges.  Hex Fiend supports discontiguous selection.
*/
//{@

/*! An array of HFRangeWrappers, representing the selected ranges.  It satisfies the following:
 The array is non-nil.
 There always is at least one selected range.
 If any range has length 0, that range is the only range.
 No range extends beyond the contentsLength, with the exception of a single zero-length range at the end.

 When setting, the setter MUST obey the above criteria. A zero length range when setting or getting represents the cursor position. */
@property (nonatomic, copy) NSArray *selectedContentsRanges;

/*! Selects the entire contents. */
- (IBAction)selectAll:(id)sender;

/*! Returns the smallest value in the selected contents ranges, or the insertion location if the selection is empty. */
- (unsigned long long)minimumSelectionLocation;

/*! Returns the largest HFMaxRange of the selected contents ranges, or the insertion location if the selection is empty. */
- (unsigned long long)maximumSelectionLocation;

/*! Convenience method for creating a byte array containing all of the selected bytes.  If the selection has length 0, this returns an empty byte array. */
- (nullable HFByteArray *)byteArrayForSelectedContentsRanges;
//@}

@property (readonly) NSMutableArray<HFColorRange*> *colorRanges;
- (void)colorRangesDidChange; // manually notify of changes to color range individual values

/* Number of bytes used in each column for a text-style representer. */
@property (nonatomic) NSUInteger bytesPerColumn;

/*! @name Edit Mode
   Determines what mode we're in, read-only, overwrite or insert. */
@property (nonatomic) HFEditMode editMode;

/*! @name Displayed line range
    Methods for setting and getting the current range of displayed lines. 
*/
//{@
/*! Get the current displayed line range.  The displayed line range is an HFFPRange (range of long doubles) containing the lines that are currently displayed.

  The values may be fractional.  That is, if only the bottom half of line 4 through the top two thirds of line 8 is shown, then the displayedLineRange.location will be 4.5 and the displayedLineRange.length will be 3.17 ( = 7.67 - 4.5).  Representers are expected to be able to handle such fractional values.
 
  When setting the displayed line range, the given range must be nonnegative, and the maximum of the range must be no larger than the total line count.
  
*/
@property (nonatomic) HFFPRange displayedLineRange;

/*! Modify the displayedLineRange so that as much of the given range as can fit is visible. If possible, moves by as little as possible so that the visible ranges before and afterward intersect with each other. */
- (void)maximizeVisibilityOfContentsRange:(HFRange)range;

/*! Modify the displayedLineRange as to center the given contents range.  If the range is near the bottom or top, this will center as close as possible.  If contents range is too large to fit, it centers the top of the range.  contentsRange may be empty. */
- (void)centerContentsRange:(HFRange)range;

- (void)adjustDisplayRangeAsNeeded:(HFFPRange *)range;

- (unsigned long long)lineForRange:(const HFRange)range;

//@}

/*! The current font. */
@property (nonatomic, copy) HFFont *font;

/*! The undo manager. If no undo manager is set, then undo is not supported. By default the undo manager is nil.
*/
@property (nullable, nonatomic, strong) NSUndoManager *undoManager;

/*! Whether the user can edit the document. */
@property (nonatomic) BOOL editable;

/*! Whether the user can save the document. */
@property (nonatomic) BOOL savable;

/*! Whether the text should be antialiased. Note that Mac OS X settings may prevent antialiasing text below a certain point size. */
@property (nonatomic) BOOL shouldAntialias;

/*! When enabled, characters have a background color that correlates to their byte values. */
@property (nonatomic) BOOL shouldColorBytes;

/*! When enabled, byte bookmarks display callout-style labels attached to them. */
@property (nonatomic) BOOL shouldShowCallouts;

/*! When enabled, null bytes are hidden in the hex view. */
@property (nonatomic) BOOL shouldHideNullBytes;

/*! When enabled, unmodified documents are auto refreshed to their latest on disk state. */
@property (nonatomic) BOOL shouldLiveReload;

/*! Representer initiated property changes
    Called from a representer to indicate when some internal property of the representer has changed which requires that some properties be recalculated.
*/
//@{
/*! Callback for a representer-initiated change to some property.  For example, if some property of a view changes that would cause the number of bytes per line to change, then the representer should call this method which will trigger the HFController to recompute the relevant properties. */

- (void)representer:(nullable HFRepresenter *)rep changedProperties:(HFControllerPropertyBits)properties;
//@}

#if !TARGET_OS_IPHONE
/*! @name Mouse selection
    Methods to handle mouse selection.  Representers that allow text selection should call beginSelectionWithEvent:forByteIndex: upon receiving a mouseDown event, and then continueSelectionWithEvent:forByteIndex: for mouseDragged events, terminating with endSelectionWithEvent:forByteIndex: upon receiving the mouse up.  HFController will compute the correct selected ranges and propagate any changes via the HFControllerPropertyBits mechanism. */
//@{
/*! Begin a selection session, with a mouse down at the given byte index. */
- (void)beginSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;

/*! Continue a selection session, whe the user drags over the given byte index. */
- (void)continueSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;

/*! End a selection session, with a mouse up at the given byte index. */
- (void)endSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;

/*! @name Scrollling
    Support for the mouse wheel and scroll bars. */
//@{
/*! Trigger scrolling appropriate for the given scroll event.  */
- (void)scrollWithScrollEvent:(NSEvent *)scrollEvent;
#endif

/*! Trigger scrolling by the given number of lines.  If lines is positive, then the document is scrolled down; otherwise it is scrolled up.  */
- (void)scrollByLines:(long double)lines;

//@}

/*! @name Keyboard navigation
    Support for chaging the selection via the keyboard
*/

/*! General purpose navigation function.  Modify the selection in the given direction by the given number of bytes.  The selection is modifed according to the given transformation.  If useAnchor is set, then anchored selection is used; otherwise any anchor is discarded.
 
 This has a few limitations:
  - Only HFControllerDirectionLeft and HFControllerDirectionRight movement directions are supported.
  - Anchored selection is not supported for HFControllerShiftSelection (useAnchor must be NO)
*/
- (void)moveInDirection:(HFControllerMovementDirection)direction byByteCount:(unsigned long long)amountToMove withSelectionTransformation:(HFControllerSelectionTransformation)transformation usingAnchor:(BOOL)useAnchor;

/*! Navigation designed for key events. */
- (void)moveInDirection:(HFControllerMovementDirection)direction withGranularity:(HFControllerMovementGranularity)granularity andModifySelection:(BOOL)extendSelection;
- (void)moveToLineBoundaryInDirection:(HFControllerMovementDirection)direction andModifySelection:(BOOL)extendSelection;

/*! @name Text editing
    Methods to support common text editing operations */
//@{

/*! Replaces the selection with the given data.  For something like a hex view representer, it takes two keypresses to create a whole byte; the way this is implemented, the first keypress goes into the data as a complete byte, and the second one (if any) replaces it.  If previousByteCount > 0, then that many prior bytes are replaced, without breaking undo coalescing.  For previousByteCount to be > 0, the following must be true: There is only one selected range, and it is of length 0, and its location >= previousByteCount 
    
    These functions return YES if they succeed, and NO if they fail.  Currently they may fail only in overwrite mode, if you attempt to insert data that would require lengthening the byte array.
    
    These methods are undoable.
 */
- (BOOL)insertByteArray:(HFByteArray *)byteArray replacingPreviousBytes:(unsigned long long)previousByteCount allowUndoCoalescing:(BOOL)allowUndoCoalescing;
- (BOOL)insertData:(NSData *)data replacingPreviousBytes:(unsigned long long)previousByteCount allowUndoCoalescing:(BOOL)allowUndoCoalescing;

/*! Deletes the selection. This operation is undoable. */
- (void)deleteSelection;

/*! If the selection is empty, deletes one byte in a given direction, which must be HFControllerDirectionLeft or HFControllerDirectionRight; if the selection is not empty, deletes the selection. Undoable. */
- (void)deleteDirection:(HFControllerMovementDirection)direction;

//@}

/*! @name Reading data
    Methods for reading data */

/*! Returns an NSData representing the given HFRange.  The length of the HFRange must be of a size that can reasonably be fit in memory.  This method may cache the result. */
- (NSData *)dataForRange:(HFRange)range;

/*! Copies data within the given HFRange into an in-memory buffer.  This is equivalent to [[controller byteArray] copyBytes:bytes range:range]. */
- (void)copyBytes:(unsigned char *)bytes range:(HFRange)range;

/*! Convenience method that returns the attributes of the underlying byte array.  You can message it directly to add and remove attributes.  If you do so, be sure to call representer:changedProperties: with the HFControllerByteRangeAttributes bit */
- (HFByteRangeAttributeArray *)byteRangeAttributeArray;

/*! Returns the attributes for the given range.  This is a union of the receiver's byteRangeAttributeArray properties and the properties returned by the byte array itself.  range.length must be <= NSUIntegerMax. */
- (HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range;

/*! Returns the range for the given bookmark.  If there is no bookmark, returns {ULLONG_MAX, ULLONG_MAX}. */
- (HFRange)rangeForBookmark:(NSInteger)bookmark;

/*! Sets the range for the given bookmark.  Pass {ULLONG_MAX, ULLONG_MAX} to remove the bookmark. Undoable. */
- (void)setRange:(HFRange)range forBookmark:(NSInteger)bookmark;

/*! Returns an NSIndexSet of the bookmarks in the given range. */
- (NSIndexSet *)bookmarksInRange:(HFRange)range;

/*! Returns total number of bytes.  This is equivalent to [[controller byteArray] length]. */
- (unsigned long long)contentsLength;

/*! @name File writing dependency handling
*/
//@{
/*! Attempts to clear all dependencies on the given file (clipboard, undo, etc.) that could not be preserved if the file were written.  Returns YES if we successfully prepared, NO if someone objected.  This works by posting a HFPrepareForChangeInFileNotification.  HFController does not register for this notification: instead the owners of the HFController are expected to register for HFPrepareForChangeInFileNotification and react appropriately.  */
+ (BOOL)prepareForChangeInFile:(NSURL *)targetFile fromWritingByteArray:(HFByteArray *)array;

/*! Attempts to break undo stack dependencies for writing the given file.  If it is unable to do so, it will clear the controller's contributions to the stack. Returns YES if it successfully broke the dependencies, and NO if the stack had to be cleared. */
- (BOOL)clearUndoManagerDependenciesOnRanges:(NSArray *)ranges inFile:(HFFileReference *)reference hint:(NSMutableDictionary *)hint;
//@}

@end

/*! A notification posted whenever any of the HFController's properties change.  The object is the HFController.  The userInfo contains one key, HFControllerChangedPropertiesKey, which contains an NSNumber with the changed properties as a HFControllerPropertyBits bitmask.  This is useful for external objects to be notified of changes.  HFRepresenters added to the HFController are notified via the controllerDidChange: message.
*/
extern NSString * const HFControllerDidChangePropertiesNotification;

/*! @name HFControllerDidChangePropertiesNotification keys 
*/
//@{
extern NSString * const HFControllerChangedPropertiesKey; //!< A key in the HFControllerDidChangeProperties containing a bitmask of the changed properties, as a HFControllerPropertyBits
//@}

/*! A notification posted from prepareForChangeInFile:fromWritingByteArray: because we are about to write a ByteArray to a file.  The object is the FileReference.
  Currently, HFControllers do not listen for this notification.  This is because under GC there is no way of knowing whether the controller is live or not.  However, pasteboard owners do listen for it, because as long as we own a pasteboard we are guaranteed to be live.
*/
extern NSString * const HFPrepareForChangeInFileNotification;

/*! @name HFPrepareForChangeInFileNotification keys 
*/
//@{
extern NSString * const HFChangeInFileByteArrayKey; //!< A key in the HFPrepareForChangeInFileNotification specifying the byte array that will be written
extern NSString * const HFChangeInFileModifiedRangesKey; //!< A key in the HFPrepareForChangeInFileNotification specifying the array of HFRangeWrappers indicating which parts of the file will be modified
extern NSString * const HFChangeInFileShouldCancelKey; //!< A key in the HFPrepareForChangeInFileNotification specifying an NSValue containing a pointer to a BOOL.  If set to YES, then someone was unable to prepare and the file should not be saved.  It's a good idea to check if this value points to YES; if so your notification handler does not have to do anything.
extern NSString * const HFChangeInFileHintKey; //!< The hint parameter that you may pass to clearDependenciesOnRanges:inFile:hint:
//@}

NS_ASSUME_NONNULL_END
