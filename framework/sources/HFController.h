//
//  HFController.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <HexFiend/HFTypes.h>

@class HFRepresenter, HFByteArray;

enum
{
    HFControllerContentValue = 1 << 0,
    HFControllerContentLength = 1 << 1,
    HFControllerDisplayedRange = 1 << 2,
    HFControllerSelectedRanges = 1 << 3,
    HFControllerBytesPerLine = 1 << 4,
    HFControllerEditable = 1 << 5
};
typedef NSUInteger HFControllerPropertyBits;

enum
{
    HFControllerDirectionLeft,
    HFControllerDirectionRight,
    HFControllerDirectionUp,
    HFControllerDirectionDown
};
typedef NSUInteger HFControllerMovementDirection;

enum
{
    HFControllerMovementByte,
    HFControllerMovementLine,
    HFControllerMovementPage,
    HFControllerMovementDocument
};
typedef NSUInteger HFControllerMovementQuantity;


@interface HFController : NSObject {
    @private
    NSMutableArray *representers;
    HFByteArray *byteArray;
    NSMutableArray *selectedContentsRanges;
    HFRange displayedContentsRange;
    NSUInteger bytesPerLine;
    HFControllerPropertyBits propertiesToUpdate;
    
    unsigned long long selectionAnchor;
    HFRange selectionAnchorRange;
    
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

/* Methods for obtaining information about the current contents state */
- (HFRange)displayedContentsRange;
- (void)setDisplayedContentsRange:(HFRange)range;

- (NSArray *)selectedContentsRanges; //returns an array of HFRangeWrappers
- (unsigned long long)contentsLength; //returns total length of contents

/* Methods for getting at data */
- (void)copyBytes:(unsigned char *)bytes range:(HFRange)range;

/* Methods for setting a byte array */
- (void)setByteArray:(HFByteArray *)val;
- (HFByteArray *)byteArray;

/* Set/get editable property */
- (BOOL)isEditable;
- (void)setEditable:(BOOL)flag;

/* Line oriented representers can use this */
- (NSUInteger)bytesPerLine;

/* Callback for a representer-initiated change to some property */
- (void)representer:(HFRepresenter *)rep changedProperties:(HFControllerPropertyBits)properties;

/* Selection methods */
- (void)beginSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;
- (void)continueSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;
- (void)endSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex;

/* Scroll wheel support */
- (void)scrollWithScrollEvent:(NSEvent *)scrollEvent;

/* Action methods */
- (IBAction)selectAll:sender;


/* Keyboard navigation */
- (void)moveDirection:(HFControllerMovementDirection)direction andModifySelection:(BOOL)extendSelection;

@end
