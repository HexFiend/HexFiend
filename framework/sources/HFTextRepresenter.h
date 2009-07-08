//
//  HFTextRepresenter.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFRepresenter.h>
#import <HexFiend/HFByteArray.h>

/*! @class HFTextRepresenter
    @brief An HFRepresenter that draws text (e.g. the hex or ASCII view).
    
    HFTextRepresenter is an abstract subclass of HFRepresenter that is responsible for displaying text.  There are two concrete subclass, HFHexTextRepresenter and HFStringEncodingTextRepresenter.
    
    Most of the functionality of HFTextRepresenter is private, and there is not yet enough exposed to allow creating new representers based on it.  However, there is a small amount of configurability.
*/
@interface HFTextRepresenter : HFRepresenter {
    BOOL behavesAsTextField;
    NSArray *rowBackgroundColors;
}


/*! Returns the per-row background colors.  The default is <tt>-[NSControl controlAlternatingRowBackgroundColors]</tt>. */
- (NSArray *)rowBackgroundColors;

/*! Sets the per-row background colors.  Each row is drawn with the next color in turn, cycling back to the beginning when the array is exhausted.  Any empty space is filled with the first color in the array.  If the array is empty, then the background is drawn with \c clearColor. */
- (void)setRowBackgroundColors:(NSArray *)colors;

/*! Set whether the text view behaves like a text field (YES) or a text view (NO).  Currently this determines whether it draws a focus ring when it is the first responder.
*/
- (void)setBehavesAsTextField:(BOOL)val;

/*! Returns whether the text view behaves like a text field (YES) or a text view (NO).
*/
- (BOOL)behavesAsTextField;

@end
