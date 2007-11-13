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
    HFControllerSelectedRange = 1 << 3,
    HFControllerBytesPerLine = 1 << 4
};

typedef NSUInteger HFControllerPropertyBits;

@interface HFController : NSObject {
    @private
    NSMutableArray *representers;
    HFByteArray *byteArray;
    NSMutableArray *selectedContentsRanges;
    HFRange displayedContentsRange;
    NSUInteger bytesPerLine;
}

/* Methods for dealing with representers */
- (NSArray *)representers;
- (void)addRepresenter:(HFRepresenter *)representer;
- (void)removeRepresenter:(HFRepresenter *)representer;

/* Methods for obtaining information about the current contents state */
- (HFRange)displayedContentsRange;
- (NSArray *)selectedContentsRanges; //returns an array of HFRangeWrappers
- (unsigned long long)contentsLength; //returns total length of contents

/* Methods for getting at data */
- (void)copyBytes:(unsigned char *)bytes range:(HFRange)range;

/* Methods for setting a byte array */
- (void)setByteArray:(HFByteArray *)val;
- (HFByteArray *)byteArray;

/* Line oriented representers can use this */
- (NSUInteger)bytesPerLine;

/* Callback for a representer-initiated change to some property */
- (void)representer:(HFRepresenter *)rep changedProperties:(HFControllerPropertyBits)properties;

@end
