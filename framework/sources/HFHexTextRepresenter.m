//
//  HFHexTextRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFRepresenterHexTextView.h>

@implementation HFHexTextRepresenter

- (Class)_textViewClass {
    return [HFRepresenterHexTextView class];
}

@end
