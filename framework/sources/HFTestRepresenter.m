//
//  HFTestRepresenter.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "HFTestRepresenter.h"
#import "HFController.h"

@interface HFTestRepresenterView : NSView {
    @public
    HFTestRepresenter *representer;
}

@end

@implementation HFTestRepresenterView

- (void)drawRect:(NSRect)rect {
    [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
    [[NSColor colorWithCalibratedRed:(CGFloat).8 green:(CGFloat)1 blue:(CGFloat).8 alpha:(CGFloat)1] set];
    NSRectFill(rect);
    
    [[NSColor blackColor] set];
    NSMutableString *stats;
    if (! [representer controller]) stats = nil;
    else {
        stats = [NSMutableString stringWithFormat:@"displayedLineRange:\t%@", HFRangeToString([[representer controller] displayedContentsRange])];
        [stats appendFormat:@"\nselectedContentsRanges:"];
        FOREACH(HFRangeWrapper*, wrapper, [[representer controller] selectedContentsRanges]) {
            [stats appendFormat:@"\n\t%@", HFRangeToString([wrapper HFRange])];
        }
    }
    [stats drawAtPoint:NSMakePoint(50, 50) withAttributes:nil];
}

- (BOOL)isFlipped { return YES; }

@end

@implementation HFTestRepresenter

- (NSView *)createView {
    HFTestRepresenterView *view = [[HFTestRepresenterView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];
    view->representer = self;
    return view;
}

@end
