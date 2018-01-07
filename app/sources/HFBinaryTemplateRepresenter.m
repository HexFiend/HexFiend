//
//  HFBinaryTemplateRepresenter.m
//  HexFiend_2
//
//  Created by Kevin Wojniak on 1/6/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFBinaryTemplateRepresenter.h"
#import "HFBinaryTemplateController.h"
#import "HFTclTemplateController.h"
#import "HFTemplateNode.h"

@interface HFBinaryTemplateRepresenter ()

@property (strong) HFBinaryTemplateController *viewController;
@property (strong) HFTclTemplateController *templateController;
@property unsigned long long lastMinimumSelectionLocation;

@end

@implementation HFBinaryTemplateRepresenter

- (instancetype)init {
    if ((self = [super init]) == nil) {
        return nil;
    }

    _templateController = [[HFTclTemplateController alloc] init];
    _lastMinimumSelectionLocation = -1;

    return self;
}

- (NSView *)createView {
    self.viewController = [[HFBinaryTemplateController alloc] initWithNibName:@"BinaryTemplateController" bundle:nil];
    return self.viewController.view;
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(3, 0);
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger __unused)bytesPerLine {
    return 250;
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & HFControllerSelectedRanges) {
        if (self.controller.contentsLength > 0 && self.controller.minimumSelectionLocation != self.lastMinimumSelectionLocation) {
            self.lastMinimumSelectionLocation = self.controller.minimumSelectionLocation;
            [self rerunTemplate];
        }
    }
}

- (void)rerunTemplate {
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/hexfiend.tcl"];
    NSString *errorMessage = nil;
    HFTemplateNode *node = [self.templateController evaluateScript:path forController:self.controller error:&errorMessage];
    [self.viewController setRootNode:node error:errorMessage];
}

@end
