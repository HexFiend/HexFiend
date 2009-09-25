//
//  MyDocument.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "MyDocument.h"
#import "HFBannerDividerThumb.h"
#import "HFDocumentOperationView.h"
#import "DataInspectorRepresenter.h"
#import <HexFiend/HexFiend.h>
#include <pthread.h>

static const char *const kProgressContext = "context";

enum {
    HFSaveSuccessful,
    HFSaveCancelled,
    HFSaveError
};


static BOOL isRunningOnLeopardOrLater(void) {
    return NSAppKitVersionNumber >= 860.;
}

static inline Class preferredByteArrayClass(void) {
    return [HFBTreeByteArray class];
}

@interface MyDocument (ForwardDeclarations)
- (NSString *)documentWindowTitleFormatString;
@end

/* Subclass to display custom window title that shows progress */
@interface MyDocumentWindowController : NSWindowController

@end

@implementation MyDocumentWindowController

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName {
    NSString *result;
    NSString *superDisplayName = [super windowTitleForDocumentDisplayName:displayName];
    
    /* Apply a format string */
    NSString *formatString = [[self document] documentWindowTitleFormatString];
    result = [NSString stringWithFormat:formatString, superDisplayName];
    
    return result;
}

@end

#define USERDEFS_KEY_FOR_REP(r) @"RepresenterIsShown " @#r

@implementation MyDocument

+ (void)initialize {
    if (self == [MyDocument class]) {
        NSNumber *yes = [NSNumber numberWithBool:YES];
        NSDictionary *defs = [[NSDictionary alloc] initWithObjectsAndKeys:
                              yes, @"AntialiasText",
                              @"Monaco", @"DefaultFontName",
                              [NSNumber numberWithDouble:10.], @"DefaultFontSize",
                              [NSNumber numberWithInt:4], @"BytesPerColumn",
                              yes, USERDEFS_KEY_FOR_REP(lineCountingRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(hexRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(asciiRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(dataInspectorRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(statusBarRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(scrollRepresenter),
                              nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
        [defs release];
	
	// Get notified when we are about to save a document, so we can try to break dependencies on the file in other documents
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prepareForChangeInFileByBreakingFileDependencies:) name:HFPrepareForChangeInFileNotification object:nil];
    }
}

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
    return [NSArray arrayWithObjects:lineCountingRepresenter, hexRepresenter, asciiRepresenter, scrollRepresenter, dataInspectorRepresenter, statusBarRepresenter, nil];
}

- (BOOL)representerIsShown:(HFRepresenter *)representer {
    NSParameterAssert(representer);
    return [[layoutRepresenter representers] containsObject:representer];
}

- (void)showViewForRepresenter:(HFRepresenter *)rep {
    NSView *repView = [rep view];
    HFASSERT([repView superview] == nil && [repView window] == nil);
    [controller addRepresenter:rep];
    [layoutRepresenter addRepresenter:rep];
}

- (void)hideViewForRepresenter:(HFRepresenter *)rep {
    HFASSERT(rep != NULL);
    HFASSERT([[layoutRepresenter representers] indexOfObjectIdenticalTo:rep] != NSNotFound);
    [controller removeRepresenter:rep];
    [layoutRepresenter removeRepresenter:rep];
}

/* Code to save to user defs (NO) or apply from user defs (YES) the default representers to show. */
- (void)saveOrApplyDefaultRepresentersToDisplay:(BOOL)isApplying {
    const struct {
        NSString *name;
        HFRepresenter *rep;
    } shownRepresentersData[] = {
        {USERDEFS_KEY_FOR_REP(lineCountingRepresenter), lineCountingRepresenter},
        {USERDEFS_KEY_FOR_REP(hexRepresenter), hexRepresenter},
        {USERDEFS_KEY_FOR_REP(asciiRepresenter), asciiRepresenter},
        {USERDEFS_KEY_FOR_REP(dataInspectorRepresenter), dataInspectorRepresenter},
        {USERDEFS_KEY_FOR_REP(statusBarRepresenter), statusBarRepresenter},
        {USERDEFS_KEY_FOR_REP(scrollRepresenter), scrollRepresenter}
    };
    NSUInteger i;
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    for (i=0; i < sizeof shownRepresentersData / sizeof *shownRepresentersData; i++) {
        if (isApplying) {
            /* Read from user defaults */
            NSNumber *boolObject = [defs objectForKey:shownRepresentersData[i].name];
            if (boolObject != nil) {
                BOOL shouldShow = [boolObject boolValue];
                HFRepresenter *rep = shownRepresentersData[i].rep;
                if (shouldShow != [self representerIsShown:rep]) {
                    if (shouldShow) [self showViewForRepresenter:rep];
                    else [self hideViewForRepresenter:rep];
                }
            }
        }
        else {
            /* Save to user defaults */
            BOOL isShown = [self representerIsShown:shownRepresentersData[i].rep];
            [defs setBool:isShown forKey:shownRepresentersData[i].name];
        }
    }
}

- (void)saveDefaultRepresentersToDisplay {    
    [self saveOrApplyDefaultRepresentersToDisplay:NO];
}

- (void)applyDefaultRepresentersToDisplay {
    [self saveOrApplyDefaultRepresentersToDisplay:YES];
}

/* Return a format string that can take one argument which is the document name. */
- (NSString *)documentWindowTitleFormatString {
    NSMutableString *result = [NSMutableString stringWithString:@"%@"]; //format specifier that is replaced with document name
    
    if ([controller inOverwriteMode]) {
        [result appendString:@" **OVERWRITE MODE**"];
    }
    
    HFDocumentOperationView * const views[] = {findReplaceView, moveSelectionByView, saveView};
    NSUInteger i;
    BOOL hasAppendedProgressMarker = NO;
    for (i=0; i < sizeof views / sizeof *views; i++) {
        HFDocumentOperationView *view = views[i];
        if (view != nil && view != operationView && [view operationIsRunning]) {
            /* If we're gonna show our save view after a delay, then don't include the save view in the title */
            if (view == saveView && showSaveViewAfterDelayTimer != nil) continue;
            NSString *displayName = [view displayName];
            double progress = [view progress];
            if (displayName != nil && progress != -1) {
                if (! hasAppendedProgressMarker) {
                    [result appendString:@" ("];
                    hasAppendedProgressMarker = YES;
                }
                else {
                    [result appendString:@", "];
                }
                if (displayName) {
                    /* %%%% is the right way to get a single % after applying this appendFormat: and then applying this return value as a format string as well */
                    [result appendFormat:@"%@: %d%%%%", displayName, (int)(100. * progress)];
                }
            }
        }
    }
    if (hasAppendedProgressMarker) [result appendString:@")"];
    return result;
}

- (void)updateDocumentWindowTitle {
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeWindowTitleWithDocumentName)];    
}

- (void)makeWindowControllers {
    NSString *windowNibName = [self windowNibName];
    if (windowNibName != nil) {
        NSWindowController *windowController = [[MyDocumentWindowController alloc] initWithWindowNibName:windowNibName owner:self];
        [self addWindowController:windowController];
        [windowController release];
    }
}

- (NSSize)minimumWindowFrameSizeForProposedSize:(NSSize)frameSize {
    NSView *layoutView = [layoutRepresenter view];
    NSSize proposedSizeInLayoutCoordinates = [layoutView convertSize:frameSize fromView:nil];
    CGFloat resultingWidthInLayoutCoordinates = [layoutRepresenter minimumViewWidthForLayoutInProposedWidth:proposedSizeInLayoutCoordinates.width];
    NSSize resultSize = [layoutView convertSize:NSMakeSize(resultingWidthInLayoutCoordinates, proposedSizeInLayoutCoordinates.height) toView:nil];
    return resultSize;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
    if (sender != [self window] || layoutRepresenter == nil) return frameSize;
    return [self minimumWindowFrameSizeForProposedSize:frameSize];
}

/* Relayout the window without increasing its window frame size */
- (void)relayoutAndResizeWindowPreservingFrame {
    NSWindow *window = [self window];
    NSRect windowFrame = [window frame];
    windowFrame.size = [self minimumWindowFrameSizeForProposedSize:windowFrame.size];
    [window setFrame:windowFrame display:YES];
}

/* Relayout the window to support the given number of bytes per line */
- (void)relayoutAndResizeWindowForBytesPerLine:(NSUInteger)bytesPerLine {
    NSWindow *window = [self window];
    NSRect windowFrame = [window frame];
    NSView *layoutView = [layoutRepresenter view];
    CGFloat minViewWidth = [layoutRepresenter minimumViewWidthForBytesPerLine:bytesPerLine];
    CGFloat minWindowWidth = [layoutView convertSize:NSMakeSize(minViewWidth, 1) toView:nil].width;
    windowFrame.size.width = minWindowWidth;
    [window setFrame:windowFrame display:YES];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
    USE(windowController);
    
    NSWindow *window = [windowController window];
    [containerView setVertical:NO];
    if ([containerView respondsToSelector:@selector(setDividerStyle:)]) {
        [containerView setDividerStyle:2/*NSSplitViewDividerStyleThin*/];
    }
    [containerView setDelegate:(id)self];
    
    NSView *layoutView = [layoutRepresenter view];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [layoutView setFrame:[containerView bounds]];
    [containerView addSubview:layoutView];
    [self applyDefaultRepresentersToDisplay];
    NSRect windowFrame = [window frame];
    windowFrame.size = [self minimumWindowFrameSizeForProposedSize:windowFrame.size];
    [window setFrame:windowFrame display:NO];
}

/* When our line counting view needs more space, we increase the size of our window, and also move it left by the same amount so that the other content does not appear to move. */
- (void)lineCountingViewChangedWidth:(NSNotification *)note {
    USE(note);
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
        
        /* convertSize: has a nasty habit of stomping on negatives.  Make our window width change negative if our view-space horizontal change was negative. */
#if __LP64__
        windowWidthChange = copysign(windowWidthChange, widthChange);
#else
        windowWidthChange = copysignf(windowWidthChange, widthChange);
#endif
        
        NSRect windowFrame = [lineCountingViewWindow frame];
        windowFrame.size.width += windowWidthChange;
	
	/* If we are not setting the font, we want to grow the window left, so that the content area is preserved.  If we are setting the font, grow the window right. */
	if (! currentlySettingFont) windowFrame.origin.x -= windowWidthChange;
        [lineCountingViewWindow setFrame:windowFrame display:YES animate:NO];
    }
}

