//
//  HFHexPasteboardOwner.h
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFPasteboardOwner.h>

@interface HFHexPasteboardOwner : HFPasteboardOwner {
    NSUInteger _bytesPerColumn;
}
@property (nonatomic) NSUInteger bytesPerColumn;
@end
