//
//  HFRepresenter.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFController.h>

/*! @class HFRepresenter
    @brief The principal view class of Hex Fiend's MVC architecture.
    
    HFRepresenter is a class that visually represents some property of the HFController, such as the data (in various formats), the scroll position, the line number, etc.  An HFRepresenter is added to an HFController and then gets notified of changes to various properties, through the controllerDidChange: methods.
    
    HFRepresenters also have a view, accessible through the -view method.  The HFRepresenter is expected to update its view to reflect the relevant properties of its HFController.  If the user can interact with the view, then the HFRepresenter should pass any changes down to the HFController, which will subsequently notify all HFRepresenters of the change.
    
    HFRepresenter is an abstract class, with a different subclass for each possible view type.  Because HFController interacts with HFRepresenters, rather than views directly, an HFRepresenter can use standard Cocoa views and controls.
    
    To add a new view type:
    
    -# Create a subclass of HFRepresenter
    -# Override \c -createView to return a view (note that this method should transfer ownership)
    -# Override \c -controllerDidChange:, checking the bitmask to see what properties have changed and updating your view as appropriate
    -# If you plan on using this view together with other views, override \c +defaultLayoutPosition to control how your view gets positioned in an HFLayoutRepresenter
    -# If your view's width depends on the properties of the controller, override some of the measurement methods, such as \c +maximumBytesPerLineForViewWidth:, so that your view gets sized correctly
    
*/
@interface HFRepresenter : NSObject <NSCoding> {
    @private
    id view;
    HFController *controller;
    NSPoint layoutPosition;
}

/*! @name View management
    Methods related to accessing and initializing the representer's view.
*/
//@{
/*! Returns the view for the receiver, creating it if necessary.  The view for the HFRepresenter is initially nil.  When the \c -view method is called, if the view is nil, \c -createView is called and then the result is stored.  This method should not be overridden; however you may want to call it to access the view.
*/
- (id)view;

/*! Returns YES if the view has been created, NO if it has not.  To create the view, call the view method.
 */
- (BOOL)isViewLoaded;

/*! Override point for creating the view displaying this representation.  This is called on your behalf the first time the \c -view method is called, so you would not want to call this explicitly; however this method must be overridden.  This follows the "create" rule, and so it should return a retained view.
*/
- (NSView *)createView NS_RETURNS_RETAINED;

/*! Override point for initialization of view, after the HFRepresenter has the view set as its -view property.  The default implementation does nothing.
*/
- (void)initializeView;

//@}

/*! @name Accessing the HFController
*/
//@{
/*! Returns the HFController for the receiver.  This is set by the controller from the call to \c addRepresenter:. A representer can only be in one controller at a time. */
- (HFController *)controller;
//@}

/*! @name Property change notifications
*/
//@{
/*! Indicates that the properties indicated by the given bits did change, and the view should be updated as to reflect the appropriate properties.  This is the main mechanism by which representers are notified of changes to the controller.
*/
- (void)controllerDidChange:(HFControllerPropertyBits)bits;
//@}

/*! @name HFController convenience methods
    Convenience covers for certain HFController methods
*/
//@{
/*! Equivalent to <tt>[[self controller] bytesPerLine]</tt> */
- (NSUInteger)bytesPerLine;

/*! Equivalent to <tt>[[self controller] bytesPerColumn]</tt> */
- (NSUInteger)bytesPerColumn;

/*! Equivalent to <tt>[[self controller] representer:self changedProperties:properties]</tt> .  You may call this when some internal aspect of the receiver's view (such as its frame) has changed in a way that may globally change some property of the controller, and the controller should recalculate those properties.  For example, the text representers call this with HFControllerDisplayedLineRange when the view grows vertically, because more data may be displayed.
*/
- (void)representerChangedProperties:(HFControllerPropertyBits)properties;
//@}

/*! @name Measurement
    Methods related to measuring the HFRepresenter, so that it can be laid out properly by an HFLayoutController.  All of these methods are candidates for overriding.
*/
//@{
/*! Returns the maximum number of bytes per line for the given view size.  The default value is NSUIntegerMax, which means that the representer can display any number of lines for the given view size. */
- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth;

/*! Returns the minimum view frame size for the given bytes per line.  Default is to return 0, which means that the representer can display the given bytes per line in any view size.  Fixed width views should return their fixed width. */
- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine;

/*! Returns the maximum number of lines that could be displayed at once for a given view height.  Default is to return DBL_MAX. */
- (double)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight;
//@}

/*! Returns the required byte granularity.  HFLayoutRepresenter will constrain the bytes per line to a multiple of the granularity, e.g. so that UTF-16 characters are not split across lines.  If different representers have different granularities, then it will constrain it to a multiple of all granularities, which may be very large. The default implementation returns 1. */
- (NSUInteger)byteGranularity;

/*! @name Auto-layout methods
   Methods for simple auto-layout by HFLayoutRepresenter.  See the HFLayoutRepresenter class for discussion of how it lays out representer views.
*/
//@{


/// The layout position for the receiver.
@property (nonatomic) NSPoint layoutPosition;

/*! Returns the default layout position for representers of this class.  Within the -init method, the view's layout position is set to the default for this class.  You may override this to control the default layout position.  See HFLayoutRepresenter for a discussion of the significance of the layout postition.
*/
+ (NSPoint)defaultLayoutPosition;

//@}


@end