- (void)dataInspectorDeletedAllRows:(NSNotification *)note {
    DataInspectorRepresenter *inspector = [note object];
    [self hideViewForRepresenter:inspector];
    [self saveDefaultRepresentersToDisplay]; // Save the representers in UserDefaults so we start out next time the same way
}

/* Called when our data inspector changes its size (number of rows) */
- (void)dataInspectorChangedRowCount:(NSNotification *)note {
    DataInspectorRepresenter *inspector = [note object];
    CGFloat newHeight = (CGFloat)[[[note userInfo] objectForKey:@"height"] doubleValue];
    NSView *dataInspectorView = [inspector view];
    NSSize size = [dataInspectorView frame].size;
    size.height = newHeight;
    [dataInspectorView setFrameSize:size];
    [layoutRepresenter performLayout];
}

- init {
    [super init];
    lineCountingRepresenter = [[HFLineCountingRepresenter alloc] init];
    hexRepresenter = [[HFHexTextRepresenter alloc] init];
    asciiRepresenter = [[HFStringEncodingTextRepresenter alloc] init];
    scrollRepresenter = [[HFVerticalScrollerRepresenter alloc] init];
    layoutRepresenter = [[HFLayoutRepresenter alloc] init];
    statusBarRepresenter = [[HFStatusBarRepresenter alloc] init];
    dataInspectorRepresenter = [[DataInspectorRepresenter alloc] init];
    
    [[hexRepresenter view] setAutoresizingMask:NSViewHeightSizable];
    [[asciiRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(lineCountingViewChangedWidth:) name:HFLineCountingRepresenterMinimumViewWidthChanged object:lineCountingRepresenter];
    [center addObserver:self selector:@selector(dataInspectorChangedRowCount:) name:DataInspectorDidChangeRowCount object:dataInspectorRepresenter];
    [center addObserver:self selector:@selector(dataInspectorDeletedAllRows:) name:DataInspectorDidDeleteAllRows object:dataInspectorRepresenter];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    controller = [[HFController alloc] init];
    [controller setShouldAntialias:[defs boolForKey:@"AntialiasText"]];
    [controller setUndoManager:[self undoManager]];
    [controller setBytesPerColumn:[defs integerForKey:@"BytesPerColumn"]];
    [controller addRepresenter:layoutRepresenter];
    
    NSString *fontName = [defs stringForKey:@"DefaultFontName"];
    CGFloat fontSize = [defs floatForKey:@"DefaultFontSize"];
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];
    if (font != nil) {
        [controller setFont: font];
    }
    
#if ! NDEBUG
    static BOOL hasAddedMenu = NO;
    if (! hasAddedMenu) {
        hasAddedMenu = YES;
        NSMenu *menu = [[[NSApp mainMenu] itemWithTitle:@"Debug"] submenu];
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Show ByteArray" action:@selector(_showByteArray:) keyEquivalent:@"k"];
        [[[menu itemArray] lastObject] setKeyEquivalentModifierMask:NSCommandKeyMask];
    }
#endif
    return self;
}

