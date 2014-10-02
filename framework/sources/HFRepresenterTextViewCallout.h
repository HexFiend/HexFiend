//
//  HFRepresenterTextViewCallout.h
//  HexFiend_2
//
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HFRepresenterTextView;

#define kHFRepresenterTextViewCalloutMaxGlyphCount 2u

@interface HFRepresenterTextViewCallout : NSObject {
    CGFloat rotation;
    NSPoint tipOrigin;
    NSPoint pinStart, pinEnd;
}

@property(nonatomic) NSInteger byteOffset;
@property(nonatomic, copy) NSColor *color;
@property(nonatomic, copy) NSString *label;
@property(nonatomic, retain) id representedObject;
@property(readonly) NSRect rect;

+ (void)layoutCallouts:(NSArray *)callouts inView:(HFRepresenterTextView *)textView;

- (void)drawShadowWithClip:(NSRect)clip;
- (void)drawWithClip:(NSRect)clip;

@end
