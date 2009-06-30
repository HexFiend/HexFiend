//
//  HFTextFieldIntegration.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/6/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextField.h>
#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "HFTextFieldInspector.h"

@implementation HFTextField (HFTextField_IBIntegration)

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths {
    [super ibPopulateKeyPaths:keyPaths];
	
	// Remove the comments and replace "MyFirstProperty" and "MySecondProperty" 
	// in the following line with a list of your view's KVC-compliant properties.
    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:[NSArray arrayWithObjects:/* @"MyFirstProperty", @"MySecondProperty",*/ nil]];
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes {
    [super ibPopulateAttributeInspectorClasses:classes];
    [classes addObject:[HFTextFieldInspector class]];
}


@end
