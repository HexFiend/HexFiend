//
//  DocumentWindow.h
//  HexFiend_2
//
//  Created by Paul Eipper on 25/6/2012.
//  Copyright (c) 2012 ridiculous_fish. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol DragDropDelegate <NSObject>
- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
@end

@protocol DocumentWindowDelegate <NSWindowDelegate>
@optional
- (void)window:(NSWindow *)w didSaveFrameWithName:(NSString *)name;
@end

@interface DocumentWindow : NSWindow
@property (assign) id<DocumentWindowDelegate, DragDropDelegate>delegate;
@end
