//
//  MyDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MyDocument.h"
#import <HexFiend/HFTestRepresenter.h>

@implementation MyDocument

- (NSString *)windowNibName {
    // Implement this to return a nib to load OR implement -makeWindowControllers to manually create your controllers.
    return @"MyDocument";
}

- (NSWindow *)window {
    NSArray *windowControllers = [self windowControllers];
    HFASSERT([windowControllers count] == 1);
    return [[windowControllers objectAtIndex:0] window];
}

- (NSArray *)representers {
    return [NSArray arrayWithObjects:debugRepresenter, hexRepresenter, asciiRepresenter, scrollRepresenter, nil];
}


- (void)showViewForRepresenter:(HFRepresenter *)rep {
    NSView *repView = [rep view];
    HFASSERT([repView superview] == nil && [repView window] == nil);
    NSRect containerBounds = [containerView bounds];
    NSRect viewFrame = containerBounds;
    [repView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [repView setFrame:viewFrame];
    [containerView addSubview:repView];
}

- (void)hideViewForRepresenter:(HFRepresenter *)rep {
    NSView *repView = [rep view];
    HFASSERT([repView superview] == containerView && [repView window] == [self window]);
    [repView removeFromSuperview];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
    USE(windowController);
    [self showViewForRepresenter:hexRepresenter];
}

- init {
    [super init];
    debugRepresenter = [[[HFTestRepresenter alloc] init] autorelease];
    hexRepresenter = [[[HFHexTextRepresenter alloc] init] autorelease];
    
    controller = [[HFController alloc] init];
    FOREACH(HFRepresenter*, rep, [self representers]) {
        [controller addRepresenter:rep];
    }
    return self;
}

- (void)dealloc {
    [controller release];
    [super dealloc];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    USE(typeName);
    USE(outError);
    // Insert code here to write your document to data of the specified type. If the given outError != NULL, ensure that you set *outError when returning nil.

    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    // For applications targeted for Panther or earlier systems, you should use the deprecated API -dataRepresentationOfType:. In this case you can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    NSParameterAssert(data != NULL);
    
    USE(data);
    USE(typeName);
    USE(outError);
    
    HFFullMemoryByteArray *byteArray = [[[HFFullMemoryByteArray alloc] init] autorelease];
    [byteArray insertByteSlice:[[[HFFullMemoryByteSlice alloc] initWithData:data] autorelease] inRange:HFRangeMake(0, 0)];
    [controller setByteArray:byteArray];
    
    // Insert code here to read your document from the given data of the specified type.  If the given outError != NULL, ensure that you set *outError when returning NO.

    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead. 
    
    // For applications targeted for Panther or earlier systems, you should use the deprecated API -loadDataRepresentation:ofType. In this case you can also choose to override -readFromFile:ofType: or -loadFileWrapperRepresentation:ofType: instead.
    
    return YES;
}

- (IBAction)toggleVisibleControllerView:(id)sender {
    USE(sender);
    NSUInteger arrayIndex = [sender tag] - 1;
    NSArray *representers = [self representers];
    if (arrayIndex >= [representers count]) {
        NSBeep();
    }
    else {
        HFRepresenter *rep = [representers objectAtIndex:arrayIndex];
        NSView *repView = [rep view];
        if ([repView window] == [self window]) {
            [self hideViewForRepresenter:rep];
        }
        else {
            [self showViewForRepresenter:rep];
        }
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if ([item action] == @selector(toggleVisibleControllerView:)) {
        NSUInteger arrayIndex = [item tag] - 1;
        NSArray *representers = [self representers];
        if (arrayIndex >= [representers count]) {
            return NO;
        }
        else {
            HFRepresenter *rep = [representers objectAtIndex:arrayIndex];
            NSView *repView = [rep view];
            [item setState: ([repView window] == [self window])];
            return YES;
        }
    }
    else return [super validateMenuItem:item];
}

@end
