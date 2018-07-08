//
//  HFTextVisualStyle.h
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

@interface HFTextVisualStyleRun : NSObject

#if TARGET_OS_IPHONE
@property (nonatomic, copy) UIColor *foregroundColor;
@property (nonatomic, copy) UIColor *backgroundColor;
#else
@property (nonatomic, copy) NSColor *foregroundColor;
@property (nonatomic, copy) NSColor *backgroundColor;
#endif
@property (nonatomic) NSRange range;
@property (nonatomic) BOOL shouldDraw;
@property (nonatomic) CGFloat scale;
@property (nonatomic, copy) NSIndexSet *bookmarkStarts;
@property (nonatomic, copy) NSIndexSet *bookmarkExtents;
@property (nonatomic, copy) NSIndexSet *bookmarkEnds;

- (void)set;

@end
