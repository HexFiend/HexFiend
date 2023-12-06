//
//  DocumentWindow.m
//  HexFiend_2
//
//  Created by Paul Eipper on 25/6/2012.
//  Copyright (c) 2012 ridiculous_fish. All rights reserved.
//

#import "DocumentWindow.h"
#import <HexFiend/HexFiend.h>

@implementation DocumentWindow

@dynamic delegate;

- (void)awakeFromNib {
    [self registerForDraggedTypes:@[NSPasteboardTypeFileURL]];
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender {
    USE(sender);
    return NSDragOperationGeneric;
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    return [self.delegate performDragOperation:sender];
}

@end
