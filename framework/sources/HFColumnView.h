//
//  HFColumnView.h
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/1/19.
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <HexFiend/HFColumnRepresenter.h>
#import <HexFiend/HFHexGlyphTable.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFColumnView : NSView

@property (weak) HFColumnRepresenter *representer;
@property CGFloat lineCountingWidth;
@property HFHexGlyphTable *glyphTable;

@end

NS_ASSUME_NONNULL_END
