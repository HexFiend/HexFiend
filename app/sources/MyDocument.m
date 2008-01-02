//
//  MyDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MyDocument.h"
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
    return [NSArray arrayWithObjects:lineCountingRepresenter, hexRepresenter, asciiRepresenter, scrollRepresenter, nil];
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

- (void)showViewForRepresenter:(HFRepresenter *)rep {
    NSView *repView = [rep view];
    HFASSERT([repView superview] == nil && [repView window] == nil);
    [layoutRepresenter addRepresenter:rep];
    [controller addRepresenter:rep];
}

- (void)hideViewForRepresenter:(HFRepresenter *)rep {
    HFASSERT(rep != NULL);
    HFASSERT([[layoutRepresenter representers] indexOfObjectIdenticalTo:rep] != NSNotFound);
    [controller removeRepresenter:rep];
    [layoutRepresenter removeRepresenter:rep];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
    USE(windowController);
    
    NSView *layoutView = [layoutRepresenter view];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [layoutView setFrame:[containerView bounds]];
    [containerView addSubview:layoutView];
    
    [self showViewForRepresenter:hexRepresenter];
    [self showViewForRepresenter:asciiRepresenter];
    [self showViewForRepresenter:scrollRepresenter];
    [self showViewForRepresenter:lineCountingRepresenter];
    [self showViewForRepresenter:statusBarRepresenter];
}

/* When our line counting view needs more space, we increase the size of our window, and also move it left by the same amount so that the other content does not appear to move. */
- (void)lineCountingViewChangedWidth:(NSNotification *)note {
    HFASSERT([note object] == lineCountingRepresenter);
    NSView *lineCountingView = [lineCountingRepresenter view];
    
    /* Don't do anything window changing if we're not in a window yet */
    NSWindow *lineCountingViewWindow = [lineCountingView window];
    if (! lineCountingViewWindow) return;
    
    HFASSERT(lineCountingViewWindow == [self window]);
    
    CGFloat currentWidth = NSWidth([lineCountingView frame]);
    CGFloat newWidth = [lineCountingRepresenter preferredWidth];
    if (newWidth != currentWidth) {
        CGFloat widthChange = newWidth - currentWidth; //if we shrink, widthChange will be negative
        CGFloat windowWidthChange = [[lineCountingView superview] convertSize:NSMakeSize(widthChange, 0) toView:nil].width;
        windowWidthChange = (windowWidthChange < 0 ? HFFloor(windowWidthChange) : HFCeil(windowWidthChange));
        
        /* convertSize: has a nasty habit of stomping on negatives.  Make our window width negative if our view-space horizontal change was negative. */
#if __LP64__
        windowWidthChange = copysign(windowWidthChange, widthChange);
#else
        windowWidthChange = copysignf(windowWidthChange, widthChange);
#endif
        
        NSRect windowFrame = [lineCountingViewWindow frame];
        windowFrame.size.width += windowWidthChange;
        windowFrame.origin.x -= windowWidthChange;
        [lineCountingViewWindow setFrame:windowFrame display:YES animate:NO];
    }
}

- init {
    [super init];
    lineCountingRepresenter = [[HFLineCountingRepresenter alloc] init];
    hexRepresenter = [[HFHexTextRepresenter alloc] init];
    asciiRepresenter = [[HFStringEncodingTextRepresenter alloc] init];
    scrollRepresenter = [[HFVerticalScrollerRepresenter alloc] init];
    layoutRepresenter = [[HFLayoutRepresenter alloc] init];
    statusBarRepresenter = [[HFStatusBarRepresenter alloc] init];
    
    [[hexRepresenter view] setAutoresizingMask:NSViewHeightSizable];
    [[asciiRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(lineCountingViewChangedWidth:) name:HFLineCountingRepresenterMinimumViewWidthChanged object:lineCountingRepresenter];
    
    controller = [[HFController alloc] init];
    [controller setUndoManager:[self undoManager]];
    [controller addRepresenter:layoutRepresenter];
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self representers] makeObjectsPerformSelector:@selector(release)];
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
            [item setState:[[controller representers] containsObject:rep]];
            return YES;
        }
    }
    else return [super validateMenuItem:item];
}

@end
