//
//  HFController.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <HexFiend/HFTypes.h>

@class HFRepresenter, HFByteArray, HFControllerCoalescedUndo;

enum
{
    HFControllerContentValue = 1 << 0,
    HFControllerContentLength = 1 << 1,
    HFControllerDisplayedRange = 1 << 2,
    HFControllerSelectedRanges = 1 << 3,
    HFControllerSelectionPulseAmount = 1 << 4,
    HFControllerBytesPerLine = 1 << 5,
    HFControllerBytesPerColumn = 1 << 6,
    HFControllerEditable = 1 << 7,
    HFControllerFont = 1 << 8,
    HFControllerAntialias = 1 << 9,
    HFControllerLineHeight = 1 << 10,
    HFControllerViewSizeRatios = 1 << 11 /* Indicates that the optimum size for each view may have changed; used by HFLayoutController after font changes. */
};
typedef NSUInteger HFControllerPropertyBits;

enum
{
    HFControllerDirectionLeft,
    HFControllerDirectionRight
};
typedef NSInteger HFControllerMovementDirection;

enum
{
    HFControllerDiscardSelection,
    HFControllerShiftSelection,
    HFControllerExtendSelection
};
typedef NSInteger HFControllerSelectionTransformation;

enum
{
    HFControllerMovementByte,
    HFControllerMovementLine,
    HFControllerMovementPage,
    HFControllerMovementDocument
};
typedef NSInteger HFControllerMovementGranularity;


