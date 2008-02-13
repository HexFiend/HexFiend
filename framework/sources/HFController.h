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
    HFControllerBytesPerLine = 1 << 4,
    HFControllerEditable = 1 << 5,
    HFControllerFont = 1 << 6,
    HFControllerLineHeight = 1 << 7 
};
typedef NSUInteger HFControllerPropertyBits;

enum
{
    HFControllerDirectionLeft,
    HFControllerDirectionRight
};
typedef NSUInteger HFControllerMovementDirection;

enum
{
    HFControllerMovementByte,
    HFControllerMovementLine,
    HFControllerMovementPage,
    HFControllerMovementDocument
};
typedef NSUInteger HFControllerMovementGranularity;

@interface HFController : NSObject {
    @private
    NSMutableArray *representers;
    HFByteArray *byteArray;
    NSMutableArray *selectedContentsRanges;
    HFRange displayedContentsRange;
    HFFPRange displayedLineRange;
    NSUInteger bytesPerLine;
    NSFont *font;
    CGFloat lineHeight;
    
    NSUInteger currentPropertyChangeToken;
    HFControllerPropertyBits propertiesToUpdateInCurrentTransaction;
    
    NSUndoManager *undoManager;
    
    unsigned long long selectionAnchor;
    HFRange selectionAnchorRange;
    
    HFControllerCoalescedUndo *undoCoalescer;
    
    /* Basic cache support */
    HFRange cachedRange;
    NSData *cachedData;
    NSUInteger cachedGenerationIndex;
    
    struct  {
        unsigned editable:1;
        unsigned selectable:1;
        unsigned selectionInProgress:1;
        unsigned shiftExtendSelection:1;
        unsigned commandExtendSelection:1;
        unsigned reserved1:27;
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

- (HFRange)displayedContentsRange;
- (void)setDisplayedContentsRange:(HFRange)range;

- (NSFont *)font;
- (void)setFont:(NSFont *)font;

- (CGFloat)lineHeight;

- (unsigned long long)contentsLength;

- (NSArray *)selectedContentsRanges; //returns an array of HFRangeWrappers

/* Returns the smallest value in the selected contents ranges, or the insertion location if the selection is empty. */
- (unsigned long long)minimumSelectionLocation;

/* Returns the largest HFMaxRange of the selected contents ranges, or the insertion location if the selection is empty. */
- (unsigned long long)maximumSelectionLocation;

/* Method for directly setting the selected contents ranges.  Pass an array of HFRangeWrappers that meets the following criteria:
    The array must not be NULL.
    There always must be at least one selected range.
    If any range has length 0, there must be exactly one selected range.
    No range may extend beyond the contentsLength, with the exception of a single zero-length range, which may be at the end.
*/
- (void)setSelectedContentsRanges:(NSArray *)selectedRanges;

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

/* Scroll wheel support */
- (void)scrollWithScrollEvent:(NSEvent *)scrollEvent;
- (void)scrollByLines:(long double)lines;

/* Action methods */
- (IBAction)selectAll:sender;

/* Keyboard navigation */
- (void)moveInDirection:(HFControllerMovementDirection)direction withGranularity:(HFControllerMovementGranularity)granularity andModifySelection:(BOOL)extendSelection;
- (void)moveInDirection:(HFControllerMovementDirection)direction byByteCount:(unsigned long long)amountToMove andModifySelection:(BOOL)extendSelection;
- (void)moveToLineBoundaryInDirection:(HFControllerMovementDirection)direction andModifySelection:(BOOL)extendSelection;

/* Text editing.  All of the following methods are undoable. */

/* Replaces the selection with the given data.  For something like a hex view representer, it takes two keypresses to create a whole byte; the way this is implemented, the first keypress goes into the data as a complete byte, and the second one (if any) replaces it.  If previousByteCount > 0, then that many prior bytes are replaced, without breaking undo coalescing.  For previousByteCount to be > 0, the following must be true: There is only one selected range, and it is of length 0, and its location >= previousByteCount */
- (void)insertByteArray:(HFByteArray *)byteArray replacingPreviousBytes:(unsigned long long)previousByteCount allowUndoCoalescing:(BOOL)allowUndoCoalescing;
- (void)insertData:(NSData *)data replacingPreviousBytes:(unsigned long long)previousByteCount allowUndoCoalescing:(BOOL)allowUndoCoalescing;

/* Deletes the selection */
- (void)deleteSelection;

/* Deletes one byte in a given direction, which must be HFControllerDirectionLeft or HFControllerDirectionRight */
- (void)deleteDirection:(HFControllerMovementDirection)direction;

@end