#if ! NDEBUG
- (void)_showByteArray:sender {
    USE(sender);
    NSLog(@"%@", [controller byteArray]);
}
#endif

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[self representers] makeObjectsPerformSelector:@selector(release)];
    [controller release];
    [bannerView release];
    [saveError release];
    
    /* Release and stop observing our banner views.  Note that any of these may be nil. */
    HFDocumentOperationView *views[] = {findReplaceView, moveSelectionByView, jumpToOffsetView, saveView};
    for (NSUInteger i = 0; i < sizeof views / sizeof *views; i++) {
	[views[i] removeObserver:self forKeyPath:@"progress"];
	[views[i] release];
    }
    [bannerDividerThumb release];
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == kProgressContext) {
        /* One of our HFDocumentOperationViews changed progress.  Update our title bar to reflect that.  But we don't show progress for the currently displayed banner. */
        if (object != operationView) {
            [self updateDocumentWindowTitle];
        }
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}


- (HFDocumentOperationView *)newOperationViewForNibName:(NSString *)name displayName:(NSString *)displayName {
    HFASSERT(name);
    HFDocumentOperationView *result = [[HFDocumentOperationView viewWithNibNamed:name owner:self] retain];
    [result setDisplayName:displayName];
    [result setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    [result setFrameSize:NSMakeSize(NSWidth([containerView frame]), 0)];
    [result setFrameOrigin:NSZeroPoint];
    [result addObserver:self forKeyPath:@"progress" options:0 context:(void *)kProgressContext];
    return result;
}

- (void)prepareBannerWithView:(HFDocumentOperationView *)newSubview withTargetFirstResponder:(id)targetFirstResponder {
    HFASSERT(operationView == nil);
    operationView = newSubview;
    bannerTargetHeight = [newSubview defaultHeight];
    if (! bannerView) bannerView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1, 1)];
    NSRect containerBounds = [containerView bounds];
    NSRect bannerFrame = NSMakeRect(NSMinX(containerBounds), NSMaxY(containerBounds), NSWidth(containerBounds), 0);
    [bannerView setFrame:bannerFrame];
    bannerStartTime = 0;
    bannerIsShown = YES;
    bannerGrowing = YES;
    targetFirstResponderInBanner = targetFirstResponder;
    if (isRunningOnLeopardOrLater()) {
        if (! bannerDividerThumb) bannerDividerThumb = [[HFBannerDividerThumb alloc] initWithFrame:NSMakeRect(0, 0, 14, 14)];
        [bannerDividerThumb setAutoresizingMask:0];
        [bannerDividerThumb setFrameOrigin:NSMakePoint(3, 0)];
        [bannerDividerThumb removeFromSuperview];
        [bannerView addSubview:bannerDividerThumb];
    }
    if (newSubview) {
        NSSize newSubviewSize = [newSubview frame].size;
        if (newSubviewSize.width != NSWidth(containerBounds)) {
            newSubviewSize.width = NSWidth(containerBounds);
            [newSubview setFrameSize:newSubviewSize];
        }
        if (bannerDividerThumb) [bannerView addSubview:newSubview positioned:NSWindowBelow relativeTo:bannerDividerThumb];
        else [bannerView addSubview:newSubview];
    }
    [bannerResizeTimer invalidate];
    [bannerResizeTimer release];
    bannerResizeTimer = [[NSTimer scheduledTimerWithTimeInterval:1. / 60. target:self selector:@selector(animateBanner:) userInfo:nil repeats:YES] retain];
    [self updateDocumentWindowTitle];
}


- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    USE(typeName);
    USE(outError);
    BOOL result = NO;
    HFASSERT([absoluteURL isFileURL]);
    HFFileReference *fileReference = [[[HFFileReference alloc] initWithPath:[absoluteURL path] error:outError] autorelease];
    if (fileReference) {
        HFFileByteSlice *byteSlice = [[[HFFileByteSlice alloc] initWithFile:fileReference] autorelease];
        HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
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
        if ([self representerIsShown:rep]) {
            [self hideViewForRepresenter:rep];
            [self relayoutAndResizeWindowPreservingFrame];
        }
        else {
            [self showViewForRepresenter:rep];
            [self relayoutAndResizeWindowPreservingFrame];
        }
        [self saveDefaultRepresentersToDisplay];
    }
}

- (void)setFont:(NSFont *)font {
    HFASSERT(font != nil);
    NSWindow *window = [self window];
    NSDisableScreenUpdates();
    NSUInteger bytesPerLine = [controller bytesPerLine];
    /* Record that we are currently setting the font.  We use this to decide which direction to grow the window if our line numbers change. */
    currentlySettingFont = YES;
    [controller setFont:font];
    [self relayoutAndResizeWindowForBytesPerLine:bytesPerLine];
    currentlySettingFont = NO;
    [window display];
    NSEnableScreenUpdates();
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setDouble:[font pointSize] forKey:@"DefaultFontSize"];
    [defs setObject:[font fontName] forKey:@"DefaultFontName"];
}

- (NSFont *)font {
    return [controller font];
}

- (void)setFontSizeFromMenuItem:(NSMenuItem *)item {
    NSString *fontName = [[self font] fontName];
    [self setFont:[NSFont fontWithName:fontName size:(CGFloat)[item tag]]];
}

