//
//  HFTextField.h
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>
#import <HexFiend/HFStringEncoding.h>

@class HFLayoutRepresenter, HFRepresenter, HFController, HFHexTextRepresenter, HFStringEncodingTextRepresenter;

/*! @class HFTextField
    @brief A high-level view class that is analagous to NSTextField.
    
    HFTextField encapsulates a HFController and HFRepresenters into a single "do it all" NSControl analagous to NSTextField.  Its objectValue is an HFByteArray.  It sends its \c action to its \c target when the user hits return.  It has no control.
    
    An HFTextField can be configured to show a hexadecimal view, an ASCII view, or both.
    
    This class is currently missing a fair amount of functionality, such as enabled state.
*/
    
@interface HFTextField : NSControl {
    HFController *dataController;
    HFLayoutRepresenter *layoutRepresenter;
    HFHexTextRepresenter *hexRepresenter;
    HFStringEncodingTextRepresenter *textRepresenter;
    IBOutlet id target;
    SEL action;
}

@property (nonatomic) BOOL usesHexArea; ///< Whether the hexadecimal view is shown.
@property (nonatomic) BOOL usesTextArea; ///< Whether the text area is shown.
@property (nonatomic) HFStringEncoding *stringEncoding; ///< The string encoding used by the text area.
@property (nonatomic, getter=isEditable) BOOL editable; ///< Whether the field is editable.

@end
