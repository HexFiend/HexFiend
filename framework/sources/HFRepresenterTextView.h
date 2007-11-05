//
//  HFRepresenterTextView.h
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HFRepresenter;

/* The base class for HFTextRepresenter views - such as the hex or ASCII text view */
@interface HFRepresenterTextView : NSTextView {
    HFRepresenter *representer;
}

- initWithRepresenter:(HFRepresenter *)rep;

@end
