//
//  HFTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 6/28/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFController.h>

@class HFLayoutRepresenter;

/*! @class HFTextView
    @brief A high-level view class analagous to NSTextView.
    
    HFTextField encapsulates a HFController and HFRepresenters into a single "do it all" NSControl analagous to NSTextView.  
*/    
@interface HFTextView : NSControl {
    HFController *dataController;
    HFLayoutRepresenter *layoutRepresenter;
    NSArray *backgroundColors;
    BOOL bordered;
    IBOutlet id delegate;
    NSData *cachedData;
}

/*! @name Accessing MVC components
*/
//@{
/*! Returns the HFLayoutRepresenter for the receiver.  You may want to access this to add or remove HFRepresenters from the text view at runtime. */
- (HFLayoutRepresenter *)layoutRepresenter;

/*! Returns the HFController for the receiver.  You may want to access this to add or remove HFRepresenters from the text view at runtime. */
- (HFController *)controller;

/*! Returns the HFByteArray for the receiver.  This is equivalent to <tt>[[self controller] byteArray]</tt>. */
- (HFByteArray *)byteArray;

//@}

/*! @name Display configuration
*/
//@{
/*! Sets the arry of background colors for the receiver. The background colors are used in sequence to draw each row. */
- (void)setBackgroundColors:(NSArray *)colors;

/*! Returns the array of background colors for the receiver. */
- (NSArray *)backgroundColors;

/*! Sets whether the receiver draws a border. */
- (void)setBordered:(BOOL)val;

/*! Returns whether the receiver draws a border. */
- (BOOL)bordered;
//@}

/*! @name Delegate handling
*/
//@{
/*! Sets the delegate, which may implement the methods in HFTextViewDelegate */
- (void)setDelegate:(id)delegate;

/*! Returns the delegate, which is initially nil. */
- (id)delegate;
//@}

/*! @name Accessing contents as NSData
*/
//@{
/*! Returns the contents of the HFTextView's HFByteArray as an NSData This NSData proxies an HFByteArray, and therefore it is usually more efficient than naively copying all of the bytes.   However, access to the \c -byte method will necessitate copying, a potentially expensive operation.  Furthermore, the NSData API is inherently 32 bit in a 32 bit process.  Lastly, there is no protection if the backing file for the data disappears.

   For those reasons, this should only be used when its convenience outweighs the downside (e.g. some bindings scenarios).  For most use cases, it is better to use the \c -byteArray method above.
*/
- (NSData *)data;

/*! Sets the contents of the HFTextView's HFByteArray to an \c NSData.  Note that the data is copied via the \c -copy message, so prefer to pass an immutable \c NSData when possible.
*/
- (void)setData:(NSData *)data;
//@}

@end

/*! @protocol HFTextViewDelegate
    @brief Delegate methods for HFTextView
*/
@protocol HFTextViewDelegate <NSObject>

/*! Called on the delegate when the HFTextView's HFController changed some properties.  See the documentation for the #HFControllerPropertyBits enum. */
- (void)hexTextView:(HFTextView *)view didChangeProperties:(HFControllerPropertyBits)properties;

@end
