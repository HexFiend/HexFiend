//
//  HFTextVisualStyle.h
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface HFTextVisualStyleRun : NSObject {}

@property (nonatomic, copy) NSColor *foregroundColor;
@property (nonatomic, copy) NSColor *backgroundColor;
@property (nonatomic) NSRange range;
@property (nonatomic) BOOL shouldDraw;
@property (nonatomic) CGFloat scale;
@property (nonatomic, copy) NSIndexSet *bookmarkStarts;
@property (nonatomic, copy) NSIndexSet *bookmarkExtents;
@property (nonatomic, copy) NSIndexSet *bookmarkEnds;

- (void)set;

@end
