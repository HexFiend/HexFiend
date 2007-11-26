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

- (NSArray *)visibleViews {
    NSMutableArray *result = [NSMutableArray array];
    NSEnumerator *enumer = [[self representers] objectEnumerator];
    NSWindow *window = [self window];
    HFRepresenter *rep;
    while ((rep = [enumer nextObject])) {
        NSView *view = [rep view];
        if ([view window] == window) [result addObject:view];
    }
    return result;
}

- (void)layoutViewsWithBytesPerLine:(NSUInteger)bytesPerLine contentHeight:(CGFloat)contentHeight {
    NSWindow *window = [self window];
    NSDisableScreenUpdates();
    
    NSArray *visibleViews = [self visibleViews];
    NSView *hexView = [hexRepresenter view], *asciiView = [asciiRepresenter view], *scrollerView = [scrollRepresenter view];
    NSRect hexViewFrame = NSZeroRect, asciiViewFrame = NSZeroRect, scrollerViewFrame = NSZeroRect;
    double maxXSoFar = 0;
    
    if ([visibleViews containsObject:hexView]) {
        [hexView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable | NSViewMaxXMargin];
        hexViewFrame.size.width = [hexRepresenter minimumViewWidthForBytesPerLine:bytesPerLine];
        hexViewFrame.size.height = contentHeight;
        maxXSoFar = fmax(maxXSoFar, NSMaxX(hexViewFrame));
    }
    if ([visibleViews containsObject:asciiView]) {
        [asciiView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable | NSViewMinXMargin];
        asciiViewFrame.origin.x = NSMaxX(hexViewFrame);
        asciiViewFrame.size.width = [asciiRepresenter minimumViewWidthForBytesPerLine:bytesPerLine];
        asciiViewFrame.size.height = contentHeight;
        maxXSoFar = fmax(maxXSoFar, NSMaxX(asciiViewFrame));
    }
    if ([visibleViews containsObject:scrollerView]) {
        [scrollerView setAutoresizingMask:NSViewMinXMargin | NSViewHeightSizable];
        scrollerViewFrame.origin.x = (CGFloat)maxXSoFar;
        scrollerViewFrame.size.height = contentHeight;
        scrollerViewFrame.size.width = [NSScroller scrollerWidthForControlSize:NSRegularControlSize];
        maxXSoFar = fmax(maxXSoFar, NSMaxX(scrollerViewFrame));
    }
    
    if (! NSIsEmptyRect(hexViewFrame) && ! NSIsEmptyRect(asciiViewFrame)) {
        asciiViewFrame.origin.x += 0;
    }
    
    NSRect containerFrame = NSZeroRect;
    containerFrame.size.width = (CGFloat)maxXSoFar;    
    containerFrame.size.height = (CGFloat)fmax(NSHeight(hexViewFrame), NSHeight(asciiViewFrame));

    //don't use setContentSize: because it triggers an immediate redisplay
    NSSize windowFrameSize = [window frameRectForContentRect:(NSRect){NSZeroPoint, containerFrame.size}].size;
    NSPoint windowFrameOrigin = [window frame].origin;
    [window setFrame:(NSRect){windowFrameOrigin, windowFrameSize} display:NO];
    
    if ([visibleViews containsObject:hexView]) [hexView setFrame:hexViewFrame];
    if ([visibleViews containsObject:asciiView]) [asciiView setFrame:asciiViewFrame];
    if ([visibleViews containsObject:scrollerView]) [scrollerView setFrame:scrollerViewFrame];
    [containerView setFrame:containerFrame];
    
    [window display];
    
    NSEnableScreenUpdates();
}

- (void)showViewForRepresenter:(HFRepresenter *)rep {
    NSView *repView = [rep view];
    HFASSERT([repView superview] == nil && [repView window] == nil);
    [containerView addSubview:[rep view]];
    [self layoutViewsWithBytesPerLine:[controller bytesPerLine] contentHeight:NSHeight([containerView bounds])];
    [controller addRepresenter:rep];
}

- (void)hideViewForRepresenter:(HFRepresenter *)rep {
    NSView *repView = [rep view];
    HFASSERT([repView superview] == containerView && [repView window] == [self window]);
    [controller removeRepresenter:rep];
    [repView removeFromSuperview];
    [self layoutViewsWithBytesPerLine:[controller bytesPerLine] contentHeight:NSHeight([containerView bounds])];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
    USE(windowController);
    [self showViewForRepresenter:hexRepresenter];
    [self showViewForRepresenter:asciiRepresenter];
    [self showViewForRepresenter:scrollRepresenter];
}

- init {
    [super init];
    debugRepresenter = [[HFTestRepresenter alloc] init];
    hexRepresenter = [[HFHexTextRepresenter alloc] init];
    asciiRepresenter = [[HFStringEncodingTextRepresenter alloc] init];
    scrollRepresenter = [[HFVerticalScrollerRepresenter alloc] init];
    
    controller = [[HFController alloc] init];
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
