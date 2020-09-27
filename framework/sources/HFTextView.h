//
//  HFTextView.h
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFController.h>

NS_ASSUME_NONNULL_BEGIN

@class HFLayoutRepresenter;

/*! @class HFTextView
    @brief A high-level view class analagous to NSTextView.
    
    HFTextField encapsulates a HFController and HFRepresenters into a single "do it all" NSControl analagous to NSTextView.  
*/    
@interface HFTextView : NSControl {
    HFController *dataController;
    HFLayoutRepresenter *layoutRepresenter;
    BOOL bordered;
    IBOutlet __weak id delegate;
    NSData *cachedData;
}

/*! @name Accessing MVC components
*/
//@{

/// The HFController for the receiver.  Useful for adding or removing HFRepresenters from the text view at runtime.  An HFTextView comes with its own HFController, but you can replace it.
@property (nonatomic, strong) HFController *controller;

/// The HFLayoutRepresenter for the receiver.  An HFTextView comes with its own HFLayoutRepresenter, but you can replace it.
@property (nonatomic, strong) HFLayoutRepresenter *layoutRepresenter;

/// Returns the HFByteArray for the receiver.  This is equivalent to `[[self controller] byteArray]`.
@property (nonatomic, strong, readonly) HFByteArray *byteArray;

//@}

/*! @name Display configuration
*/
//@{
/*! Sets the arry of background colors for the receiver. The background colors are used in sequence to draw each row. */

/// The array of background colors for the receiver.
@property (nonatomic, copy) NSArray *backgroundColors;

/// Whether the receiver draws a border.
@property (nonatomic) BOOL bordered;
//@}

/// The delegate, which may implement the methods in HFTextViewDelegate. Initially nil.
@property (nullable, nonatomic, weak) id delegate;

/*! Access the contents of the HFTextView's HFByteArray as an NSData.
    When setting, the data is copied via the `-copy` message, so prefer to pass an immutable `NSData` when possible.
    When getting, the NSData proxies an HFByteArray, and therefore it is usually more efficient than naively copying all of the bytes.   However, access to the `-byte` method will necessitate copying, a potentially expensive operation.  Furthermore, the NSData API is inherently 32 bit in a 32 bit process.  Lastly, there is no protection if the backing file for the data disappears.

   For those reasons, this should only be used when its convenience outweighs the downside (e.g. some bindings scenarios).  For most use cases, it is better to use the `-byteArray` method above.
*/
@property (nullable, nonatomic, copy) NSData *data;


@end

/*! @protocol HFTextViewDelegate
    @brief Delegate methods for HFTextView
*/
@protocol HFTextViewDelegate <NSObject>

/*! Called on the delegate when the HFTextView's HFController changed some properties.  See the documentation for the #HFControllerPropertyBits enum. */
- (void)hexTextView:(HFTextView *)view didChangeProperties:(HFControllerPropertyBits)properties;

@end

NS_ASSUME_NONNULL_END
