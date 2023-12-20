//
//  FiendlingAppDelegate.m
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "FiendlingAppDelegate.h"
@import HexFiend;

@interface FiendlingExample : NSObject {
    NSString *label;
    NSString *explanation;
}

@property(readonly) NSString *label;
@property(readonly) NSString *explanation;

+ (instancetype)exampleWithLabel:(NSString *)someLabel explanation:(NSString *)someExplanation;

@end

@interface FiendlingAppDelegate ()

@property NSArray<FiendlingExample *> *examples;

@end

@implementation FiendlingAppDelegate {
    /* The tab view in our nib */
    IBOutlet NSTabView *tabView;

    /**** FIRST TAB ****/
    /* Data bound to by both the NSTextView and HFTextView */
    IBOutlet HFTextView *boundDataTextView;

    NSData *textViewBoundData;

    /**** SECOND TAB ****/
    HFController *inMemoryController;
    HFController *fileController;

    /**** THIRD TAB ****/
    HFController *externalDataController;
    IBOutlet NSTextView *externalDataTextView;
    NSData *externalData;

    /* Explanatory texts */
    IBOutlet NSTextField *explanatoryTextField;
}

- (NSData *)rtfSampleData {
    NSURL *url = [NSBundle.mainBundle URLForResource:@"sampleData.rtf" withExtension:nil];
    return [NSData dataWithContentsOfURL:url options:0 error:nil];
}

- (void)setUpBoundDataHexView {
    /* Bind our text view to our bound data */
    [boundDataTextView bind:@"data" toObject:self withKeyPath:@"textViewBoundData" options:nil];
    [self setValue:[self rtfSampleData] forKey:@"textViewBoundData"];
}

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
    HFSharedMemoryByteSlice *byteSlice = [[HFSharedMemoryByteSlice alloc] initWithData:data];
    HFByteArray *byteArray = [[HFBTreeByteArray alloc] init];
    [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
    [inMemoryController setByteArray:byteArray];
    
    /* Make an HFHexTextRepresenter. */
    HFHexTextRepresenter *hexRep = [[HFHexTextRepresenter alloc] init];
    [hexRep setRowBackgroundColors:[NSArray array]]; //An empty array means don't draw a background.
    [inMemoryController addRepresenter:hexRep];
    
    /* Grab its view and stick it into our container. */
    NSView *hexView = [hexRep view];
    [hexView setFrame:[containerView bounds]];
    [hexView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [containerView addSubview:hexView];
}

- (void)setUpFileMultipleViewIntoView:(NSView *)containerView {
    /* We're going to show the contents of our Info.plist */
    NSString *infoplist = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Info.plist"];
    HFFileReference *reference = [[HFFileReference alloc] initWithPath:infoplist error:NULL];
    
    /* Make a controller to hook everything up, and then configure it a bit. */
    fileController = [[HFController alloc] init];
    [fileController setBytesPerColumn:1];
    
    /* Put our data in a byte slice. */
    HFFileByteSlice *byteSlice = [[HFFileByteSlice alloc] initWithFile:reference];
    HFByteArray *byteArray = [[HFBTreeByteArray alloc] init];
    [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
    [fileController setByteArray:byteArray];
    
    /* Here we're going to make three representers - one for the hex, one for the ASCII, and one for the scrollbar.  To lay these all out properly, we'll use a fourth HFLayoutRepresenter. */
    HFLayoutRepresenter *layoutRep = [[HFLayoutRepresenter alloc] init];
    HFHexTextRepresenter *hexRep = [[HFHexTextRepresenter alloc] init];
    HFStringEncodingTextRepresenter *asciiRep = [[HFStringEncodingTextRepresenter alloc] init];
    HFVerticalScrollerRepresenter *scrollRep = [[HFVerticalScrollerRepresenter alloc] init];
    
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
    
    HFByteArray *byteArray = [[HFBTreeByteArray alloc] init];
    [externalDataController setByteArray:byteArray];
    [externalDataController setEditable:NO];
    
    /* Here we're going to make three representers - one for the hex, one for the ASCII, and one for the scrollbar.  To lay these all out properly, we'll use a fourth HFLayoutRepresenter. */
    HFLayoutRepresenter *layoutRep = [[HFLayoutRepresenter alloc] init];
    HFHexTextRepresenter *hexRep = [[HFHexTextRepresenter alloc] init];
    HFStringEncodingTextRepresenter *asciiRep = [[HFStringEncodingTextRepresenter alloc] init];
    HFVerticalScrollerRepresenter *scrollRep = [[HFVerticalScrollerRepresenter alloc] init];
    
    /* Add all our reps to the controller. */
    [externalDataController addRepresenter:layoutRep];
    [externalDataController addRepresenter:hexRep];
    [externalDataController addRepresenter:asciiRep];
    [externalDataController addRepresenter:scrollRep];
    
    /* Tell the layout rep which reps it should lay out. */    
    [layoutRep addRepresenter:hexRep];
    [layoutRep addRepresenter:scrollRep];
    [layoutRep addRepresenter:asciiRep];
    
    [(NSView *)[hexRep view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    /* Grab the layout rep's view and stick it into our container. */
    NSView *layoutView = [layoutRep view];
    NSRect scrollViewFrame = [[externalDataTextView enclosingScrollView] frame];
    NSRect layoutViewFrame = scrollViewFrame;
    layoutViewFrame.origin.y = NSMinY([containerView bounds]);
    layoutViewFrame.size.height = NSMinY(scrollViewFrame) - layoutViewFrame.origin.y - 3;
    [layoutView setFrame:layoutViewFrame];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable | NSViewMaxYMargin];
    [containerView addSubview:layoutView];
    
    /* Set some sample data */
    [self setValue:[self rtfSampleData] forKey:@"externalData"];
}

- (void)setExternalData:(NSData *)data {
    externalData = [data copy];
    HFByteArray *newByteArray = [[HFBTreeByteArray alloc] init];
    if (externalData) {
        HFFullMemoryByteSlice *byteSlice = [[HFFullMemoryByteSlice alloc] initWithData:externalData];
        [newByteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
    }
    [externalDataController replaceByteArray:newByteArray];
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
    textViewBoundData = data;
}

- (void)applicationDidFinishLaunching:(__attribute__((unused)) NSNotification *)note {
    self.examples = @[
        [FiendlingExample exampleWithLabel:@"Bound HFTextView" explanation:@"This example demonstrates showing and editing data via the \"data\" binding on both NSTextView and HFTextView."],
        [FiendlingExample exampleWithLabel:@"In-Memory Data" explanation:@"This example demonstrates showing in-memory data in a hex view."],
        [FiendlingExample exampleWithLabel:@"File Data, Multiple Views" explanation:@"This example demonstrates showing file data in three coherent views (a hex view, an ASCII view, and a scroll bar)."],
        [FiendlingExample exampleWithLabel:@"External Data" explanation:@"This example demonstrates showing data from an external source."],
    ];
    [self setUpBoundDataHexView];
    [self setUpInMemoryHexViewIntoView:[self viewForIdentifier:@"in_memory_hex_view"]];
    [self setUpFileMultipleViewIntoView:[self viewForIdentifier:@"file_data_multiple_views"]];
    [self setUpExternalDataView:[self viewForIdentifier:@"external_data"]];
}

@end

@implementation FiendlingExample

@synthesize label = label, explanation = explanation;

+ (instancetype)exampleWithLabel:(NSString *)someLabel explanation:(NSString *)someExplanation {
    FiendlingExample *example = [[self  alloc] init];
    example->label = [someLabel copy];
    example->explanation = [someExplanation copy];
    return example;
}

@end
