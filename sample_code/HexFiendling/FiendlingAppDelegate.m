//
//  FiendlingAppDelegate.m
//  HexFiend_2
//
//  Created by Peter Ammon on 6/27/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "FiendlingAppDelegate.h"


@implementation FiendlingAppDelegate

- (void)setUpInMemoryHexViewIntoView:(NSView *)containerView {
    /* Get some random data to display */
    const unsigned int dataSize = 1024;
    NSMutableData *data = [NSMutableData dataWithLength:dataSize];
    int fd = open("/dev/random", O_RDONLY);
    read(fd, [data mutableBytes], dataSize);
    close(fd);

    /* Make a controller to hook everything up, and then configure it a bit. */
    inMemoryController = [[HFController alloc] init];
    [inMemoryController setBytesPerColumn:4];

    /* Put that data in a byte slice.  Here we use initWithData:, which causes the byte slice to take ownership of the data (and may modify it).  If we want to prevent our data from being modified, we would use initWithUnsharedData: */
    HFSharedMemoryByteSlice *byteSlice = [[[HFSharedMemoryByteSlice alloc] initWithData:data] autorelease];
    HFByteArray *byteArray = [[[HFBTreeByteArray alloc] init] autorelease];
    [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
    [inMemoryController setByteArray:byteArray];
    
    /* Make an HFHexTextRepresenter. */
    HFHexTextRepresenter *hexRep = [[[HFHexTextRepresenter alloc] init] autorelease];
    [hexRep setRowBackgroundColors:[NSArray array]]; //An empty array means don't draw a background.
    [inMemoryController addRepresenter:hexRep];
    
    /* Grab its view and stick it into our container. */
    NSView *hexView = [hexRep view];
    [hexView setFrame:[containerView bounds]];
    [hexView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [containerView addSubview:hexView];
}

- (void)setUpFileMultipleViewIntoView:(NSView *)containerView {
    /* We're going to show the contents of mach_kernel */
    HFFileReference *reference = [[[HFFileReference alloc] initWithPath:@"/mach_kernel" error:NULL] autorelease];

    /* Make a controller to hook everything up, and then configure it a bit. */
    fileController = [[HFController alloc] init];
    [fileController setBytesPerColumn:1];
    
    /* Put our data in a byte slice. */
    HFFileByteSlice *byteSlice = [[[HFFileByteSlice alloc] initWithFile:reference] autorelease];
    HFByteArray *byteArray = [[[HFBTreeByteArray alloc] init] autorelease];
    [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
    [fileController setByteArray:byteArray];

    /* Here we're going to make three representers - one for the hex, one for the ASCII, and one for the scrollbar.  To lay these all out properly, we'll use a fourth HFLayoutRepresenter. */
    HFLayoutRepresenter *layoutRep = [[[HFLayoutRepresenter alloc] init] autorelease];
    HFHexTextRepresenter *hexRep = [[[HFHexTextRepresenter alloc] init] autorelease];
    HFStringEncodingTextRepresenter *asciiRep = [[[HFStringEncodingTextRepresenter alloc] init] autorelease];
    HFVerticalScrollerRepresenter *scrollRep = [[[HFVerticalScrollerRepresenter alloc] init] autorelease];
    
    /* Add all our reps to the controller. */
    [fileController addRepresenter:layoutRep];
    [fileController addRepresenter:hexRep];
    [fileController addRepresenter:asciiRep];
    [fileController addRepresenter:scrollRep];

    /* Tell the layout rep which reps it should lay out. */    
    [layoutRep addRepresenter:hexRep];
    [layoutRep addRepresenter:asciiRep];
    [layoutRep addRepresenter:scrollRep];
    
    /* Grab the layout rep's view and stick it into our container. */
    NSView *layoutView = [layoutRep view];
    [layoutView setFrame:[containerView bounds]];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [containerView addSubview:layoutView];
}

- (void)setUpExternalDataView:(NSView *)containerView {
    externalDataController = [[HFController alloc] init];
    [externalDataController setBytesPerColumn:1];
    
    HFByteArray *byteArray = [[[HFBTreeByteArray alloc] init] autorelease];
    [externalDataController setByteArray:byteArray];
    [externalDataController setEditable:NO];

    /* Here we're going to make three representers - one for the hex, one for the ASCII, and one for the scrollbar.  To lay these all out properly, we'll use a fourth HFLayoutRepresenter. */
    HFLayoutRepresenter *layoutRep = [[[HFLayoutRepresenter alloc] init] autorelease];
    HFHexTextRepresenter *hexRep = [[[HFHexTextRepresenter alloc] init] autorelease];
    HFHexTextRepresenter *asciiRep = [[[HFStringEncodingTextRepresenter alloc] init] autorelease];
    HFVerticalScrollerRepresenter *scrollRep = [[[HFVerticalScrollerRepresenter alloc] init] autorelease];
    
    /* Add all our reps to the controller. */
    [externalDataController addRepresenter:layoutRep];
    [externalDataController addRepresenter:hexRep];
    [externalDataController addRepresenter:asciiRep];
    [externalDataController addRepresenter:scrollRep];

    /* Tell the layout rep which reps it should lay out. */    
    [layoutRep addRepresenter:hexRep];
    [layoutRep addRepresenter:scrollRep];
    [layoutRep addRepresenter:asciiRep];
    
    [[hexRep view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];

    /* Grab the layout rep's view and stick it into our container. */
    NSView *layoutView = [layoutRep view];
    NSRect scrollViewFrame = [[externalDataTextView enclosingScrollView] frame];
    NSRect layoutViewFrame = scrollViewFrame;
    layoutViewFrame.origin.y = NSMinY([containerView bounds]);
    layoutViewFrame.size.height = NSMinY(scrollViewFrame) - layoutViewFrame.origin.y - 3;
    [layoutView setFrame:layoutViewFrame];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable | NSViewMaxYMargin];
    [containerView addSubview:layoutView];
}

- (void)setExternalData:(NSData *)data {
    NSData *oldData = externalData;
    externalData = [data copy];
    [oldData release];
    HFByteArray *newByteArray = [[HFBTreeByteArray alloc] init];
    if (externalData) {
        HFFullMemoryByteSlice *byteSlice = [[HFFullMemoryByteSlice alloc] initWithData:externalData];
        [newByteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [byteSlice release];
    }
    [externalDataController replaceByteArray:newByteArray];
    [newByteArray release];
}


- (NSView *)viewForIdentifier:(NSString *)ident {
    NSView *result = nil;
    NSInteger index = [tabView indexOfTabViewItemWithIdentifier:ident];
    if (index != NSNotFound) {
        result = [[tabView tabViewItemAtIndex:index] view];
    }
    return result;
}


- (void)setTextViewBoundData:(NSData *)data {
    [data retain];
    [textViewBoundData release];
    textViewBoundData = data;
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    NSMutableArray *texts = [[NSMutableArray alloc] init];
    explanatoryTexts = texts;
    
    [texts addObject:@"This tab demonstrates showing and editing data via the \"data\" binding on both NSTextView and HFTextView."];
    //nothing to set up programmatically!
    
    [texts addObject:@"This tab demonstrates showing in-memory data in a hex view."];
    [self setUpInMemoryHexViewIntoView:[self viewForIdentifier:@"in_memory_hex_view"]];
    
    [texts addObject:@"This tab demonstrates showing file data in three coherent views (a hex view, an ASCII view, and a scroll bar)."];
    [self setUpFileMultipleViewIntoView:[self viewForIdentifier:@"file_data_multiple_views"]];

    [texts addObject:@"This tab demonstrates showing data from an external source."];
    [self setUpExternalDataView:[self viewForIdentifier:@"external_data"]];
    
    [explanatoryTextField setStringValue:[explanatoryTexts objectAtIndex:[tabView indexOfTabViewItem:[tabView selectedTabViewItem]]]];
}

- (void)tabView:(NSTabView *)tv didSelectTabViewItem:(NSTabViewItem *)tabViewItem {
    NSInteger index = [tabView indexOfTabViewItem:tabViewItem];
    [explanatoryTextField setStringValue:[explanatoryTexts objectAtIndex:index]];
}

@end
