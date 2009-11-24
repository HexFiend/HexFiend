//
//  HFTextView.m
//  HexFiend_2
//
//  Created by Peter Ammon on 6/28/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextView.h>
#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFLayoutRepresenter.h>
#import <HexFiend/HFHexTextRepresenter.h>
#import <HexFiend/HFStringEncodingTextRepresenter.h>
#import <HexFiend/HFVerticalScrollerRepresenter.h>
#import <HexFiend/HFSharedMemoryByteSlice.h>
#import <HexFiend/HFFullMemoryByteSlice.h>
#import "HFByteArrayProxiedData.h"

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
        NSNumber *propertyNumber = [[note userInfo] objectForKey:HFControllerChangedPropertiesKey];
#if __LP64__
        NSUInteger propertyMask = [propertyNumber unsignedIntegerValue];
#else
        NSUInteger propertyMask = [propertyNumber unsignedIntValue];
#endif
    if (propertyMask & (HFControllerContentValue | HFControllerContentLength)) {
        /* Note that this isn't quite right.  If we don't have any cached data, then we can't provide the "before" data for this change.  In practice, this is likely harmless, but it's still something that should be fixed at some point.
        */
        [self willChangeValueForKey:@"data"];
        [cachedData release];
        cachedData = nil; //set this to nil so that it gets recomputed on demand
        [self didChangeValueForKey:@"data"];
    }
    if ([delegate respondsToSelector:@selector(hexTextView:didChangeProperties:)]) {
        [(id <HFTextViewDelegate>)delegate hexTextView:self didChangeProperties:propertyMask];
    }
    
    /* Apply any view->model bindings */
    NSDictionary *bindingInfo = [self infoForBinding:@"data"];
    if (bindingInfo != nil) {
        NSData *valueToSet = [self data];
        id observedObject = [bindingInfo objectForKey:NSObservedObjectKey];
        NSString *keyPath = [bindingInfo objectForKey:NSObservedKeyPathKey];
        NSValueTransformer *transformer = [[bindingInfo objectForKey:NSOptionsKey] objectForKey:NSValueTransformerBindingOption];
        if ([transformer isKindOfClass:[NSValueTransformer class]] && [[transformer class] allowsReverseTransformation]) { //often the transformer is NSNull :(
            valueToSet = [transformer reverseTransformedValue:valueToSet];
        }
        [observedObject setValue:valueToSet forKeyPath:keyPath];
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

- (HFByteArray *)byteArray {
    return [[self controller] byteArray];
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

- (void)setDelegate:(id)del {
    delegate = del;
}

- (id)delegate {
    return delegate;
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

- (NSData *)data {
    if (! cachedData) {
        HFByteArray *copiedArray = [[dataController byteArray] copy];
        cachedData = [[HFByteArrayProxiedData alloc] initWithByteArray:copiedArray];
        [copiedArray release];
    }
    return cachedData;
}

- (void)setData:(NSData *)data {
    if ([data length] == 0 && [cachedData length] == 0) return; //prevent an infinite regress where someone tries to set a nil data on us
    if (data == nil || data != cachedData) {
        [cachedData release];
        cachedData = [data copy];
        HFByteArray *newArray = [[HFBTreeByteArray alloc] init];
        if (cachedData) {
            HFByteSlice *newSlice = [[HFFullMemoryByteSlice alloc] initWithData:cachedData];
            [newArray insertByteSlice:newSlice inRange:HFRangeMake(0, 0)];
            [newSlice release];
        }
        [dataController replaceByteArray:newArray];
        [newArray release];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFControllerDidChangePropertiesNotification object:dataController];
    [dataController release];
    [layoutRepresenter release];
    [backgroundColors release];
    [cachedData release];
    [super dealloc];
}

+ (void)initialize {
    if (self == [HFTextView class]) {
        [self exposeBinding:@"data"];
    }
    
}

@end
