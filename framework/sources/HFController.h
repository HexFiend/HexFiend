//
//  HFController.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <HexFiend/HFTypes.h>

/*! @header HFController
    @abstract The HFController.h header contains the HFController class, which is a central class in Hex Fiend. 
*/

@class HFRepresenter, HFByteArray, HFControllerCoalescedUndo;

/*! @enum HFControllerPropertyBits
    The HFControllerPropertyBits bitmask is used to inform the HFRepresenters of a change in the current state that they may need to react to.  A bitmask of the changed properties is passed to representerChangedProperties:.  It is common for multiple properties to be included in such a bitmask.        
*/
enum
{
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
    HFControllerViewSizeRatios = 1 << 11	/*!< Indicates that the optimum size for each view may have changed; used by HFLayoutController after font changes. */
};
typedef NSUInteger HFControllerPropertyBits;

/*! @enum HFControllerMovementDirection
    
The HFControllerMovementDirection enum is used to specify a direction (either left or right) in various text editing APIs.  HexFiend does not support left-to-right languages.
*/
enum
{
    HFControllerDirectionLeft,
    HFControllerDirectionRight
};
typedef NSInteger HFControllerMovementDirection;

/*! @enum HFControllerSelectionTransformation
    
The HFControllerSelectionTransformation enum is used to specify what happens to the selection in various APIs.  This is mainly interesting for text-editing style Representers.
*/
enum
{
    HFControllerDiscardSelection,   /*!< The selection should be discarded. */
    HFControllerShiftSelection,	    /*!< The selection should be moved, without changing its length. */
    HFControllerExtendSelection	    /*!< The selection should be extended, changing its length. */
};
typedef NSInteger HFControllerSelectionTransformation;

/*! @enum HFControllerMovementGranularity
    
The HFControllerMovementGranularity enum is used to specify the granularity of text movement in various APIs.  This is mainly interesting for text-editing style Representers.
*/
enum
{
    HFControllerMovementByte, /*!< Move by individual bytes */
    HFControllerMovementLine, /*!< Move by lines */
    HFControllerMovementPage, /*!< Move by pages */
    HFControllerMovementDocument /*!< Move by the whole document */
};
typedef NSInteger HFControllerMovementGranularity;

/*! @class HFController
@brief A central class that acts as the controller layer for HexFiend.framework

HFController acts as the controller layer in the MVC architecture of HexFiend.  The HFController plays several significant central roles, including:
 - Mediating between the data itself (in the HFByteArray) and the views of the data (the @link HFRepresenter HFRepresenters@endlink).
 - Propagating changes to the views.
 - Storing properties common to all Representers, such as the currently diplayed range, the currently selected range(s), the font, etc.
 - Handling text editing actions, such as selection changes or insertions/deletions.

An HFController is the top point of ownership for a HexFiend object graph.  It retains both its ByteArray (model) and its array of Representers (views).

You create an HFController via <tt>[[HFController alloc] init]</tt>.  After that, give it an HFByteArray via setByteArray:, and some Representers via addRepresenter:.  Then insert the Representers' views in a window, and you're done.

*/
@interface HFController : NSObject <NSCoding> {
@private
    NSMutableArray *representers;
    HFByteArray *byteArray;
    NSMutableArray *selectedContentsRanges;
    HFRange displayedContentsRange;
    HFFPRange displayedLineRange;
    NSUInteger bytesPerLine;
    NSUInteger bytesPerColumn;
    NSFont *font;
    CGFloat lineHeight;
    
    NSUInteger currentPropertyChangeToken;
    NSMutableArray *additionalPendingTransactions;
    HFControllerPropertyBits propertiesToUpdateInCurrentTransaction;
    
    NSUndoManager *undoManager;
    
    unsigned long long selectionAnchor;
    HFRange selectionAnchorRange;
    
    HFControllerCoalescedUndo *undoCoalescer;
    
    CFAbsoluteTime pulseSelectionStartTime, pulseSelectionCurrentTime;
    NSTimer *pulseSelectionTimer;
    
    /* Basic cache support */
    HFRange cachedRange;
    NSData *cachedData;
    NSUInteger cachedGenerationIndex;
    
    struct  {
        unsigned antialias:1;
        unsigned overwriteMode:1;
        unsigned editable:1;
        unsigned selectable:1;
        unsigned selectionInProgress:1;
        unsigned shiftExtendSelection:1;
        unsigned commandExtendSelection:1;
        unsigned reserved1:25;
        unsigned reserved2:32;
    } _hfflags;
}

/*! @name Representer handling.
   Methods for modifying the list of HFRepresenters attached to a controller.  Attached representers receive the controllerDidChange: message when various properties of the controller change.  A representer may only be attached to one controller at a time.  Representers are retained by the controller.
*/
//@{ 
/*! Gets the current array of representers attached to this controller. */
- (NSArray *)representers;

/*! Adds a new representer to this controller. */
- (void)addRepresenter:(HFRepresenter *)representer;

/*! Removes an existing representer from this controller.  The representer must be present in the array of representers. */
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
/*! Sets the byte array for the HFController.  The byte array must be non-nil. */
- (void)setByteArray:(HFByteArray *)val;

/*! Returns the byte array for the HFController.  In general, HFRepresenters should not use this to determine what bytes to display.  Instead they should use copyBytes:range: or dataForRange: below. */
- (HFByteArray *)byteArray;

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