- (IBAction)setAntialiasFromMenuItem:(id)sender {
    USE(sender);
    BOOL newVal = ! [controller shouldAntialias];
    [controller setShouldAntialias:newVal];
    [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"AntialiasText"];
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    SEL action = [item action];
    if (action == @selector(toggleVisibleControllerView:)) {
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
    else if (action == @selector(performFindPanelAction:)) {
        switch ([item tag]) {
            case NSFindPanelActionShowFindPanel:
            case NSFindPanelActionNext:
            case NSFindPanelActionPrevious:
                return YES;
            default:
                return NO;
        }
    }
    else if (action == @selector(setFontSizeFromMenuItem:)) {
        [item setState:[[self font] pointSize] == [item tag]];
        return YES;
    }
    else if (action == @selector(setAntialiasFromMenuItem:)) {
        [item setState:[controller shouldAntialias]];
        return YES;		
    }
    else if (action == @selector(toggleOverwriteMode:)) {
        [item setState:[controller inOverwriteMode]];
        /* We can toggle overwrite mode only if the controller doesn't require that it be on */
        return ! [controller requiresOverwriteMode];
    }
    else if (action == @selector(modifyByteGrouping:)) {
        [item setState:(NSUInteger)[item tag] == [controller bytesPerColumn]];
        return YES;
    }
    else return [super validateMenuItem:item];
}

- (void)finishedAnimation {
    if (! bannerGrowing) {
        bannerIsShown = NO;
        [bannerDividerThumb removeFromSuperview];
        [bannerView removeFromSuperview];
        [[[[bannerView subviews] copy] autorelease] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        [bannerView release];
        bannerView = nil;
        operationView = nil;
        [self updateDocumentWindowTitle];
        [containerView setNeedsDisplay:YES];
        if (commandToRunAfterBannerIsDoneHiding) {
            SEL command = commandToRunAfterBannerIsDoneHiding;
            commandToRunAfterBannerIsDoneHiding = NULL;
            [self performSelector:command withObject:nil];
        }
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

- (void)saveFirstResponderIfNotInBannerAndThenSetItTo:(id)newResponder {
    id potentialSavedFirstResponder = [[self window] firstResponder];
    if ([potentialSavedFirstResponder isKindOfClass:[NSView class]] && [potentialSavedFirstResponder ancestorSharedWithView:bannerView] != findReplaceView) {
	savedFirstResponder = potentialSavedFirstResponder;
    }
    [[self window] makeFirstResponder:newResponder];
}

- (void)animateBanner:(NSTimer *)timer {
    BOOL isFirstCall = (bannerStartTime == 0);
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (isFirstCall) bannerStartTime = now;
    CFAbsoluteTime diff = now - bannerStartTime;
    double amount = diff / .15;
    amount = fmin(fmax(amount, 0), 1);
    if (! bannerGrowing) amount = 1. - amount;
    if (bannerGrowing && diff >= 0 && [bannerView superview] != containerView) {
        [containerView addSubview:bannerView positioned:NSWindowBelow relativeTo:[layoutRepresenter view]];
        if (targetFirstResponderInBanner) {
            NSWindow *window = [self window];
            savedFirstResponder = [window firstResponder];
            [window makeFirstResponder:targetFirstResponderInBanner];
        }
    }
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
        if (timer == bannerResizeTimer && bannerResizeTimer != nil) {
            [bannerResizeTimer invalidate];
            [bannerResizeTimer release];
            bannerResizeTimer = nil;
        }
        [self finishedAnimation];
    }
}

- (BOOL)canSwitchToNewBanner {
    return operationView == nil || operationView != saveView;
}

- (void)hideBannerFirstThenDo:(SEL)command {
    HFASSERT(bannerIsShown);
    bannerGrowing = NO;
    bannerStartTime = 0;
    /* If the first responder is in our banner, move it to our view */
    NSWindow *window = [self window];
    id firstResponder = [window firstResponder];
    bannerTargetHeight = NSHeight([bannerView frame]);
    commandToRunAfterBannerIsDoneHiding = command;
    if ([firstResponder isKindOfClass:[NSView class]] && [firstResponder ancestorSharedWithView:bannerView] == bannerView) {
        [self restoreFirstResponderToSavedResponder];
    }
    [bannerResizeTimer invalidate];
    [bannerResizeTimer release];
    bannerResizeTimer = [[NSTimer scheduledTimerWithTimeInterval:1. / 60. target:self selector:@selector(animateBanner:) userInfo:nil repeats:YES] retain];
}

- (void)hideBannerImmediately {
    HFASSERT(bannerIsShown);
    NSWindow *window = [self window];
    bannerGrowing = NO;
    bannerStartTime = 0;
    bannerTargetHeight = NSHeight([bannerView frame]);
    /* If the first responder is in our banner, move it to our view */
    id firstResponder = [window firstResponder];
    if ([firstResponder isKindOfClass:[NSView class]] && [firstResponder ancestorSharedWithView:bannerView] == bannerView) {
        [self restoreFirstResponderToSavedResponder];
    }
    while (bannerIsShown) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [self animateBanner:nil];
        [window displayIfNeeded];
        [pool drain];
    }
}

- (void)showSaveBannerHavingDelayed:(NSTimer *)timer {
    HFASSERT(saveView != nil);
    USE(timer);
    if (operationView != nil && operationView != saveView) {
        [self hideBannerImmediately];
    }
    [self prepareBannerWithView:saveView withTargetFirstResponder:nil];
}

- (BOOL)writeSafelyToURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError {
    USE(inTypeName);
    *outError = NULL;
    
    HFASSERT(! saveInProgress);
    saveInProgress = YES;
    
    [HFController prepareForChangeInFile:inAbsoluteURL fromWritingByteArray:[controller byteArray]];
    
    showSaveViewAfterDelayTimer = [[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(showSaveBannerHavingDelayed:) userInfo:nil repeats:NO] retain];
    
    if (! saveView) saveView = [self newOperationViewForNibName:@"SaveBanner" displayName:@"Saving"];
    saveResult = 0;
    
    struct HFDocumentOperationCallbacks callbacks = {
        .target = self,
        .userInfo = [NSDictionary dictionaryWithObjectsAndKeys:inAbsoluteURL, @"targetURL", nil],
        .startSelector = @selector(threadedStartSave:),
        .endSelector = @selector(endSave:)
    };
    
    [[controller byteArray] incrementChangeLockCounter];
    
    [[saveView viewNamed:@"saveLabelField"] setStringValue:[NSString stringWithFormat:@"Saving \"%@\"", [self displayName]]];
    
    [saveView startOperationWithCallbacks:callbacks];
    
    while ([saveView operationIsRunning]) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        @try {  
            NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
            if (event) [NSApp sendEvent:event];
        }
        @catch (NSException *localException) {
            NSLog(@"Exception thrown during save: %@", localException);
        }
        @finally {
            [pool drain];
        }
    }
    
    [showSaveViewAfterDelayTimer invalidate];
    [showSaveViewAfterDelayTimer release];
    showSaveViewAfterDelayTimer = nil;
    
    [[controller byteArray] decrementChangeLockCounter];
    
    /* If we save to a file, then we've probably overwritten some source data, so throw away undo and just reset the document to reference the new file.  Only do this if there was no error.
    
    Note that this is actually quite wrong.  It's entirely possible that e.g. there was an error after the file was touched, e.g. when writing to the file.  In that case, we do want to just reference the file again.
    
    What we really need to know is "has a backing file been touched by this operation."  But we don't have access to that information yet.
    */
    if ((saveResult != HFSaveError) && (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation)) {
        [[self undoManager] removeAllActions];	
        HFFileReference *fileReference = [[[HFFileReference alloc] initWithPath:[inAbsoluteURL path] error:NULL] autorelease];
        if (fileReference) {
            HFFileByteSlice *byteSlice = [[[HFFileByteSlice alloc] initWithFile:fileReference] autorelease];
            HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
            [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
            [controller setByteArray:byteArray];
        }
    }
    
    if (operationView != nil && operationView == saveView) [self hideBannerFirstThenDo:NULL];
    
    if (outError) *outError = saveError;
    [saveError autorelease];
    saveError = nil;
    
    saveInProgress = NO;
    
    return saveResult != HFSaveError;
}

- (BOOL)displayCurrentSaveOperation {
    BOOL result = NO;
    if (saveInProgress) {
        HFASSERT(saveView != nil);
        result = YES;
        if (operationView == saveView) {
            /* Already showing the save view */
        }
        else if (operationView == nil) {
            [self prepareBannerWithView:saveView withTargetFirstResponder:nil];
        }
    }
    return result;
}

/* Prevent saving during saves */
- (IBAction)saveDocument:(id)sender {
    if ([self displayCurrentSaveOperation]) return;
    [super saveDocument:sender];
}

- (IBAction)saveDocumentAs:(id)sender {
    if ([self displayCurrentSaveOperation]) return;
    [super saveDocumentAs:sender];    
}

- (IBAction)saveDocumentTo:(id)sender {
    if ([self displayCurrentSaveOperation]) return;
    [super saveDocumentTo:sender];
}

- (void)showFindPanel:(NSMenuItem *)item {
    if (operationView != nil && operationView == findReplaceView) {
	[self saveFirstResponderIfNotInBannerAndThenSetItTo:[findReplaceView viewNamed:@"searchField"]];
	return;
    }
    if (! [self canSwitchToNewBanner]) {
        NSBeep();
        return;
    }
    USE(item);
    if (bannerIsShown) {
        [self hideBannerFirstThenDo:_cmd];
        return;
    }
    
    if (! findReplaceView) {
        findReplaceView = [self newOperationViewForNibName:@"FindReplaceBanner" displayName:@"Finding"];
        [[findReplaceView viewNamed:@"searchField"] setTarget:self];
        [[findReplaceView viewNamed:@"searchField"] setAction:@selector(findNext:)];
        [[findReplaceView viewNamed:@"replaceField"] setTarget:self];
        [[findReplaceView viewNamed:@"replaceField"] setAction:@selector(findNext:)]; //yes, this should be findNext:, not replace:, because when you just hit return in the replace text field, it only finds; replace is for the replace button
    }
    
    [self prepareBannerWithView:findReplaceView withTargetFirstResponder:[findReplaceView viewNamed:@"searchField"]];
}

- (NSRect)splitView:(NSSplitView *)splitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex {
    USE(dividerIndex);
    HFASSERT(splitView == containerView);
    if (bannerDividerThumb) return [bannerDividerThumb convertRect:[bannerDividerThumb bounds] toView:containerView];
    else return NSZeroRect;
}

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    HFASSERT(splitView == containerView);
    return subview == bannerView;
}

- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex {
    HFASSERT(splitView == containerView);
    USE(dividerIndex);
    if (subview == bannerView && subview != NULL) {
        [self hideBannerFirstThenDo:NULL];
    }
    return NO;
}

- (void)removeBannerIfSufficientlyShort:unused {
    USE(unused);
    willRemoveBannerIfSufficientlyShortAfterDrag = NO;
    if (bannerIsShown && bannerResizeTimer == NULL && NSHeight([bannerView frame]) < 20.) {
        [self hideBannerFirstThenDo:NULL];
    }
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    USE(notification);
    /* If the user drags the banner so that it is very small, we want it to shrink to nothing when it is released.  We handle this by checking if we are in live resize, and setting a timer to fire in NSDefaultRunLoopMode to remove the banner. */
    if (willRemoveBannerIfSufficientlyShortAfterDrag == NO && bannerResizeTimer == nil && [containerView inLiveResize]) {
        willRemoveBannerIfSufficientlyShortAfterDrag = YES;
        [self performSelector:@selector(removeBannerIfSufficientlyShort:) withObject:nil afterDelay:0. inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
    }
}

- (void)cancelOperation:sender {
    USE(sender);
    if (bannerIsShown) {
        [self hideBannerFirstThenDo:NULL];
    }
    else {
        NSBeep();
    }
}

- (id)threadedStartSave:(HFProgressTracker *)tracker {
    HFByteArray *byteArray = [controller byteArray];
    NSDictionary *userInfo = [tracker userInfo];
    NSURL *targetURL = [userInfo objectForKey:@"targetURL"];
    NSError *error = nil;
    BOOL result = [byteArray writeToFile:targetURL trackingProgress:tracker error:&error];
    [tracker noteFinished:self];
    saveError = [error retain];
    if (tracker->cancelRequested) return [NSNumber numberWithInt:HFSaveCancelled];
    else if (! result) return [NSNumber numberWithInt:HFSaveError];
    else return [NSNumber numberWithInt:HFSaveSuccessful];
}

- (void)endSave:(id)result {
#if __LP64__
    saveResult = [result integerValue];
#else
    saveResult = [result intValue]; //Tiger compatibility
#endif
    /* Post an event so our event loop wakes up */
    [NSApp postEvent:[NSEvent otherEventWithType:NSApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:NULL subtype:0 data1:0 data2:0] atStart:NO];
}

- (id)threadedStartFind:(HFProgressTracker *)tracker {
    HFASSERT(tracker != NULL);
    unsigned long long searchResult;
    NSDictionary *userInfo = [tracker userInfo];
    HFByteArray *needle = [userInfo objectForKey:@"needle"];
    HFByteArray *haystack = [userInfo objectForKey:@"haystack"];
    BOOL forwards = [[userInfo objectForKey:@"forwards"] boolValue];
    HFRange searchRange1 = [[userInfo objectForKey:@"range1"] HFRange];
    HFRange searchRange2 = [[userInfo objectForKey:@"range2"] HFRange];
    
    [tracker setMaxProgress:[haystack length]];
    
    //    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    searchResult = [haystack indexOfBytesEqualToBytes:needle inRange:searchRange1 searchingForwards:forwards trackingProgress:tracker];
    //    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    //    printf("Diff: %f\n", end - start);
    
    if (searchResult == ULLONG_MAX) {
        searchResult = [haystack indexOfBytesEqualToBytes:needle inRange:searchRange2 searchingForwards:forwards trackingProgress:tracker];
    }
    
    if (tracker->cancelRequested) return nil;
    else return [NSNumber numberWithUnsignedLongLong:searchResult];
}

- (void)findEnded:(NSNumber *)val {
    NSDictionary *userInfo = [[findReplaceView progressTracker] userInfo];
    HFByteArray *needle = [userInfo objectForKey:@"needle"];
    HFByteArray *haystack = [userInfo objectForKey:@"haystack"];
    /* nil val means cancelled */
    if (val) {
        unsigned long long searchResult = [val unsignedLongLongValue];
        if (searchResult != ULLONG_MAX) {
            HFRange resultRange = HFRangeMake(searchResult, [needle length]);
            [controller setSelectedContentsRanges:[HFRangeWrapper withRanges:&resultRange count:1]];
            [controller maximizeVisibilityOfContentsRange:resultRange];
            [self restoreFirstResponderToSavedResponder];
            [controller pulseSelection];
        }
        else {
            NSBeep();
        }
    }
    [needle decrementChangeLockCounter];
    [haystack decrementChangeLockCounter];
    
}

- (void)findNextBySearchingForwards:(BOOL)forwards {
    if ([operationView operationIsRunning]) {
	NSBeep();
	return;
    }
    HFByteArray *needle = [[findReplaceView viewNamed:@"searchField"] objectValue];
    if ([needle length] > 0) {
        HFByteArray *haystack = [controller byteArray];
        unsigned long long startLocation = [controller maximumSelectionLocation];
        unsigned long long endLocation = [controller minimumSelectionLocation];
        unsigned long long haystackLength = [haystack length];
        HFASSERT(startLocation <= [haystack length]);
        HFRange earlierRange = HFRangeMake(0, endLocation);
        HFRange laterRange = HFRangeMake(startLocation, haystackLength - startLocation);
        
        // if searching forwards, we search the range after the selection first; if searching backwards, we search the range before the selection first.
        HFRange searchRange1 = (forwards ? laterRange : earlierRange);
        HFRange searchRange2 = (forwards ? earlierRange : laterRange);
        
        NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  needle, @"needle",
                                  haystack, @"haystack",
                                  [NSNumber numberWithBool:forwards], @"forwards",
                                  [HFRangeWrapper withRange:searchRange1], @"range1",
                                  [HFRangeWrapper withRange:searchRange2], @"range2",
                                  nil];
        
        struct HFDocumentOperationCallbacks callbacks = {
            .target = self,
            .userInfo = userInfo,
            .startSelector = @selector(threadedStartFind:),
            .endSelector = @selector(findEnded:)
        };
        
        [needle incrementChangeLockCounter];
        [haystack incrementChangeLockCounter];
        
        [findReplaceView startOperationWithCallbacks:callbacks];
    }
}

- (id)threadedStartReplaceAll:(HFProgressTracker *)tracker {
    HFASSERT(tracker != NULL);
    NSDictionary *userInfo = [tracker userInfo];
    HFByteArray *needle = [userInfo objectForKey:@"needle"];
    HFByteArray *haystack = [userInfo objectForKey:@"haystack"];
    HFByteArray *replacementValue = [userInfo objectForKey:@"replacementValue"];
    const unsigned long long needleLength = [needle length];
    const unsigned long long replacementLength = [replacementValue length];
    const unsigned long long haystackLength = [haystack length];
    [tracker setMaxProgress:haystackLength];
    
    /* Perform our changes in a copy of haystack, and then set that copy back on our controller */
    HFByteArray *newHaystack = [[haystack mutableCopy] autorelease];
    unsigned long long newHaystackLength = haystackLength;    
    
    HFRange remainingRange = HFRangeMake(0, haystackLength);
    while (remainingRange.length > 0) {
        if (tracker && tracker->cancelRequested) goto cancelled;
        unsigned long long foundLocation = [haystack indexOfBytesEqualToBytes:needle inRange:remainingRange searchingForwards:YES trackingProgress:tracker];
        if (foundLocation == ULLONG_MAX) break;
        HFASSERT(foundLocation < haystackLength);
        HFASSERT(HFSum(foundLocation, needleLength) < haystackLength);
        unsigned long long offsetFromHaystackEnd = haystackLength - foundLocation;
        HFASSERT(offsetFromHaystackEnd <= newHaystackLength);
        unsigned long long offsetIntoNewHaystack = newHaystackLength - offsetFromHaystackEnd;
        HFASSERT(HFSum(offsetIntoNewHaystack, needleLength) <= newHaystackLength);
        if (tracker && tracker->cancelRequested) goto cancelled;
        [newHaystack insertByteArray:replacementValue inRange:HFRangeMake(offsetIntoNewHaystack, needleLength)];
        newHaystackLength += (replacementLength - needleLength);
        remainingRange.location = HFSum(foundLocation, needleLength);
        remainingRange.length = haystackLength - remainingRange.location;
    }
    if (tracker && tracker->cancelRequested) goto cancelled;
    return newHaystack;
    
cancelled:;
    return nil;
}

- (void)replaceAllEnded:(HFByteArray *)newValue {
    [[[findReplaceView viewNamed:@"searchField"] objectValue] decrementChangeLockCounter];
    [[controller byteArray] decrementChangeLockCounter];
    if (newValue != nil) {
        [controller replaceByteArray:newValue];
    }
}

- (void)findNext:sender {
    USE(sender);
    if ([operationView operationIsRunning]) {
	NSBeep();
	return;
    }
    [self findNextBySearchingForwards:YES];
}

- (void)findPrevious:sender {
    USE(sender);
    if ([operationView operationIsRunning]) {
	NSBeep();
	return;
    }
    [self findNextBySearchingForwards:NO];
}

- (IBAction)replace:sender {
    USE(sender);
    if ([operationView operationIsRunning]) {
	NSBeep();
	return;
    }
    HFByteArray *replaceArray = [[findReplaceView viewNamed:@"replaceField"] objectValue];
    HFASSERT(replaceArray != NULL);
    [controller insertByteArray:replaceArray replacingPreviousBytes:0 allowUndoCoalescing:NO];
    
}

- (IBAction)replaceAndFind:sender {
    if ([operationView operationIsRunning]) {
	NSBeep();
	return;
    }
    [self replace:sender];
    [self findNext:sender];
}

- (IBAction)replaceAll:sender {
    if ([operationView operationIsRunning]) {
	NSBeep();
	return;
    }
    USE(sender);
    HFByteArray *replacementValue = [[findReplaceView viewNamed:@"replaceField"] objectValue];
    HFASSERT(replacementValue != NULL);
    HFByteArray *needle = [[findReplaceView viewNamed:@"searchField"] objectValue];
    if ([needle length] == 0) {
        NSBeep();
        return;
    }
    HFByteArray *haystack = [controller byteArray];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			      replacementValue, @"replacementValue",
			      needle, @"needle",
			      haystack, @"haystack",
			      nil];
    
    struct HFDocumentOperationCallbacks callbacks = {
        .target = self,
        .userInfo = userInfo,
        .startSelector = @selector(threadedStartReplaceAll:),
        .endSelector = @selector(replaceAllEnded:)
    };
    [needle incrementChangeLockCounter];
    [haystack incrementChangeLockCounter];
    [findReplaceView startOperationWithCallbacks:callbacks];
}

