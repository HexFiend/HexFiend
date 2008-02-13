//
//  MyDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "MyDocument.h"
#import "HFBannerDividerThumb.h"
#import "HFFindReplaceBackgroundView.h"
#import <HexFiend/HexFiend.h>
#include <pthread.h>

static BOOL isRunningOnLeopardOrLater(void) {
    return NSAppKitVersionNumber >= 860.;
}

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
    return [NSArray arrayWithObjects:lineCountingRepresenter, hexRepresenter, asciiRepresenter, scrollRepresenter, statusBarRepresenter, nil];
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
    
    [containerView setVertical:NO];
    if ([containerView respondsToSelector:@selector(setDividerStyle:)]) {
	[containerView setDividerStyle:2/*NSSplitViewDividerStyleThin*/];
    }
    [containerView setDelegate:self];
    
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
    [bannerView release];
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

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    USE(typeName);
    USE(outError);
    BOOL result = NO;
    HFASSERT([absoluteURL isFileURL]);
    HFFileReference *fileReference = [[[HFFileReference alloc] initWithPath:[absoluteURL path]] autorelease];
    if (fileReference) {
        HFFileByteSlice *byteSlice = [[[HFFileByteSlice alloc] initWithFile:fileReference] autorelease];
        HFTavlTreeByteArray *byteArray = [[[HFTavlTreeByteArray alloc] init] autorelease];
        [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
        [controller setByteArray:byteArray];
        result = YES;
    }
    return result;
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
    else if ([item action] == @selector(performFindPanelAction:)) {
        switch ([item tag]) {
            case NSFindPanelActionShowFindPanel:
            case NSFindPanelActionNext:
            case NSFindPanelActionPrevious:
                return YES;
            default:
                return NO;
        }
    }
    else return [super validateMenuItem:item];
}

- (void)finishedAnimation {
    if (! bannerGrowing) {
	bannerIsShown = NO;
	[bannerDividerThumb removeFromSuperview];
	[bannerView removeFromSuperview];
	[bannerView release];
	bannerView = nil;
        [containerView setNeedsDisplay:YES];
    }
}

- (void)restoreFirstResponderToSavedResponder {
    NSWindow *window = [self window];
    NSMutableArray *views = [NSMutableArray array];
    FOREACH(HFRepresenter *, rep, [self representers]) {
        NSView *view = [rep view];
        if ([view window] == window) {
            /* If we're the saved first responder, try it first */
            if (view == savedFirstResponder) [views insertObject:view atIndex:0];
            else [views addObject:view];
        }
    }
    
    /* Try each view we identified */
    FOREACH(NSView *, view, views) {
        if ([window makeFirstResponder:view]) return;
    }
    
    /* No luck - set it to the window */
    [window makeFirstResponder:window];
}

- (void)animateBanner:(NSTimer *)timer {
    BOOL isFirstCall = (bannerStartTime == 0);
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (isFirstCall) bannerStartTime = now;
    CFAbsoluteTime diff = now - bannerStartTime;
    double amount = diff / .15;
    amount = fmin(fmax(amount, 0), 1);
    if (! bannerGrowing) amount = 1. - amount;
    CGFloat height = (CGFloat)round(bannerTargetHeight * amount);
    NSRect bannerFrame = [bannerView frame];
    bannerFrame.size.height = height;
    [bannerView setFrame:bannerFrame];
    [containerView display];
    if (isFirstCall) {
        /* The first display can take some time, which can cause jerky animation; so we start the animation after it */
        bannerStartTime = CFAbsoluteTimeGetCurrent();
    }
    if ((bannerGrowing && amount >= 1.) || (!bannerGrowing && amount <= 0.)) {
        [timer invalidate];
	[self finishedAnimation];
    }
}

- (void)hideBannerFirstThenDo:(SEL)command {
    HFASSERT(bannerIsShown);
    bannerGrowing = NO;
    bannerStartTime = 0;
    /* If the first responder is in our banner, move it to our view */
    NSWindow *window = [self window];
    id firstResponder = [window firstResponder];
    if ([firstResponder isKindOfClass:[NSView class]] && [firstResponder ancestorSharedWithView:bannerView] == bannerView) {
        [self restoreFirstResponderToSavedResponder];
    }
    [NSTimer scheduledTimerWithTimeInterval:1. / 60. target:self selector:@selector(animateBanner:) userInfo:nil repeats:YES];
    bannerTargetHeight = NSHeight([bannerView frame]);
}

