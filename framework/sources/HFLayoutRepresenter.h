//
//  HFLayoutRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 12/10/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>

/*! @class HFLayoutRepresenter
    @brief An HFRepresenter responsible for arranging the views of other HFRepresenters attached to the same HFController.
    
    HFLayoutRepresenter is an HFRepresenter that manages the views of other HFRepresenters.  It arranges their views in its own view, mediating between them to determine their position and size, as well as global properties such as bytes per line.
    
    HFLayoutRepresenter has an array of representers attached to it.  When you add an HFRepresenter to this array, HFLayoutRepresenter will add the view of the representer as a subview of its own view.
*/
@interface HFLayoutRepresenter : HFRepresenter {
    NSMutableArray *representers;
    BOOL maximizesBytesPerLine;
    
}

/*! @name Managed representers
*/
//@{
/*! Return the array of representers managed by the receiver. */
- (NSArray *)representers;

/*! Adds a new representer to the receiver, triggering relayout. */
- (void)addRepresenter:(HFRepresenter *)representer;

/*! Removes a representer to the receiver (which must be present in the receiver's array of representers), triggering relayout. */
- (void)removeRepresenter:(HFRepresenter *)representer;
//@}

/*! Returns the rect in which to layout the representers.  Defaults to <tt>[[self view] bounds]</tt>.  This can be overridden to return a different rect. */
- (NSRect)boundsRectForLayout;

/* createView can be overridden to return any view within which to layout the representers' views.  This method should return a view with a retain count of 1, per the "create" rule. */
- (NSView *)createView;

/*! Sets whether the receiver will attempt to maximize the bytes per line so as to consume as much as possible of the bounds rect.  If this is YES, then upon relayout, the receiver will recalculate the maximum number of bytes per line that can fit in its boundsRectForLayout.  If this is NO, then the receiver will not change the bytes per line. */
- (void)setMaximizesBytesPerLine:(BOOL)val;

/*! Returns whether the receiver maximizes the bytes per line. */
- (BOOL)maximizesBytesPerLine;

/*! Returns the smallest width that produces the same layout (and, if maximizes bytesPerLine, the same bytes per line) as the proposed width. */
- (CGFloat)minimumViewWidthForLayoutInProposedWidth:(CGFloat)proposedWidth;

/*! Returns the minimum width that can display the given bytesPerLine */
- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine;

/*! Relayouts are triggered when representers are added and removed, or when the view is resized.  You may call this explicitly to trigger a relayout. */
- (void)performLayout;

@end
