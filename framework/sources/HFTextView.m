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
#import <HexFiend/HFSharedMemoryByteSlice.h>

@implementation HFTextView

- (void)_sharedInitHFTextViewWithMutableData:(NSMutableData *)mutableData {
    HFBTreeByteArray *byteArray = [[HFBTreeByteArray alloc] init];
    if (mutableData) {
        HFSharedMemoryByteSlice *byteSlice = [[HFSharedMemoryByteSlice alloc] initWithData:mutableData];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [byteSlice release];
    }
    [dataController setByteArray:byteArray];
    [byteArray release];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_HFControllerDidChangeProperties:) name:HFControllerDidChangePropertiesNotification object:dataController];
}

- (void)_HFControllerDidChangeProperties:(NSNotification *)note {
    if ([delegate respondsToSelector:@selector(hexTextView:didChangeProperties:)]) {
        NSNumber *propertyNumber = [[note userInfo] objectForKey:HFControllerChangedPropertiesKey];
#if __LP64__
        NSUInteger propertyMask = [propertyNumber unsignedIntegerValue];
#else
        NSUInteger propertyMask = [propertyNumber unsignedIntValue];
#endif
        [(id <HFTextViewDelegate>) delegate hexTextView:self didChangeProperties:propertyMask];
        
    }
}

- (NSRect)_desiredFrameForLayoutView {
    NSRect result = [self bounds];
    if (bordered) result = NSInsetRect(result, 1, 1);
    return result;
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super initWithCoder:coder];
    dataController = [[coder decodeObjectForKey:@"HFController"] retain];
    layoutRepresenter = [[coder decodeObjectForKey:@"HFLayoutRepresenter"] retain];
    backgroundColors = [[coder decodeObjectForKey:@"HFBackgroundColors"] retain];
    bordered = [coder decodeBoolForKey:@"HFBordered"];
    NSMutableData *byteArrayData = [coder decodeObjectForKey:@"HFByteArrayMutableData"]; //may be nil
    [self _sharedInitHFTextViewWithMutableData:byteArrayData];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];    
    [coder encodeObject:dataController forKey:@"HFController"];
    [coder encodeObject:layoutRepresenter forKey:@"HFLayoutRepresenter"];
    [coder encodeObject:backgroundColors forKey:@"HFBackgroundColors"];
    [coder encodeBool:bordered forKey:@"HFBordered"];
    /* We save our ByteArray if it's 64K or less */
    HFByteArray *byteArray = [dataController byteArray];
    unsigned long long byteArrayLength = [byteArray length];
    if (byteArrayLength > 0 && byteArrayLength <= 64 * 1024 * 1024) {
        NSUInteger length = ll2l(byteArrayLength);
        NSMutableData *byteArrayData = [[NSMutableData alloc] initWithLength:length];
        if (byteArrayData) {
            [byteArray copyBytes:[byteArrayData mutableBytes] range:HFRangeMake(0, byteArrayLength)];
            [coder encodeObject:byteArrayData forKey:@"HFByteArrayMutableData"];
            [byteArrayData release];
        }
    }
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
    [layoutView setFrame:[self _desiredFrameForLayoutView]];
    [self addSubview:layoutView];
    
    [self _sharedInitHFTextViewWithMutableData:NULL];
    
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

- (void)drawRect:(NSRect)clipRect {
    USE(clipRect);
    if (bordered) {
        CGFloat topColor = (CGFloat).55;
        CGFloat otherColors = (CGFloat).745;
        NSRect rects[2];
        rects[0] = [self bounds];
        rects[1] = rects[0];
        if (! [self isFlipped]) {
            rects[1].origin.y = NSMaxY(rects[1]) - 1;
        }
        rects[1].size.height = 1;
        const CGFloat grays[2] = {otherColors, topColor};
        NSRectFillListWithGrays(rects, grays, 2);
    }
}

- (void)setBordered:(BOOL)val {
    bordered = val;
    [[layoutRepresenter view] setFrame:[self _desiredFrameForLayoutView]];
}

- (BOOL)bordered {
    return bordered;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFControllerDidChangePropertiesNotification object:dataController];
    [dataController release];
    [layoutRepresenter release];
    [backgroundColors release];
    [super dealloc];
}

@end
