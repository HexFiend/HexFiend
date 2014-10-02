//
//  HFTextRepresenter.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>
#import <HexFiend/HFByteArray.h>

/*! @class HFTextRepresenter
    @brief An HFRepresenter that draws text (e.g. the hex or ASCII view).
    
    HFTextRepresenter is an abstract subclass of HFRepresenter that is responsible for displaying text.  There are two concrete subclass, HFHexTextRepresenter and HFStringEncodingTextRepresenter.
    
    Most of the functionality of HFTextRepresenter is private, and there is not yet enough exposed to allow creating new representers based on it.  However, there is a small amount of configurability.
*/
@interface HFTextRepresenter : HFRepresenter {}
/*! Given a rect edge, return an NSRect representing the maximum edge in that direction, in the coordinate system of the receiver's view.  The dimension in the direction of the edge is 0 (so if edge is NSMaxXEdge, the resulting width is 0).  The returned rect is in the coordinate space of the receiver's view.  If the byte range is not displayed, returns NSZeroRect.
 
    If range is entirely above the visible region, returns an NSRect whose width and height are 0, and whose origin is -CGFLOAT_MAX (the most negative CGFloat).  If range is entirely below the visible region, returns the same except with CGFLOAT_MAX (positive).
 
    This raises an exception if range is empty.
*/
- (NSRect)furthestRectOnEdge:(NSRectEdge)edge forByteRange:(HFRange)range;

/*! Returns the origin of the character at the given byte index.  The returned point is in the coordinate space of the receiver's view.  If the character is not displayed because it would be above the displayed range, returns {0, -CGFLOAT_MAX}.  If it is not displayed because it is below the displayed range, returns {0, CGFLOAT_MAX}.  As a special affordance, you may pass a byte index one greater than the contents length of the controller, and it will return the result as if the byte existed.
 */
- (NSPoint)locationOfCharacterAtByteIndex:(unsigned long long)byteIndex;

/*! The per-row background colors. Each row is drawn with the next color in turn, cycling back to the beginning when the array is exhausted.  Any empty space is filled with the first color in the array.  If the array is empty, then the background is drawn with \c clearColor.
 */
@property (nonatomic, copy) NSArray *rowBackgroundColors;

/*! Whether the text view behaves like a text field (YES) or a text view (NO).  Currently this determines whether it draws a focus ring when it is the first responder.
*/
@property (nonatomic) BOOL behavesAsTextField;

@end