- (void)prepareBannerWithView:(NSView *)newSubview {
    if (! bannerView) bannerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];
    NSRect containerBounds = [containerView bounds];
    NSRect bannerFrame = NSMakeRect(NSMinX(containerBounds), NSMaxY(containerBounds), NSWidth(containerBounds), 0);
    [bannerView setFrame:bannerFrame];
    [containerView addSubview:bannerView positioned:NSWindowBelow relativeTo:[layoutRepresenter view]];
    bannerStartTime = 0;
    bannerIsShown = YES;
    bannerGrowing = YES;
    if (isRunningOnLeopardOrLater()) {
        if (! bannerDividerThumb) bannerDividerThumb = [[HFBannerDividerThumb alloc] initWithFrame:NSMakeRect(0, 0, 14, 14)];
        [bannerDividerThumb setAutoresizingMask:0];
        [bannerDividerThumb setFrameOrigin:NSMakePoint(3, 0)];
        [bannerDividerThumb removeFromSuperview];
        [bannerView addSubview:bannerDividerThumb];
    }
    if (newSubview) {
        if (bannerDividerThumb) [bannerView addSubview:newSubview positioned:NSWindowBelow relativeTo:bannerDividerThumb];
        else [bannerView addSubview:newSubview];
    }
    [NSTimer scheduledTimerWithTimeInterval:1. / 60. target:self selector:@selector(animateBanner:) userInfo:nil repeats:YES];
}

- (void)showFindPanel:(NSMenuItem *)item {
    USE(item);
    if (bannerIsShown) {
	[self hideBannerFirstThenDo:_cmd];
	return;
    }
    
    if (! findReplaceBackgroundView) {
        if (! [NSBundle loadNibNamed:@"FindReplace" owner:self] || ! findReplaceBackgroundView) {
            [NSException raise:NSInternalInconsistencyException format:@"Unable to load FindReplace.nib"];
        }
        [[findReplaceBackgroundView searchField] setTarget:self];
        [[findReplaceBackgroundView searchField] setAction:@selector(findNext:)];
        [[findReplaceBackgroundView replaceField] setTarget:self];
        [[findReplaceBackgroundView replaceField] setAction:@selector(findNext:)];
        [findReplaceBackgroundView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [findReplaceBackgroundView setFrameSize:NSMakeSize(NSWidth([containerView frame]), 0)];
        [findReplaceBackgroundView setFrameOrigin:NSZeroPoint];
    }

    bannerTargetHeight = [findReplaceBackgroundView defaultHeight];
    
    [self prepareBannerWithView:findReplaceBackgroundView];
    savedFirstResponder = [[self window] firstResponder];
    [[self window] makeFirstResponder:[findReplaceBackgroundView searchField]];
}

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex {
    USE(dividerIndex);
    HFASSERT(splitView == containerView);
    if (bannerDividerThumb) return [bannerDividerThumb convertRect:[bannerDividerThumb bounds] toView:containerView];
    else return NSZeroRect;
}

- (void)cancelOperation:sender {
    USE(sender);
    [self hideBannerFirstThenDo:NULL];
}

typedef struct {
    HFByteArray *needle;
    HFByteArray *haystack;
    HFRange range1;
    HFRange range2;
    HFProgressTracker *tracker;
    BOOL forwards;
    
    unsigned long long result;
} FindBuffer_t;


static void *threadedPerformFindFunction(void *vParam) {
    FindBuffer_t *findBufferPtr = vParam;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; //necessary so the collector knows about this thread
    
    unsigned long long searchResult;
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    searchResult = [findBufferPtr->haystack indexOfBytesEqualToBytes:findBufferPtr->needle inRange:findBufferPtr->range1 searchingForwards:findBufferPtr->forwards trackingProgress:findBufferPtr->tracker];
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    printf("Diff: %f\n", end - start);
    if (searchResult == ULLONG_MAX) {
        searchResult = [findBufferPtr->haystack indexOfBytesEqualToBytes:findBufferPtr->needle inRange:findBufferPtr->range2 searchingForwards:findBufferPtr->forwards trackingProgress:findBufferPtr->tracker];
    }
    findBufferPtr->result = searchResult;
    [findBufferPtr->tracker noteFinished:nil];
    [pool release];
    return findBufferPtr;
}

- (void)_findThreadFinished:(NSNotification *)note {
    NSLog(@"Finished %p", threadedOperation);
    USE(note);
    HFASSERT(threadedOperation != NULL);
    FindBuffer_t *findBufferPtr = NULL;
    unsigned long long searchResult;
    int joinResult;
    joinResult = pthread_join(threadedOperation, (void **)&findBufferPtr);
    threadedOperation = NULL;
    HFASSERT(joinResult == 0);
    HFASSERT(findBufferPtr != NULL);
    if (! findBufferPtr->tracker->cancelRequested) {
        searchResult = findBufferPtr->result;
        if (searchResult != ULLONG_MAX) {
            HFRange resultRange = HFRangeMake(searchResult, [findBufferPtr->needle length]);
            [controller setSelectedContentsRanges:[HFRangeWrapper withRanges:&resultRange count:1]];
            [controller maximizeVisibilityOfContentsRange:resultRange];
            [self restoreFirstResponderToSavedResponder];
        }
        else {
            NSBeep();
        }
    }
    HFASSERT([note object] == findBufferPtr->tracker);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFProgressTrackerDidFinishNotification object:findBufferPtr->tracker];
    [findBufferPtr->tracker endTrackingProgress];
    [findBufferPtr->needle decrementChangeLockCounter];
    [findBufferPtr->haystack decrementChangeLockCounter];
    [findBufferPtr->needle release];
    [findBufferPtr->haystack release];
    [findBufferPtr->tracker release];
    free(findBufferPtr);
}