@interface HFController : NSObject {
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

/* Methods for dealing with representers */
- (NSArray *)representers;
- (void)addRepresenter:(HFRepresenter *)representer;
- (void)removeRepresenter:(HFRepresenter *)representer;

/* Property transaction methods.  There is a property transaction stack, and all property changes are collected until the last token is popped off the stack, at which point all representers are notified of all collected changes via viewChangedProperties:.  Tokens cannot be popped out of order - they are used as a correctness check. */
- (NSUInteger)beginPropertyChangeTransaction;
- (void)endPropertyChangeTransaction:(NSUInteger)token;

/* Returns all lines on which the cursor may be placed.  This is equivalent to (unsigned long long)(HFRoundUpToNextMultiple(contentsLength, bytesPerLine) / bytesPerLine) */
- (unsigned long long)totalLineCount;

/* Methods for obtaining information about the current contents state */
- (HFFPRange)displayedLineRange;
- (void)setDisplayedLineRange:(HFFPRange)range;

- (NSFont *)font;
- (void)setFont:(NSFont *)font;

- (BOOL)shouldAntialias;
- (void)setShouldAntialias:(BOOL)antialias;

/* Returns the height in points of a line. */
- (CGFloat)lineHeight;

/* Returns total length of the contents */
- (unsigned long long)contentsLength;

/* Returns an array of HFRangeWrappers */
- (NSArray *)selectedContentsRanges;

/* Method for directly setting the selected contents ranges.  Pass an array of HFRangeWrappers that meets the following criteria:
 The array must not be NULL.
 There always must be at least one selected range.
 If any range has length 0, there must be exactly one selected range.
 No range may extend beyond the contentsLength, with the exception of a single zero-length range, which may be at the end.
 */
- (void)setSelectedContentsRanges:(NSArray *)selectedRanges;

/* Returns the smallest value in the selected contents ranges, or the insertion location if the selection is empty. */
- (unsigned long long)minimumSelectionLocation;

/* Returns the largest HFMaxRange of the selected contents ranges, or the insertion location if the selection is empty. */
- (unsigned long long)maximumSelectionLocation;

/* 0 means no pulse, 1 means maximum pulse */
- (double)selectionPulseAmount;

/* Attempts to scroll as little as possible so that as much of the given range as can fit is visible. */
- (void)maximizeVisibilityOfContentsRange:(HFRange)range;

/* Methods for getting at data */
- (NSData *)dataForRange:(HFRange)range;
- (void)copyBytes:(unsigned char *)bytes range:(HFRange)range;

/* Methods for setting a byte array */
- (void)setByteArray:(HFByteArray *)val;
- (HFByteArray *)byteArray;

/* Methods for setting an undo manager.  If one is not set, undo does not occur. */
- (void)setUndoManager:(NSUndoManager *)manager;
- (NSUndoManager *)undoManager;

/* Set/get editable property */
- (BOOL)isEditable;
- (void)setEditable:(BOOL)flag;

/* Line oriented representers can use this */
- (NSUInteger)bytesPerLine;

/* Callback for a representer-initiated change to some property */
- (void)representer:(HFRepresenter *)rep changedProperties:(HFControllerPropertyBits)properties;

/* Creates a byte array containing all of the selected bytes.  If the selection has length 0, this returns an empty byte array. */
- (HFByteArray *)byteArrayForSelectedContentsRanges;

/* Selection methods */
- (void)beginSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;
- (void)continueSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;
- (void)endSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;

/* Highlights the selection */
- (void)pulseSelection;

/* Scroll wheel support */
- (void)scrollWithScrollEvent:(NSEvent *)scrollEvent;
- (void)scrollByLines:(long double)lines;

/* Action methods */
- (IBAction)selectAll:sender;

/* General purpose navigation function.  Modify the selection in the given direction by the given number of bytes.  The selection is modifed according to the given transformation.  If useAnchor is set, then anchored selection is used; otherwise any anchor is discarded.
 
 This has a few limitations:
  - Only HFControllerDirectionLeft and HFControllerDirectionRight movement directions are supported.
  - Anchored selection is not supported for HFControllerShiftSelection (useAnchor must be NO)
*/
- (void)moveInDirection:(HFControllerMovementDirection)direction byByteCount:(unsigned long long)amountToMove withSelectionTransformation:(HFControllerSelectionTransformation)transformation usingAnchor:(BOOL)useAnchor;

/* Keyboard navigation */
- (void)moveInDirection:(HFControllerMovementDirection)direction withGranularity:(HFControllerMovementGranularity)granularity andModifySelection:(BOOL)extendSelection;
- (void)moveToLineBoundaryInDirection:(HFControllerMovementDirection)direction andModifySelection:(BOOL)extendSelection;

/* Text editing.  All of the following methods are undoable. */

/* Replaces the selection with the given data.  For something like a hex view representer, it takes two keypresses to create a whole byte; the way this is implemented, the first keypress goes into the data as a complete byte, and the second one (if any) replaces it.  If previousByteCount > 0, then that many prior bytes are replaced, without breaking undo coalescing.  For previousByteCount to be > 0, the following must be true: There is only one selected range, and it is of length 0, and its location >= previousByteCount 
    
    These functions return YES if they succeed, and NO if they fail.  Currently they may fail only in overwrite mode, if you attempt to insert data that would require lengthening the byte array.
 */
- (BOOL)insertByteArray:(HFByteArray *)byteArray replacingPreviousBytes:(unsigned long long)previousByteCount allowUndoCoalescing:(BOOL)allowUndoCoalescing;
- (BOOL)insertData:(NSData *)data replacingPreviousBytes:(unsigned long long)previousByteCount allowUndoCoalescing:(BOOL)allowUndoCoalescing;


/* Deletes the selection */
- (void)deleteSelection;

/* If the selection is empty, deletes one byte in a given direction, which must be HFControllerDirectionLeft or HFControllerDirectionRight; if the selection is not empty, deletes the selection. */
- (void)deleteDirection:(HFControllerMovementDirection)direction;

/* Replaces the entire byte array with a new one, preserving as much of the selection as possible. */
- (void)replaceByteArray:(HFByteArray *)newArray;

/* Determines how many bytes are used in each column for a text view. */
- (void)setBytesPerColumn:(NSUInteger)val;
- (NSUInteger)bytesPerColumn;

/* Determines whether we are in overwrite mode or not. */
- (BOOL)inOverwriteMode;
- (void)setInOverwriteMode:(BOOL)val;

/* Returns YES if we must be in overwrite mode (because our backing data cannot have its size changed) */
- (BOOL)requiresOverwriteMode;

@end

@interface HFController (HFFileWritingNotification)

/* Attempts to clear all dependencies on the given file (clipboard, undo, etc.) that could not be preserved if the file were written. */
+ (void)prepareForChangeInFile:(NSURL *)targetFile fromWritingByteArray:(HFByteArray *)array;

@end

/* Posted from prepareForChangeInFile:fromWritingByteArray: because we are about to write a ByteArray to a file.  The object is the FileReference. */
extern NSString * const HFPrepareForChangeInFileNotification;

/* Key in HFPrepareForChangeInFileNotification: */
extern NSString * const HFChangeInFileByteArrayKey; //the byte array that will be written
extern NSString * const HFChangeInFileModifiedRangesKey; //an array of HFRangeWrappers indicating which parts of the file will be modified
