//
//  HFTextView.m
//  HexFiend_2
//
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
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>
#import "HFByteArrayProxiedData.h"

@implementation HFTextView

- (void)_sharedInitHFTextViewWithMutableData:(NSMutableData *)mutableData {
    HFBTreeByteArray *byteArray = [[HFBTreeByteArray alloc] init];
    if (mutableData) {
        HFSharedMemoryByteSlice *byteSlice = [[HFSharedMemoryByteSlice alloc] initWithData:mutableData];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
    }
    [dataController setByteArray:byteArray];
}

- (void)_HFControllerDidChangeProperties:(NSNotification *)note {
    NSNumber *propertyNumber = [note userInfo][HFControllerChangedPropertiesKey];
    NSUInteger propertyMask = [propertyNumber unsignedIntegerValue];
    if (propertyMask & (HFControllerContentValue | HFControllerContentLength)) {
        /* Note that this isn't quite right.  If we don't have any cached data, then we can't provide the "before" data for this change.  In practice, this is likely harmless, but it's still something that should be fixed at some point.
        */
        [self willChangeValueForKey:@"data"];
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
        id observedObject = bindingInfo[NSObservedObjectKey];
        NSString *keyPath = bindingInfo[NSObservedKeyPathKey];
        NSValueTransformer *transformer = bindingInfo[NSOptionsKey][NSValueTransformerBindingOption];
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

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    dataController = [coder decodeObjectForKey:@"HFController"];
    layoutRepresenter = [coder decodeObjectForKey:@"HFLayoutRepresenter"];
    _backgroundColors = [coder decodeObjectForKey:@"HFBackgroundColors"];
    bordered = [coder decodeBoolForKey:@"HFBordered"];
    NSMutableData *byteArrayData = [coder decodeObjectForKey:@"HFByteArrayMutableData"]; //may be nil
    [self _sharedInitHFTextViewWithMutableData:byteArrayData];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_HFControllerDidChangeProperties:) name:HFControllerDidChangePropertiesNotification object:dataController];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];    
    [coder encodeObject:dataController forKey:@"HFController"];
    [coder encodeObject:layoutRepresenter forKey:@"HFLayoutRepresenter"];
    [coder encodeObject:_backgroundColors forKey:@"HFBackgroundColors"];
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
        }
    }
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    
    _backgroundColors = [NSColor controlAlternatingRowBackgroundColors];
    
    dataController = [[HFController alloc] init];
    layoutRepresenter = [[HFLayoutRepresenter alloc] init];
    [dataController addRepresenter:layoutRepresenter];
    
    HFHexTextRepresenter *hexRep = [[HFHexTextRepresenter alloc] init];
    [(NSView *)[hexRep view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable]; //by default make the hex view fill remaining space
    
    HFStringEncodingTextRepresenter *textRep = [[HFStringEncodingTextRepresenter alloc] init];
    HFVerticalScrollerRepresenter *scrollRep = [[HFVerticalScrollerRepresenter alloc] init];

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_HFControllerDidChangeProperties:) name:HFControllerDidChangePropertiesNotification object:dataController];
    
    return self;
}

- (HFLayoutRepresenter *)layoutRepresenter {
    return layoutRepresenter;
}

- (void)setLayoutRepresenter:(HFLayoutRepresenter *)val {
    if (val == layoutRepresenter) return;
    
    /* Remove the old view and representer */
    NSView *oldLayoutView = [layoutRepresenter view];
    [oldLayoutView removeFromSuperview];
    
    /* Install the new view and representer */
    layoutRepresenter = val;
    NSView *newLayoutView = [layoutRepresenter view];
    [newLayoutView setFrame:[self _desiredFrameForLayoutView]];
    [self addSubview:newLayoutView];
}

- (HFController *)controller {
    return dataController;
}

- (void)setController:(HFController *)controller {
    if (controller == dataController) return;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFControllerDidChangePropertiesNotification object:dataController];
    dataController = controller;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_HFControllerDidChangeProperties:) name:HFControllerDidChangePropertiesNotification object:dataController];
}

- (HFByteArray *)byteArray {
    return [[self controller] byteArray];
}

- (void)setBackgroundColors:(NSArray *)colors {
    if (colors != _backgroundColors) {
        _backgroundColors = [colors copy];
        id rep;
        NSEnumerator *enumer = [[self controller].representers objectEnumerator];
        while ((rep = [enumer nextObject])) {
            if ([rep isKindOfClass:[HFTextRepresenter class]]) {
                ((HFTextRepresenter*)rep).rowBackgroundColors = colors;
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
    }
    return cachedData;
}

- (void)setData:(NSData *)data {
    if (data == nil && [cachedData length] == 0) return; //prevent an infinite regress where someone tries to set a nil data on us
    if (data == nil || data != cachedData) {
        cachedData = [data copy];
        HFByteArray *newArray = [[HFBTreeByteArray alloc] init];
        if (cachedData) {
            HFByteSlice *newSlice = [[HFFullMemoryByteSlice alloc] initWithData:cachedData];
            [newArray insertByteSlice:newSlice inRange:HFRangeMake(0, 0)];
        }
        [dataController replaceByteArray:newArray];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFControllerDidChangePropertiesNotification object:dataController];
}

+ (void)initialize {
    if (self == [HFTextView class]) {
        [self exposeBinding:@"data"];
    }
}

@end
