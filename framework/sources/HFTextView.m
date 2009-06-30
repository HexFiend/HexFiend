//
//  HFTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 6/28/09.
//  Copyright 2009 Apple Computer. All rights reserved.
//

#import <HexFiend/HFTextView.h>
#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFLayoutRepresenter.h>
#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFStringEncodingTextRepresenter.h>
#import <HexFiend/HFVerticalScrollerRepresenter.h>

@implementation HFTextView

- (void)_sharedInitHFTextView {
    HFBTreeByteArray *byteArray = [[HFBTreeByteArray alloc] init];
    [dataController setByteArray:byteArray];
    [byteArray release];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    dataController = [[coder decodeObjectForKey:@"HFController"] retain];
    layoutRepresenter = [[coder decodeObjectForKey:@"HFLayoutRepresenter"] retain];
    backgroundColors = [[coder decodeObjectForKey:@"HFBackgroundColors"] retain];
    [self _sharedInitHFTextView];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];    
    [coder encodeObject:dataController forKey:@"HFController"];
    [coder encodeObject:layoutRepresenter forKey:@"HFLayoutRepresenter"];
    [coder encodeObject:backgroundColors forKey:@"HFBackgroundColors"];
}

- (id)initWithFrame:(NSRect)frame {
    [super initWithFrame:frame];
    
    backgroundColors = [[NSColor controlAlternatingRowBackgroundColors] copy];
    
    dataController = [[HFController alloc] init];
    layoutRepresenter = [[HFLayoutRepresenter alloc] init];
    [dataController addRepresenter:layoutRepresenter];
    
    HFHexTextRepresenter *hexRep = [[[HFHexTextRepresenter alloc] init] autorelease];
    [[hexRep view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable]; //by default make the hex view fill remaining space
    
    HFStringEncodingTextRepresenter *textRep = [[[HFStringEncodingTextRepresenter alloc] init] autorelease];
    HFVerticalScrollerRepresenter *scrollRep = [[[HFVerticalScrollerRepresenter alloc] init] autorelease];

    [dataController addRepresenter:hexRep];
    [dataController addRepresenter:textRep];
    [dataController addRepresenter:scrollRep];
    [layoutRepresenter addRepresenter:hexRep];
    [layoutRepresenter addRepresenter:textRep];
    [layoutRepresenter addRepresenter:scrollRep];
    
    NSView *layoutView = [layoutRepresenter view];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [layoutView setFrame:[self bounds]];
    [self addSubview:layoutView];
    
    [self _sharedInitHFTextView];
    
    return self;
}

- (HFLayoutRepresenter *)layoutRepresenter {
    return layoutRepresenter;
}

- (HFController *)controller {
    return dataController;
}

- (NSArray *)backgroundColors {
    return backgroundColors;
}

- (void)setBackgroundColors:(NSArray *)colors {
    if (colors != backgroundColors) {
        [backgroundColors release];
        backgroundColors = [colors copy];
        id rep;
        NSEnumerator *enumer = [[[self controller] representers] objectEnumerator];
        while ((rep = [enumer nextObject])) {
            if ([rep isKindOfClass:[HFTextRepresenter class]]) {
                [rep setRowBackgroundColors:colors];
            }
        }
    }
}

- (void)dealloc {
    [dataController release];
    [layoutRepresenter release];
    [backgroundColors release];
    [super dealloc];
}

@end
