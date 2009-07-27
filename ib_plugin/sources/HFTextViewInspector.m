//
//  HFTextViewInspector.m
//  HexFiend_2
//
//  Created by Peter Ammon on 6/29/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "HFTextViewInspector.h"


@implementation HFTextViewInspector

- (NSString *)viewNibName {
    return @"HFTextViewInspector";
}

- (void)refresh {
    // Synchronize your inspector's content view with the currently selected objects
    [super refresh];
}

@end
