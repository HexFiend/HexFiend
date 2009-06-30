//
//  HFTextFieldInspector.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/6/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFTextFieldInspector.h"

@implementation HFTextFieldInspector

- (NSString *)viewNibName {
    return @"HFTextFieldInspector";
}

- (void)refresh {
    // Synchronize your inspector's content view with the currently selected objects
    [super refresh];
}

@end
