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

@property (strong, nonatomic) HFBinaryTemplateController *viewController;
@property NSUInteger menuPosition;

@end

@implementation HFBinaryTemplateRepresenter

- (HFBinaryTemplateController *)viewController {
    if (!_viewController) {
        _viewController = [[HFBinaryTemplateController alloc] init];
    }
    return _viewController;
}

- (NSView *)createView {
    return self.viewController.view;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(5, 0);
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger __unused)bytesPerLine {
    return ceil(self.viewWidth);
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
    
    NSString *anchorTitle = [NSString stringWithFormat:NSLocalizedString(@"Anchor Template at Offset %lu", nil), (unsigned long)self.menuPosition];
    NSMenuItem *anchorMenuItem = [[NSMenuItem alloc] initWithTitle:anchorTitle action:@selector(anchorTemplatesAt:) keyEquivalent:@""];
    anchorMenuItem.target = self;
    anchorMenuItem.enabled = position < self.controller.contentsLength;
    [menu addItem:anchorMenuItem];
    
    if (self.viewController.hasTemplate) {
        NSString *gotoInTemplateTitle = NSLocalizedString(@"Show in Template", nil);
        NSMenuItem *gotoInTemplateMenuItem = [[NSMenuItem alloc] initWithTitle:gotoInTemplateTitle action:@selector(showInTemplateAt:) keyEquivalent:@""];
        gotoInTemplateMenuItem.target = self;
        gotoInTemplateMenuItem.enabled = position < self.controller.contentsLength;
        [menu addItem:gotoInTemplateMenuItem];
    }
}

- (void)anchorTemplatesAt:(id __unused)sender {
    [self.viewController anchorTo:self.menuPosition];
}

- (void)showInTemplateAt:(id __unused)sender {
    [self.viewController showInTemplateAt:self.menuPosition];
}

@end