- (void)performHFFindPanelAction:(NSMenuItem *)item {
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

- (void)showNavigationBannerSettingExtendSelectionCheckboxTo:(BOOL)extend {
    if (moveSelectionByView == operationView && moveSelectionByView != nil) {
        [[moveSelectionByView viewNamed:@"extendSelectionByCheckbox"] setIntValue:extend];
	[self saveFirstResponderIfNotInBannerAndThenSetItTo:[moveSelectionByView viewNamed:@"moveSelectionByTextField"]];
        return;
    }
    if (! moveSelectionByView) moveSelectionByView = [self newOperationViewForNibName:@"MoveSelectionByBanner" displayName:@"Moving Selection"];
    [[moveSelectionByView viewNamed:@"extendSelectionByCheckbox"] setIntValue:extend];
    [self prepareBannerWithView:moveSelectionByView withTargetFirstResponder:[moveSelectionByView viewNamed:@"moveSelectionByTextField"]];
    
}

- (void)moveSelectionForwards:(NSMenuItem *)sender {
    USE(sender);
    if (! [self canSwitchToNewBanner]) {
        NSBeep();
        return;
    }
    if (operationView != nil && operationView != moveSelectionByView) {
        [self hideBannerFirstThenDo:_cmd];
        return;
    }
    [self showNavigationBannerSettingExtendSelectionCheckboxTo:NO];
}

- (void)extendSelectionForwards:(NSMenuItem *)sender {
    USE(sender);
    if (! [self canSwitchToNewBanner]) {
        NSBeep();
        return;
    }
    if (operationView != nil && operationView != moveSelectionByView) {
        [self hideBannerFirstThenDo:_cmd];
        return;
    }
    [self showNavigationBannerSettingExtendSelectionCheckboxTo:YES];
}

- (void)jumpToOffset:(NSMenuItem *)sender {
    USE(sender);
    if (! [self canSwitchToNewBanner]) {
        NSBeep();
        return;
    }
    if (operationView != nil && operationView != jumpToOffsetView) {
        [self hideBannerFirstThenDo:_cmd];
        return;
    }
    if (! jumpToOffsetView) jumpToOffsetView = [self newOperationViewForNibName:@"JumpToOffsetBanner" displayName:@"Jumping to Offset"];
    [self prepareBannerWithView:jumpToOffsetView withTargetFirstResponder:[jumpToOffsetView viewNamed:@"moveSelectionByTextField"]];
}

- (BOOL)parseSuffixMultiplier:(const char *)multiplier intoMultiplier:(unsigned long long *)multiplierResultValue {
    NSParameterAssert(multiplier != NULL);
    NSParameterAssert(multiplierResultValue != NULL);
    size_t length = strlen(multiplier);
    /* Allow spaces at the end */
    while (length > 0 && multiplier[length-1] == ' ') length--;
    /* Allow an optional trailing b or B (e.g. MB or M) */
    if (length > 0 && strchr("bB", multiplier[length-1]) != NULL) length--;
    
    /* If this exhausted our string, return success, e.g. so that the user can type "5 b" and it will return a multiplier of 1 */
    if (length == 0) {
        *multiplierResultValue = 1;
        return YES;
    }
    
    /* Now check each SI suffix */
    const char * const decimalSuffixes[] = {"k", "m", "g", "t", "p", "e", "z", "y"};
    const char * const binarySuffixes[] = {"ki", "mi", "gi", "ti", "pi", "ei", "zi", "yi"};
    NSUInteger i;
    unsigned long long suffixMultiplier = 1;
    BOOL suffixMultiplierDidOverflow = NO;
    for (i=0; i < sizeof decimalSuffixes / sizeof *decimalSuffixes; i++) {
        unsigned long long product = suffixMultiplier * 1000;
        suffixMultiplierDidOverflow = suffixMultiplierDidOverflow || (product/1000 != suffixMultiplier);
        suffixMultiplier = product;
        if (! strncasecmp(multiplier, decimalSuffixes[i], length)) {
            if (suffixMultiplierDidOverflow) suffixMultiplier = ULLONG_MAX;
            *multiplierResultValue = suffixMultiplier;
            return ! suffixMultiplierDidOverflow;
        }
    }
    suffixMultiplier = 1;
    suffixMultiplierDidOverflow = NO;
    for (i=0; i < sizeof binarySuffixes / sizeof *binarySuffixes; i++) {
        unsigned long long product = suffixMultiplier * 1024;
        suffixMultiplierDidOverflow = suffixMultiplierDidOverflow || (product/1024 != suffixMultiplier);
        suffixMultiplier = product;
        if (! strncasecmp(multiplier, binarySuffixes[i], length)) {
            if (suffixMultiplierDidOverflow) suffixMultiplier = ULLONG_MAX;
            *multiplierResultValue = suffixMultiplier;
            return ! suffixMultiplierDidOverflow;
        }
    }
    return NO;
}

- (BOOL)parseMoveString:(NSString *)stringValue into:(unsigned long long *)resultValue isNegative:(BOOL *)resultIsNegative {
    const char *string = [stringValue UTF8String];
    if (string == NULL) goto invalidString;
    /* Parse the string with strtoull */
    unsigned long long amount = -1;
    unsigned long long suffixMultiplier = 1;
    int err = 0;
    BOOL isNegative = NO;
    char *endPtr = NULL;
    for (;;) {
        while (isspace(*string)) string++;
        if (*string == '-') {
            if (isNegative) goto invalidString;
            isNegative = YES;
            string++;
        }
        else {
            break;
        }
    }
    errno = 0;
    amount = strtoull(string, &endPtr, 0);
    err = errno;
    if (err != 0 || endPtr == NULL) goto invalidString;
    if (*endPtr != '\0' && ![self parseSuffixMultiplier:endPtr intoMultiplier:&suffixMultiplier]) goto invalidString;
    
    if (! HFProductDoesNotOverflow(amount, suffixMultiplier)) goto invalidString;
    amount *= suffixMultiplier;
    
    *resultValue = amount;
    *resultIsNegative = isNegative;
    return YES;
invalidString:;
    return NO;
}

- (BOOL)movingRanges:(NSArray *)ranges byAmount:(unsigned long long)value isNegative:(BOOL)isNegative isValidForLength:(unsigned long long)length {
    FOREACH(HFRangeWrapper *, wrapper, ranges) {
        HFRange range = [wrapper HFRange];
        if (isNegative) {
            if (value > range.location) return NO;
        }
        else {
            unsigned long long sum = HFMaxRange(range) + value;
            if (sum < value) return NO; /* Overflow */
            if (sum > length) return NO;
        }
    }
    return YES;
}

- (IBAction)moveSelectionToAction:(id)sender {
    USE(sender);
    BOOL success = NO;
    unsigned long long value;
    BOOL isNegative;
    if ([self parseMoveString:[[jumpToOffsetView viewNamed:@"moveSelectionByTextField"] stringValue] into:&value isNegative:&isNegative]) {
        unsigned long long length = [controller contentsLength];
        if (length >= value) {
            const unsigned long long offset = (isNegative ? length - value : value);
            const HFRange contentsRange = HFRangeMake(offset, 0);
            [controller setSelectedContentsRanges:[NSArray arrayWithObject:[HFRangeWrapper withRange:contentsRange]]];
            [controller maximizeVisibilityOfContentsRange:contentsRange];
            [controller pulseSelection];
            success = YES;
        }
    }
    if (! success) NSBeep();
}

- (IBAction)moveSelectionByAction:(id)sender {
    USE(sender);
    BOOL success = NO;
    unsigned long long value;
    BOOL isNegative;
    if ([self parseMoveString:[[moveSelectionByView viewNamed:@"moveSelectionByTextField"] stringValue] into:&value isNegative:&isNegative]) {
	if ([self movingRanges:[controller selectedContentsRanges] byAmount:value isNegative:isNegative isValidForLength:[controller contentsLength]]) {
	    BOOL extendSelection = !![[moveSelectionByView viewNamed:@"extendSelectionByCheckbox"] intValue];
	    HFControllerMovementDirection direction = (isNegative ? HFControllerDirectionLeft : HFControllerDirectionRight);
	    HFControllerSelectionTransformation transformation = (extendSelection ? HFControllerExtendSelection : HFControllerShiftSelection);
	    [controller moveInDirection:direction byByteCount:value withSelectionTransformation:transformation usingAnchor:NO];
	    [controller maximizeVisibilityOfContentsRange:[[[controller selectedContentsRanges] objectAtIndex:0] HFRange]];
	    [controller pulseSelection];
	    success = YES;
	}
    }
    if (! success) NSBeep();
}


- (IBAction)showFontPanel:(id)sender {
    NSFontPanel *panel = [NSFontPanel sharedFontPanel];
    [panel orderFront:sender];
    [panel setPanelFont:[self font] isMultiple:NO];
}

- (void)changeFont:(id)sender {
    [self setFont:[sender convertFont:[self font]]];
}

- (IBAction)modifyByteGrouping:sender {
    NSUInteger bytesPerLine = [controller bytesPerLine], newDesiredBytesPerLine;
    NSUInteger newBytesPerColumn = (NSUInteger)[sender tag];
    if (newBytesPerColumn == 0) {
        newDesiredBytesPerLine = bytesPerLine;
    }
    else {
        newDesiredBytesPerLine = MAX(newBytesPerColumn, bytesPerLine - (bytesPerLine % newBytesPerColumn));
    }
    [controller setBytesPerColumn:newBytesPerColumn];
    [self relayoutAndResizeWindowForBytesPerLine:newDesiredBytesPerLine]; //this ensures that the window does not shrink when going e.g. from 4->8->4
    [[NSUserDefaults standardUserDefaults] setInteger:newBytesPerColumn forKey:@"BytesPerColumn"];
}

- (IBAction)toggleOverwriteMode:sender {
    USE(sender);
    [controller setInOverwriteMode:![controller inOverwriteMode]];
    [self updateDocumentWindowTitle];
}


+ (void)didEndBreakFileDependencySheet:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    USE(alert);
    USE(contextInfo);
    [NSApp stopModalWithCode:returnCode];
    
}

