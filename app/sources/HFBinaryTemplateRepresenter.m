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
    return NSMakePoint(3, 0);
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger __unused)bytesPerLine {
    return ceil([[NSUserDefaults standardUserDefaults] doubleForKey:@"BinaryTemplateRepresenterWidth"]);
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
    NSString *title = [NSString stringWithFormat:NSLocalizedString(@"Anchor Template at Offset %llu", nil), self.menuPosition];
    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(anchorTemplatesAt:) keyEquivalent:@""];
    menuItem.target = self;
    menuItem.enabled = position < self.controller.contentsLength;
    [menu addItem:menuItem];
}

- (void)anchorTemplatesAt:(id __unused)sender {
    [self.viewController anchorTo:self.menuPosition];
}

@end
