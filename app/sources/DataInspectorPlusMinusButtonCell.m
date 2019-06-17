//
//  DataInspectorPlusMinusButtonCell.m
//  HexFiend_2
//
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "DataInspectorPlusMinusButtonCell.h"

@implementation DataInspectorPlusMinusButtonCell

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    [self setBezelStyle:NSRoundRectBezelStyle];
    return self;
}

- (void)drawDataInspectorTitleWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    const BOOL isPlus = [[self title] isEqual:@"+"];
    const unsigned char grayColor = 0x73;
    const unsigned char alpha = 0xFF;
#if __BIG_ENDIAN__
    const unsigned short X = (grayColor << 8) | alpha ;
#else
    const unsigned short X = (alpha << 8) | grayColor;
#endif
    const NSUInteger bytesPerPixel = sizeof X;
    const unsigned short plusData[] = {
        0,0,0,X,X,0,0,0,
        0,0,0,X,X,0,0,0,
        0,0,0,X,X,0,0,0,
        X,X,X,X,X,X,X,X,
        X,X,X,X,X,X,X,X,
        0,0,0,X,X,0,0,0,
        0,0,0,X,X,0,0,0,
        0,0,0,X,X,0,0,0
    };
    
    const unsigned short minusData[] = {
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        X,X,X,X,X,X,X,X,
        X,X,X,X,X,X,X,X,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0
    };
    
    const unsigned char * const bitmapData = (const unsigned char *)(isPlus ? plusData : minusData);
    
    NSInteger width = 8, height = 8;
    assert(width * height * bytesPerPixel == sizeof plusData);
    assert(width * height * bytesPerPixel == sizeof minusData);
    NSRect bitmapRect = NSMakeRect(NSMidX(cellFrame) - width/2, NSMidY(cellFrame) - height/2, width, height);
    bitmapRect = [controlView centerScanRect:bitmapRect];
    
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, bitmapData, width * height * bytesPerPixel, NULL);
    CGImageRef image = CGImageCreate(width, height, CHAR_BIT, bytesPerPixel * CHAR_BIT, bytesPerPixel * width, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast, provider, NULL, YES, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(space);
    [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositingOperationSourceOver];
    CGContextDrawImage(HFGraphicsGetCurrentContext(), *(CGRect *)&bitmapRect, image);
    CGImageRelease(image);
}

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView {
    /* Defeat title drawing by doing nothing */
    USE(title);
    USE(frame);
    USE(controlView);
    return NSZeroRect;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawWithFrame:cellFrame inView:controlView];
    [self drawDataInspectorTitleWithFrame:cellFrame inView:controlView];
}

@end
