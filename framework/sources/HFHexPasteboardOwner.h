//
//  HFHexPasteboardOwner.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFPasteboardOwner.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFHexPasteboardOwner : HFPasteboardOwner

@property (nonatomic) NSUInteger bytesPerColumn;

- (NSString *)stringFromByteArray:(HFByteArray *)byteArray ofLength:(unsigned long long)length trackingProgress:(HFProgressTracker *)tracker;

@end

NS_ASSUME_NONNULL_END
