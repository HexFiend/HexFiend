//
//  HFRepresenterTextViewCallout.h
//  HexFiend_2
//
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class HFRepresenterTextView;

#define kHFRepresenterTextViewCalloutMaxGlyphCount 2u

@interface HFRepresenterTextViewCallout : NSObject {
    CGFloat rotation;
    NSPoint tipOrigin;
    NSPoint pinStart, pinEnd;
}

@property(nonatomic) NSInteger byteOffset;
@property(nullable, nonatomic, copy) NSColor *color;
@property(nullable, nonatomic, copy) NSString *label;
@property(nullable, nonatomic, retain) id representedObject;
@property(readonly) NSRect rect;

+ (void)layoutCallouts:(NSArray *)callouts inView:(HFRepresenterTextView *)textView;

- (void)drawShadowWithClip:(NSRect)clip;
- (void)drawWithClip:(NSRect)clip;

@end

NS_ASSUME_NONNULL_END