- (unsigned long long)_findBytes:(HFByteArray *)needle inBytes:(HFByteArray *)haystack range1:(HFRange)range1 range2:(HFRange)range2 forwards:(BOOL)forwards tracker:(HFProgressTracker *)tracker {
    NSLog(@"%s %p", _cmd, threadedOperation);
    HFASSERT(threadedOperation == NULL);
    const FindBuffer_t findBuffer = {.needle = [needle retain], .haystack = [haystack retain], .range1 = range1, .range2 = range2, .forwards = forwards, .tracker = [tracker retain]};
    int threadResult;
    
    FindBuffer_t *findBufferPtr = malloc(sizeof *findBufferPtr);
    if (! findBufferPtr) [NSException raise:NSMallocException format:@"Unable to malloc %lu bytes", (unsigned long)sizeof *findBufferPtr];
    *findBufferPtr = findBuffer;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_findThreadFinished:) name:HFProgressTrackerDidFinishNotification object:tracker];
    [tracker beginTrackingProgress];
    [findBufferPtr->needle incrementChangeLockCounter];
    [findBufferPtr->haystack incrementChangeLockCounter];
    
    threadResult = pthread_create(&threadedOperation, NULL, threadedPerformFindFunction, findBufferPtr);
    if (threadResult != 0) [NSException raise:NSGenericException format:@"pthread_create returned error %d", threadResult];
    NSLog(@"Made operation %p", threadedOperation);
    
    return 0;
}

- (void)findNextBySearchingForwards:(BOOL)forwards {
    HFByteArray *needle = [[findReplaceBackgroundView searchField] objectValue];
    if ([needle length] > 0) {
        HFByteArray *haystack = [controller byteArray];
        unsigned long long haystackLength = [haystack length];
        HFProgressTracker *tracker = [[HFProgressTracker alloc] init];
        [tracker setMaxProgress:haystackLength];
        [tracker setProgressIndicator:[findReplaceBackgroundView progressIndicator]];
        /* We start looking at the max selection, and if we don't find anything, wrap around up to the min selection.  Counterintuitively, endLocation is less than startLocation. */
        unsigned long long startLocation = [controller maximumSelectionLocation];
        unsigned long long endLocation = [controller minimumSelectionLocation];
        HFASSERT(startLocation <= haystackLength);
        HFRange searchRange1 = HFRangeMake(startLocation, haystackLength - startLocation);
        HFRange searchRange2 = HFRangeMake(0, endLocation);
        [self _findBytes:needle inBytes:haystack range1:searchRange1 range2:searchRange2 forwards:forwards tracker:tracker];
        [tracker release];
    }
}

- (void)findNext:sender {
    USE(sender);
    [self findNextBySearchingForwards:YES];
}

- (void)findPrevious:sender {
    USE(sender);
    [self findNextBySearchingForwards:NO];
}

- (void)performFindPanelAction:(NSMenuItem *)item {
    switch ([item tag]) {
        case NSFindPanelActionShowFindPanel:
            [self showFindPanel:item];
            break;
        case NSFindPanelActionNext:
            [self findNext:item];
            break;
        case NSFindPanelActionPrevious:
            [self findPrevious:item];
            break;
        default:
            NSLog(@"Unhandled item %@", item);
            break;
    }
}


@end
