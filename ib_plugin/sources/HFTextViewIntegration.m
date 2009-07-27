//
//  HFTextViewIntegration.m
//  HexFiend_2
//
//  Created by Peter Ammon on 6/29/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//


#import <HexFiend/HFTextView.h>
#import <HexFiend/HFVerticalScrollerRepresenter.h>
#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFStringEncodingTextRepresenter.h>
#import <HexFiend/HFLineCountingRepresenter.h>
#import <InterfaceBuilderKit/InterfaceBuilderKit.h>
#import "HFTextViewInspector.h"

@implementation HFTextView (HFTextView_IBIntegration)

- (void)ibPopulateKeyPaths:(NSMutableDictionary *)keyPaths {
    [super ibPopulateKeyPaths:keyPaths];
	
    [[keyPaths objectForKey:IBAttributeKeyPaths] addObjectsFromArray:[NSArray arrayWithObjects:@"ibContainsHexView", @"ibContainsASCIIView", @"ibContainsScrollerView", @"ibContainsLineNumsView", @"controller.editable", @"controller.shouldAntialias", @"controller.inOverwriteMode", @"ibColorIsDefaultAlternatingRows", @"ibSingleBackgroundColor", nil]];
}

- (void)ibPopulateAttributeInspectorClasses:(NSMutableArray *)classes {
    [super ibPopulateAttributeInspectorClasses:classes];
    [classes addObject:[HFTextViewInspector class]];
}

- (HFRepresenter *)ibRepresenterOfClass:(Class)class {
    NSEnumerator *enumer = [[[self controller] representers] objectEnumerator];
    HFRepresenter *rep;
    while ((rep = [enumer nextObject])) {
        if ([rep isKindOfClass:class]) return rep;
    }
    return nil;
}

- (void)ibAddOrRemove:(BOOL)shouldAdd representerOfClass:(Class)class {
    if (shouldAdd) {
        id rep = [[class alloc] init];
        if (class == [HFHexTextRepresenter class]) [[rep view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        if ([class isSubclassOfClass:[HFTextRepresenter class]]) {
            [rep setRowBackgroundColors:[self backgroundColors]];
        }
        [[self controller] addRepresenter:rep];
        [[self layoutRepresenter] addRepresenter:rep];
        [rep release];
    }
    else {
        HFRepresenter *rep = [self ibRepresenterOfClass:class];
        if (rep) {
            [[self layoutRepresenter] removeRepresenter:rep];
            [[self controller] removeRepresenter:rep];
        }
    }
}

- (BOOL)ibContainsHexView { return !![self ibRepresenterOfClass:[HFHexTextRepresenter class]]; }
- (BOOL)ibContainsASCIIView { return !![self ibRepresenterOfClass:[HFStringEncodingTextRepresenter class]]; }
- (BOOL)ibContainsScrollerView { return !![self ibRepresenterOfClass:[HFVerticalScrollerRepresenter class]]; }
- (BOOL)ibContainsLineNumsView { return !![self ibRepresenterOfClass:[HFLineCountingRepresenter class]]; }

- (void)setIbContainsHexView:(BOOL)val { [self ibAddOrRemove:val representerOfClass:[HFHexTextRepresenter class]]; }
- (void)setIbContainsASCIIView:(BOOL)val { [self ibAddOrRemove:val representerOfClass:[HFStringEncodingTextRepresenter class]]; }
- (void)setIbContainsScrollerView:(BOOL)val { [self ibAddOrRemove:val representerOfClass:[HFVerticalScrollerRepresenter class]]; }
- (void)setIbContainsLineNumsView:(BOOL)val { [self ibAddOrRemove:val representerOfClass:[HFLineCountingRepresenter class]]; }

- (BOOL)ibColorIsDefaultAlternatingRows {
    return [[self backgroundColors] isEqual:[NSColor controlAlternatingRowBackgroundColors]];
}

- (void)setIbColorIsDefaultAlternatingRows:(BOOL)val {
    if (val) {
        [self setBackgroundColors:[NSColor controlAlternatingRowBackgroundColors]];
    }
    else {
        [self setBackgroundColors:[NSArray arrayWithObject:[NSColor whiteColor]]];
    }
}

- (NSColor *)ibSingleBackgroundColor {
    return [[self backgroundColors] lastObject];
}

- (void)setIbSingleBackgroundColor:(NSColor *)color {
    [self setBackgroundColors:[NSArray arrayWithObject:color]];
}

@end
