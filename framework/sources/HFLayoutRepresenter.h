//
//  HFLayoutRepresenter.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

/*! @class HFLayoutRepresenter
    @brief An HFRepresenter responsible for arranging the views of other HFRepresenters attached to the same HFController.
    
    HFLayoutRepresenter is an HFRepresenter that manages the views of other HFRepresenters.  It arranges their views in its own view, mediating between them to determine their position and size, as well as global properties such as bytes per line.
    
    HFLayoutRepresenter has an array of representers attached to it.  When you add an HFRepresenter to this array, HFLayoutRepresenter will add the view of the representer as a subview of its own view.
    
    \b Layout
    
    HFLayoutRepresenter is capable of arranging the views of other HFRepresenters to fit within the bounds of its view.  The layout process depends on three things:
    
    -# The \c frame and \c autoresizingMask of the representers' views.
    -# The \c minimumViewWidthForBytesPerLine: method, which determines the largest number of bytes per line that the representer can display for a given view width.
    -# The representer's \c layoutPosition.  This is an NSPoint, but it is not used geometrically.  Instead, the relative values of the X and Y coordinates of the \c layoutPosition determine the relative positioning of the views, as described below.
    
    Thus, to have your subclass of HFRepresenter participate in the HFLayoutRepresenter system, override \c defaultLayoutPosition: to control its positioning, and possibly \\c minimumViewWidthForBytesPerLine: if your representer requires a certain width to display some bytes per line.  Then ensure your view has its autoresizing mask set properly, and if its frame is fixed size, ensure that its frame is correct as well.
    
    The layout process, in detail, is:
    
    -# The views are sorted vertically by the Y component of their representers' \c layoutPosition into "slices." Smaller values appear towards the bottom of the layout view.  There is no space between slices.
    -# Views with equal Y components are sorted horizontally by the X component of their representers' \c layoutPosition, with smaller values appearing on the left.
    -# The height of each slice is determined by the tallest view within it, excluding views that have \c NSViewHeightSizable set.  If there is any leftover vertical space, it is distributed equally among all slices with at least one view with \c NSViewHeightSizable set.
    -# If the layout representer is not set to maximize the bytes per line (BPL), then the BPL from the HFController is used.  Otherwise:
        -# Each representer is queried for its \c minimumViewWidthForBytesPerLine:
	-# The largest BPL allowing each row to fit within the layout width is determined via a binary search.
	-# The BPL is rounded down to a multiple of the bytes per column (if non-zero).
	-# The BPL is then set on the controller.
    -# For each row, each view is assigned its minimum view width for the BPL.
    -# If there is any horizontal space left over, it is divided evenly between all views in that slice that have \c NSViewWidthSizable set in their autoresizing mask.
    
*/
@interface HFLayoutRepresenter : HFRepresenter {
    NSMutableArray *representers;
    BOOL maximizesBytesPerLine;
}

/*! @name Managed representers
    Managing the list of representers laid out by the receiver
*/
//@{
/// Return the array of representers managed by the receiver. */
@property (readonly, copy) NSArray *representers;

/*! Adds a new representer to the receiver, triggering relayout. */
- (void)addRepresenter:(HFRepresenter *)representer;

/*! Removes a representer to the receiver (which must be present in the receiver's array of representers), triggering relayout. */
- (void)removeRepresenter:(HFRepresenter *)representer;
//@}

/*! When enabled, the receiver will attempt to maximize the bytes per line so as to consume as much as possible of the bounds rect.  If this is YES, then upon relayout, the receiver will recalculate the maximum number of bytes per line that can fit in its boundsRectForLayout.  If this is NO, then the receiver will not change the bytes per line. */
@property (nonatomic) BOOL maximizesBytesPerLine;

/*! @name Layout
    Methods to get information about layout, and to explicitly trigger it.
*/
//@{
/*! Returns the smallest width that produces the same layout (and, if maximizes bytesPerLine, the same bytes per line) as the proposed width. */
- (CGFloat)minimumViewWidthForLayoutInProposedWidth:(CGFloat)proposedWidth;

/*! Returns the maximum bytes per line that can fit in the proposed width (ignoring maximizesBytesPerLine).  This is always a multiple of the bytesPerColumn, and always at least bytesPerColumn. */
- (NSUInteger)maximumBytesPerLineForLayoutInProposedWidth:(CGFloat)proposedWidth;

/*! Returns the smallest width that can support the given bytes per line. */
- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine;

/*! Relayouts are triggered when representers are added and removed, or when the view is resized.  You may call this explicitly to trigger a relayout. */
- (void)performLayout;
//@}

@end
