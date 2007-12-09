//
//  HFRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFController.h>

@interface HFRepresenter : NSObject {
    @private
    id view;
    HFController *controller;
}

// Accessor method for returning the view displaying this representation.  Not useful to override, but useful to call.
- (id)view;

// Override point for creating the view displaying this representation; must be overridden.  Should return a retained view.
- (NSView *)createView;

// Override point for initialization of view, after the HFRepresenter has it as its view property.  You may override this, but you should call super.
- (void)initializeView;

// Returns the controller for this representer.  A representer can only be in one controller at a time.
- (HFController *)controller;

// Indicates that the properties indicated by the given bits did change, and the view should be updated as appropriate.  You may override this for different actions, but you should call super.
- (void)controllerDidChange:(HFControllerPropertyBits)bits;

// Cover method for NSController
- (NSUInteger)bytesPerLine;

// Returns the maximum number of bytes per line for the given view size.  Representers that don't care should return NSUIntegerMax, which is the default value.
- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth;

// Returns the minimum view frame size for the given bytes per line.  Default is to return 0.  Fixed width views should return their fixed width.
- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine;

// Returns the maximum number of lines that could be displayed at once for a given view height.  Default is to return NSUIntegerMax.
- (NSUInteger)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight;

// Returns the maximum number of total bytes that can be displayed for the given view size.  Default is to return maximumBytesPerLineForViewWidth * maximumAvailableLinesForViewHeight, capped at NSUIntegerMax.
- (NSUInteger)maximumNumberOfBytesForViewSize:(NSSize)viewSize;

- (void)scrollWheel:(NSEvent *)event;

- (void)selectAll:sender;

// Called by the view to indicate that one or more properties has changed
- (void)viewChangedProperties:(HFControllerPropertyBits)properties;

@end