/*! Returns an array of HFRangeWrappers, representing the selected ranges.  This method always contains at least one range.  If there is no selection, then the result will contain a single range of length 0, with the location equal to the position of the cursor. */
- (NSArray *)selectedContentsRanges;

/*! Explicitly set the selected contents ranges.  Pass an array of HFRangeWrappers that meets the following criteria:
 The array must not be NULL.
 There always must be at least one selected range.
 If any range has length 0, there must be exactly one selected range.
 No range may extend beyond the contentsLength, with the exception of a single zero-length range, which may be at the end.
*/
- (void)setSelectedContentsRanges:(NSArray *)selectedRanges;

/*! Selects the entire contents. */
- (IBAction)selectAll:(id)sender;

/*! Returns the smallest value in the selected contents ranges, or the insertion location if the selection is empty. */
- (unsigned long long)minimumSelectionLocation;

/*! Returns the largest HFMaxRange of the selected contents ranges, or the insertion location if the selection is empty. */
- (unsigned long long)maximumSelectionLocation;

/*! Convenience method for creating a byte array containing all of the selected bytes.  If the selection has length 0, this returns an empty byte array. */
- (HFByteArray *)byteArrayForSelectedContentsRanges;
//@}

/*! @name Bytes per column
   Set and get the number of bytes per column. */
//@{ 
/* Sets the number of bytes used in each column for a text-style representer. */
- (void)setBytesPerColumn:(NSUInteger)val;

/* Returns the number of bytes used in each column for a text-style representer. */
- (NSUInteger)bytesPerColumn;
//@}

/*! @name Overwrite mode
   Determines whether text insertion overwrites subsequent text or not. */
//@{

/*! Determines whether this HFController is in overwrite mode or not. */
- (BOOL)inOverwriteMode;

/*! Sets whether we this HFController is in overwrite mode or not. */
- (void)setInOverwriteMode:(BOOL)val;

/*! Returns YES if we must be in overwrite mode (because our backing data cannot have its size changed) */
- (BOOL)requiresOverwriteMode;

//@}

/*! @name Displayed line range
    Methods for setting and getting the current range of displayed lines. 
*/
//{@
/*! Get the current displayed line range.  The displayed line range is an HFFPRange (range of long doubles) containing the lines that are currently displayed.

  The values may be fractional.  That is, if only the bottom half of line 4 through the top two thirds of line 8 is shown, then the displayedLineRange.location will be 4.5 and the displayedLineRange.length will be 3.17 ( = 7.67 - 4.5).  Representers are expected to be able to handle such fractional values. 
  
*/
- (HFFPRange)displayedLineRange;

/*! Sets the displayed line range.  When setting the displayed line range, the given range must be nonnegative, and the maximum of the range must be no larger than the total line count.  See the -displayedLineRange method for more information. */
- (void)setDisplayedLineRange:(HFFPRange)range;

/*! Modify the displayedLineRange as little as possible so that as much of the given range as can fit is visible. */
- (void)maximizeVisibilityOfContentsRange:(HFRange)range;

//@}

/*! @name Font
    Get and set the current font.
*/
//@{
/*! Get the current font. */
- (NSFont *)font;

/*! Set the current font. */
- (void)setFont:(NSFont *)font;

/*! @name Undo management
    Get and set the undo manager.  If no undo manager is set, then undo is not supported.
*/
//@{

/*! Set the undo manager for this HFController.  By default the undo manager for an HFController is nil.  If one is not set, undo does not occur.  This retains the undo manager. */
- (void)setUndoManager:(NSUndoManager *)manager;

/*! Gets the undo manager for this HFController.  By default the undo manager is nil.  Undo will not be supported unless an undo manager is set. */
- (NSUndoManager *)undoManager;

//@}

/*! @name Editability
   Set and get whether representers should allow editing the data.
*/
//@{
/*! Get the editable property, which determines whether the user can edit the document. */
- (BOOL)editable;

/*! Set the editable property, which determines whether the user can edit the document. */
- (void)setEditable:(BOOL)flag;
//@}

/*! @name Antialiasing
  Set and get whether the text should be antialiased. Note that Mac OS X settings may prevent antialiasing text below a certain point size. */
//@{
/*! Returns whether text should be antialiased. */
- (BOOL)shouldAntialias;

/*! Sets whether text should be antialiased. */
- (void)setShouldAntialias:(BOOL)antialias;
//@}

/*! Representer initiated property changes
    Called from a representer to indicate when some internal property of the representer has changed which requires that some properties be recalculated.
*/
//@{
/*! Callback for a representer-initiated change to some property.  For example, if some property of a view changes that would cause the number of bytes per line to change, then the representer should call this method which will trigger the HFController to recompute the relevant properties. */

- (void)representer:(HFRepresenter *)rep changedProperties:(HFControllerPropertyBits)properties;
//@}

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

/*! Returns total number of bytes.  This is equivalent to [[controller byteArray] length]. */
- (unsigned long long)contentsLength;

/*! @name File writing dependency handling
*/
//@{
/*! Attempts to clear all dependencies on the given file (clipboard, undo, etc.) that could not be preserved if the file were written.  Returns YES if we successfully prepared, NO if someone objected. */
+ (BOOL)prepareForChangeInFile:(NSURL *)targetFile fromWritingByteArray:(HFByteArray *)array;
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
//@}