+ (void)prepareForChangeInFileByBreakingFileDependencies:(NSNotification *)note {
    HFFileReference *fileReference = [note object];
    NSDictionary *userInfo = [note userInfo];
    
    BOOL *cancellationPointer = [[userInfo objectForKey:HFChangeInFileShouldCancelKey] pointerValue];
    if (*cancellationPointer) return; //don't do anything if someone requested cancellation
    
    HFByteArray *byteArray = [userInfo objectForKey:HFChangeInFileByteArrayKey];
    NSArray *modifiedRanges = [userInfo objectForKey:HFChangeInFileModifiedRangesKey];
    NSArray *allDocuments = [[[NSDocumentController sharedDocumentController] documents] copy]; //we copy this because we may need to close them
    
    /* Determine which document contains this byte array so we can make a nice dialog */
    NSDocument *documentForThisByteArray = nil;
    FOREACH(MyDocument *, testDocument, allDocuments) {
        if ([testDocument->controller byteArray] == byteArray) {
            documentForThisByteArray = testDocument;
            break;
        }
    }
    HFASSERT(documentForThisByteArray != nil); //for now we require that saving a ByteArray is associated with a document save
    
    FOREACH(MyDocument *, document, allDocuments) {
	if (! [document isKindOfClass:[MyDocument class]]) {
	    /* Paranoia in case other NSDocument classes slip in */
	    continue;
	}
        if (document == documentForThisByteArray) continue; //this is the document being saved
        
	HFByteArray *itsArray = [document->controller byteArray];
	if (! [itsArray clearDependenciesOnRanges:modifiedRanges inFile:fileReference]) {
	    /* We aren't able to remove our dependency on this file in this document, so ask permission to close it.  We don't try to save the document first, because if saving the document would require breaking dependencies in another document, we could get into an infinite loop! */
	    NSAlert *alert = [[NSAlert alloc] init];
	    [alert setMessageText:[NSString stringWithFormat:@"This document contains data that will be overwritten if you save the document \"%@.\"", [documentForThisByteArray displayName]]];
	    [alert setInformativeText:@"To save that document, you must close this one."];
	    [alert addButtonWithTitle:@"Cancel Save"];
	    [alert addButtonWithTitle:@"Close, Discarding Any Changes"];
	    [alert beginSheetModalForWindow:[document windowForSheet] modalDelegate:self didEndSelector:@selector(didEndBreakFileDependencySheet:returnCode:contextInfo:) contextInfo:nil];
	    NSInteger modalResult = [NSApp runModalForWindow:[alert window]];
	    [alert release];
	    
	    BOOL didCancel = (modalResult == NSAlertFirstButtonReturn);
	    if (didCancel) *cancellationPointer = YES;
	    
	    if (! didCancel) [document close];
	}
	
    }
    [allDocuments release];
}

@end
