//
//  HFBinaryTemplateRepresenter.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/6/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFBinaryTemplateRepresenter.h"
#import "HFBinaryTemplateController.h"
#import "HFTemplateNode.h"
#import <HexFiend/HFRepresenterTextView.h>

@interface HFBinaryTemplateRepresenter ()

@property (strong) HFBinaryTemplateController *viewController;
@property NSUInteger menuPosition;

@end

@implementation HFBinaryTemplateRepresenter

- (NSView *)createView {
    self.viewController = [[HFBinaryTemplateController alloc] init];
    return self.viewController.view;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(3, 0);
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger __unused)bytesPerLine {
    return 250;
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & HFControllerContentValue) {
        [self.viewController rerunTemplateWithController:self.controller];
    }
}

- (void)representerTextView:(HFRepresenterTextView * __unused)sender menu:(NSMenu *)menu forEvent:(NSEvent * __unused)event atPosition:(NSUInteger)position {
    if (menu.numberOfItems > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
    }
    self.menuPosition = position;
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Anchor Template at %llu", nil), self.menuPosition];
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(anchorTemplatesAt:) keyEquivalent:@""];
    menuItem.target = self;
    [menu addItem:menuItem];
}

- (void)anchorTemplatesAt:(id __unused)sender {
    [self.viewController anchorTo:self.menuPosition];
}

@end
