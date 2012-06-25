//
//  MyDocument.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "BaseDataDocument.h"
#import "HFBannerDividerThumb.h"
#import "HFDocumentOperationView.h"
#import "DataInspectorRepresenter.h"
#import "TextDividerRepresenter.h"
#import "AppDebugging.h"
#import "AppUtilities.h"
#import <HexFiend/HexFiend.h>
#include <pthread.h>
#include <objc/runtime.h>

static const char *const kProgressContext = "context";

NSString * const BaseDataDocumentDidChangeStringEncodingNotification = @"BaseDataDocumentDidChangeStringEncodingNotification";

enum {
    HFSaveSuccessful,
    HFSaveCancelled,
    HFSaveError
};


static BOOL isRunningOnLeopardOrLater(void) {
    return NSAppKitVersionNumber >= 860.;
}

static inline Class preferredByteArrayClass(void) {
    return [HFAttributedByteArray class];
}

@interface BaseDataDocument (ForwardDeclarations)
- (NSString *)documentWindowTitleFormatString;
- (id)threadedSaveToURL:(NSURL *)targetURL trackingProgress:(HFProgressTracker *)tracker error:(NSError **)error;
@end

/* Subclass to display custom window title that shows progress */
@interface MyDocumentWindowController : NSWindowController

@end

@interface UndoRedoByteArrayReference : NSObject {
@public
    HFByteArray *byteArray;
}
@end

@implementation UndoRedoByteArrayReference

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

@implementation BaseDataDocument

+ (NSString *)userDefKeyForRepresenterWithName:(const char *)repName {
    NSString *result = nil;
    NSString *layoutIdentifier = [self layoutUserDefaultIdentifier];
    if (layoutIdentifier) {
        result = [NSString stringWithFormat:@"RepresenterIsShown %@ %s", layoutIdentifier, repName];
    }
    return result;
}

#define USERDEFS_KEY_FOR_REP(r) [[self class] userDefKeyForRepresenterWithName: #r]

+ (NSString *)layoutUserDefaultIdentifier {
    return NSStringFromClass(self);
}

/* Register the default-defaults for this class. */
+ (void)registerDefaultDefaults {
    static OSSpinLock sLock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&sLock); //use a spinlock to be safe, but contention should be very low because we only expect to make these on the main thread
    static BOOL sRegisteredGlobalDefaults = NO;
    const id yes = (id)kCFBooleanTrue;
    if (! sRegisteredGlobalDefaults) {
        /* Defaults common to all subclasses */
        NSDictionary *defs = [[NSDictionary alloc] initWithObjectsAndKeys:
                              yes, @"AntialiasText",
                              @"Monaco", @"DefaultFontName",
                              [NSNumber numberWithDouble:10.], @"DefaultFontSize",
                              [NSNumber numberWithInteger:4], @"BytesPerColumn",
                              [NSNumber numberWithInteger:[NSString defaultCStringEncoding]], @"DefaultStringEncoding",
                              nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
        [defs release];
        sRegisteredGlobalDefaults = YES;
    }
    
    static NSMutableArray *sRegisteredDefaultsByIdentifier = nil;
    NSString *ident = [self layoutUserDefaultIdentifier];
    if (ident && ! [sRegisteredDefaultsByIdentifier containsObject:ident]) {
        /* Register defaults for this identifier */
        if (! sRegisteredDefaultsByIdentifier) sRegisteredDefaultsByIdentifier = [[NSMutableArray alloc] init];
        [sRegisteredDefaultsByIdentifier addObject:ident];
        
        NSDictionary *defs = [[NSDictionary alloc] initWithObjectsAndKeys:
                              yes, USERDEFS_KEY_FOR_REP(lineCountingRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(hexRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(asciiRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(dataInspectorRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(statusBarRepresenter),
                              yes, USERDEFS_KEY_FOR_REP(scrollRepresenter),
                              nil];
        [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
        [defs release];
    }
    OSSpinLockUnlock(&sLock);
}

+ (void)initialize {
    if (self == [BaseDataDocument class]) {
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
#if ! NDEBUG
                              yes, @"NSApplicationShowExceptions",
#endif
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
    return [NSArray arrayWithObjects:lineCountingRepresenter, hexRepresenter, asciiRepresenter, scrollRepresenter, dataInspectorRepresenter, statusBarRepresenter, textDividerRepresenter, nil];
}

- (HFByteArray *)byteArray {
    return [controller byteArray];
}

- (BOOL)representerIsShown:(HFRepresenter *)representer {
    NSParameterAssert(representer);
    return [[layoutRepresenter representers] containsObject:representer];
}

- (void)showViewForRepresenter:(HFRepresenter *)rep {
    HFASSERT([[rep view] superview] == nil && [[rep view] window] == nil);
    [controller addRepresenter:rep];
    [layoutRepresenter addRepresenter:rep];
}

- (void)hideViewForRepresenter:(HFRepresenter *)rep {
    HFASSERT(rep != NULL);
    HFASSERT([[layoutRepresenter representers] indexOfObjectIdenticalTo:rep] != NSNotFound);
    [controller removeRepresenter:rep];
    [layoutRepresenter removeRepresenter:rep];
}

- (BOOL)dividerRepresenterShouldBeShown {
    return [self representerIsShown:hexRepresenter] && [self representerIsShown:asciiRepresenter];
}

/* Called to show or hide the divider representer. This should be shown when both our text representers are visible */
- (void)showOrHideDividerRepresenter {
    BOOL dividerRepresenterShouldBeShown = [self dividerRepresenterShouldBeShown];;
    BOOL dividerRepresenterIsShown = [self representerIsShown:textDividerRepresenter];
    if (dividerRepresenterShouldBeShown && ! dividerRepresenterIsShown) {
        [self showViewForRepresenter:textDividerRepresenter];
    } else if (! dividerRepresenterShouldBeShown && dividerRepresenterIsShown) {
        [self hideViewForRepresenter:textDividerRepresenter];
    }
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
    if (isApplying) {
        [self showOrHideDividerRepresenter];
    }
}

- (void)saveDefaultRepresentersToDisplay {    
    [self saveOrApplyDefaultRepresentersToDisplay:NO];
}

- (void)applyDefaultRepresentersToDisplay {
    [self saveOrApplyDefaultRepresentersToDisplay:YES];
}

- (NSArray *)runningOperationViews {
    NSView *views[16];
    NSUInteger idx = 0;
    if ([findReplaceView operationIsRunning]) views[idx++] = findReplaceView;
    if ([moveSelectionByView operationIsRunning]) views[idx++] = moveSelectionByView;
    if ([jumpToOffsetView operationIsRunning]) views[idx++] = jumpToOffsetView;
    if ([saveView operationIsRunning]) views[idx++] = saveView;
    return [NSArray arrayWithObjects:views count:idx];
}

/* Return a format string that can take one argument which is the document name. */
- (NSString *)documentWindowTitleFormatString {
    NSMutableString *result = [NSMutableString stringWithString:@"%@"]; //format specifier that is replaced with document name

    switch ([controller editMode]) {
    case HFInsertMode:
        break;
    case HFOverwriteMode:
        [result appendString:NSLocalizedString(@" **OVERWRITE MODE**", @"Title Suffix")];
        break;
    case HFReadOnlyMode:
        [result appendString:NSLocalizedString(@" **READ-ONLY MODE**", @"Title Suffix")];
        break;
    }

    BOOL hasAppendedProgressMarker = NO;
    NSArray *runningViews = [self runningOperationViews];
    FOREACH(HFDocumentOperationView *, view, runningViews) {
        /* Skip the currently visible view */
        if (view == operationView) continue;
        
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
    if (hasAppendedProgressMarker) [result appendString:@")"];
    return result;
}

- (void)updateDocumentWindowTitle {
    [[self windowControllers] makeObjectsPerformSelector:@selector(synchronizeWindowTitleWithDocumentName)];    
}

- (void)makeWindowControllers {
    /* We may already have a window controller if we replaced a transient document; in that case do nothing. */
    if ([[self windowControllers] count] == 0) {
        NSString *windowNibName = [self windowNibName];
        if (windowNibName != nil) {
            NSWindowController *windowController = [[MyDocumentWindowController alloc] initWithWindowNibName:windowNibName owner:self];
            [self addWindowController:windowController];
            [windowController release];
        }
    }
}

- (CGFloat)minimumWindowFrameWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    NSView *layoutView = [layoutRepresenter view];
    CGFloat resultingWidthInLayoutCoordinates = [layoutRepresenter minimumViewWidthForBytesPerLine:bytesPerLine];
    NSSize resultSize = [layoutView convertSize:NSMakeSize(resultingWidthInLayoutCoordinates, 1) toView:nil];
    return resultSize.width;
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

- (void)setContainerView:(NSSplitView *)view {
    /* Called when the nib is loaded.  We retain it. */
    [view retain];
    [containerView release];
    containerView = view;
}

/* Shared point for setting up a window, optionally setting a bytes per line */
- (void)setupWindowEnforcingBytesPerLine:(NSUInteger)bplOrZero {
    
    NSView *layoutView = [layoutRepresenter view];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    if (containerView) {
        [containerView setVertical:NO];
        if ([containerView respondsToSelector:@selector(setDividerStyle:)]) {
            [containerView setDividerStyle:2/*NSSplitViewDividerStyleThin*/];
        }
        [containerView setDelegate:(id)self];
        [layoutView setFrame:[containerView bounds]];
        [containerView addSubview:layoutView];
    }
    [self applyDefaultRepresentersToDisplay];
    
    if (bplOrZero > 0) {
        /* Here we probably get larger */
        [self relayoutAndResizeWindowForBytesPerLine:bplOrZero];
    } else {
        /* Here we probably get smaller */
        [self relayoutAndResizeWindowPreservingFrame];
    }
}

- (void)windowControllerDidLoadNib:(NSWindowController *)windowController {
    [super windowControllerDidLoadNib:windowController];
    [self setupWindowEnforcingBytesPerLine:0];
}

- (void)adoptWindowController:(NSWindowController *)windowController fromTransientDocument:(BaseDataDocument *)transientDocument {
    NSParameterAssert(windowController != nil);
    NSParameterAssert(transientDocument != nil);
    
    NSWindow *window = [windowController window];
    if (! window) return;
    
    /* Get the BPL of the document so we can preserve it */
    NSUInteger oldBPL = [transientDocument->controller bytesPerLine];
    
    /* Set the delegate */
    [window setDelegate:self];
    
    /* Find the split view */
    NSView *contentView = [window contentView];
    NSArray *contentSubviews = [contentView subviews];
    NSAssert1([contentSubviews count] == 1, @"Unable to adopt transient window controller %@", windowController);
    NSSplitView *splitView = [contentSubviews objectAtIndex:0];
    NSAssert1([splitView isKindOfClass:[NSSplitView class]], @"Unable to adopt transient window controller %@", windowController);
    
    /* Remove all of its subviews */
    NSArray *existingViews = [[splitView subviews] copy];
    FOREACH(NSView *, view, existingViews) {
        [view removeFromSuperview];
    }
    [existingViews release];
    
    /* It's our split view now! */
    [containerView release];
    containerView = [splitView retain];
    
    /* Set up the window */
    [self setupWindowEnforcingBytesPerLine:oldBPL];
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
    self = [super init];
    
    /* Make sure we register our defaults for this class */
    [[self class] registerDefaultDefaults];
    
    lineCountingRepresenter = [[HFLineCountingRepresenter alloc] init];
    hexRepresenter = [[HFHexTextRepresenter alloc] init];
    asciiRepresenter = [[HFStringEncodingTextRepresenter alloc] init];
    scrollRepresenter = [[HFVerticalScrollerRepresenter alloc] init];
    layoutRepresenter = [[HFLayoutRepresenter alloc] init];
    statusBarRepresenter = [[HFStatusBarRepresenter alloc] init];
    dataInspectorRepresenter = [[DataInspectorRepresenter alloc] init];
    textDividerRepresenter = [[TextDividerRepresenter alloc] init];
    
    [(NSView *)[hexRepresenter view] setAutoresizingMask:NSViewHeightSizable];
    [(NSView *)[asciiRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
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
    
    [self setStringEncoding:[[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultStringEncoding"]];
    
    static BOOL hasAddedMenu = NO;
    if (! hasAddedMenu) {
        hasAddedMenu = YES;
        if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HFDebugMenu"]) {
            NSMenu *menu = [[[NSApp mainMenu] itemWithTitle:@"Debug"] submenu];
            [self installDebuggingMenuItems:menu];
        }
    }
    return self;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [lineCountingRepresenter release];
    
    [hexRepresenter release];
    [asciiRepresenter release];
    [scrollRepresenter release];
    [layoutRepresenter release];
    [statusBarRepresenter release];
    [dataInspectorRepresenter release];
    [textDividerRepresenter release];
    
    [controller release];
    [bannerView release];
    
    /* Release and stop observing our banner views.  Note that any of these may be nil. */
    HFDocumentOperationView *views[] = {findReplaceView, moveSelectionByView, jumpToOffsetView, saveView};
    for (NSUInteger i = 0; i < sizeof views / sizeof *views; i++) {
        [views[i] removeObserver:self forKeyPath:@"progress"];
        [views[i] release];
    }
    [containerView release];
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


- (HFDocumentOperationView *)newOperationViewForNibName:(NSString *)name displayName:(NSString *)displayName fixedHeight:(BOOL)fixedHeight {
    HFASSERT(name);
    HFDocumentOperationView *result = [[HFDocumentOperationView viewWithNibNamed:name owner:self] retain];
    [result setDisplayName:displayName];
    [result setIsFixedHeight:fixedHeight];
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

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSArray *files = [sender.draggingPasteboard propertyListForType:NSFilenamesPboardType];
    for (NSString *filename in files) {
        NSURL *fileURL = [NSURL fileURLWithPath:filename];
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES error:nil];
    }
    return YES;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    USE(typeName);
    USE(outError);
    BOOL result = NO;
    HFASSERT([absoluteURL isFileURL]);
    HFFileReference *fileReference = [[[HFFileReference alloc] initWithPath:[absoluteURL path] error:outError] autorelease];
    if (fileReference) {
        
        HFFileByteSlice *byteSlice = [[[HFFileByteSlice alloc] initWithFile:fileReference] autorelease];
        //        HFByteSlice *byteSlice = [[[NSClassFromString(@"HFRandomDataByteSlice") alloc] initWithRandomDataLength:ULLONG_MAX] autorelease];
        //        pid_t pid = [[[NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.apple.TextEdit"] lastObject] processIdentifier];
        //        HFByteSlice *byteSlice = [[[NSClassFromString(@"HFProcessMemoryByteSlice") alloc] initWithPID:pid range:HFRangeMake(0, 1 + (unsigned long long)UINT_MAX)] autorelease];
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
            [self showOrHideDividerRepresenter];
            [self relayoutAndResizeWindowPreservingFrame];
        }
        else {
            [self showViewForRepresenter:rep];
            [self showOrHideDividerRepresenter];
            [self relayoutAndResizeWindowPreservingFrame];
        }
        [self saveDefaultRepresentersToDisplay];
    }
}

- (void)setFont:(NSFont *)font registeringUndo:(BOOL)undo {
    HFASSERT(font != nil);
    
    /* If we should register undo, do so, but do it behind NSDocument's back so it doesn't think the document was edited.  I tried temporarily clearing our undo manager, but that resulted in some wacky infinite loop, so do it this way instead. */
    if (undo) {
        NSFont *existingFont = [self font];
        NSUndoManager *undoer = [self undoManager];
        [[undoer prepareWithInvocationTarget:self] setFont:existingFont registeringUndo:YES];
    }
    
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
    [self setFont:[NSFont fontWithName:fontName size:(CGFloat)[item tag]] registeringUndo:YES];
}

- (IBAction)increaseFontSize:(id)sender {
    USE(sender);
    NSFont *font = [self font];
    [self setFont:[NSFont fontWithName:[font fontName] size:[font pointSize] + 1] registeringUndo:YES];
}

- (IBAction)decreaseFontSize:(id)sender {
    USE(sender);
    NSFont *font = [self font];
    [self setFont:[NSFont fontWithName:[font fontName] size:[font pointSize] - 1] registeringUndo:YES];
}

- (NSStringEncoding)stringEncoding {
    return [(HFStringEncodingTextRepresenter *)asciiRepresenter encoding];
}

- (void)setStringEncoding:(NSStringEncoding)encoding {
    NSUInteger bytesPerLine = [controller bytesPerLine];
    [(HFStringEncodingTextRepresenter *)asciiRepresenter setEncoding:encoding];
    if ([[self windowControllers] count] > 0) {
        [self relayoutAndResizeWindowForBytesPerLine:bytesPerLine];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:BaseDataDocumentDidChangeStringEncodingNotification object:self userInfo:nil];
}

- (void)setStringEncodingFromMenuItem:(NSMenuItem *)item {
    [self setStringEncoding:[item tag]];
    
    /* Call to the delegate so it sets the default */
    [[NSApp delegate] setStringEncodingFromMenuItem:item];
}


- (IBAction)setAntialiasFromMenuItem:(id)sender {
    USE(sender);
    BOOL newVal = ! [controller shouldAntialias];
    [controller setShouldAntialias:newVal];
    [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"AntialiasText"];
}


/* Returns the selected bookmark, or NSNotFound. If more than one bookmark is selected, returns the largest. */
- (NSInteger)selectedBookmark {
    NSInteger result = NSNotFound;
    NSArray *ranges = [controller selectedContentsRanges];
    if ([ranges count] > 0) {
        HFRange range = [[ranges objectAtIndex:0] HFRange];
        if (range.length == 0 && range.location < [controller contentsLength]) range.length = 1;
        NSEnumerator *attributeEnumerator = [[controller attributesForBytesInRange:range] attributeEnumerator];
        NSString *attribute;
        while ((attribute = [attributeEnumerator nextObject])) {
            NSInteger thisBookmark = HFBookmarkFromBookmarkAttribute(attribute);
            if (thisBookmark != NSNotFound && (result == NSNotFound || thisBookmark > result)) {
                result = thisBookmark;
            }
        }
    }
    return result;
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
    else if (action == @selector(decreaseFontSize:)) {
        return [[self font] pointSize] >= 5.; //5 is our minimum font size
    }    
    else if (action == @selector(setAntialiasFromMenuItem:)) {
        [item setState:[controller shouldAntialias]];
        return YES;		
    }
    else if (action == @selector(setOverwriteMode:)) {
        [item setState:[controller editMode] == HFOverwriteMode];
        /* We can toggle overwrite mode only if the controller doesn't require that it be on */
        return YES;
    }
    else if (action == @selector(setInsertMode:)) {
        [item setState:[controller editMode] == HFInsertMode];
        return ![self requiresOverwriteMode];
    }
    else if (action == @selector(setReadOnlyMode:)) {
        [item setState:[controller editMode] == HFReadOnlyMode];
        return YES;
    }
    else if (action == @selector(modifyByteGrouping:)) {
        [item setState:(NSUInteger)[item tag] == [controller bytesPerColumn]];
        return YES;
    }
    else if (action == @selector(scrollToBookmark:) || action == @selector(selectBookmark:)) {
        HFRange range = [controller rangeForBookmark:[item tag]];
        return range.location != ULLONG_MAX || range.length != ULLONG_MAX;
    }
    else if (action == @selector(deleteBookmark:)) {
        NSInteger selectedBookmark = [self selectedBookmark];
        NSString *newTitle;
        if (selectedBookmark == NSNotFound) {
            newTitle = NSLocalizedString(@"Remove Bookmark", @"Menu item title for remove bookmark");
        }
        else {
            newTitle = [NSString stringWithFormat:NSLocalizedString(@"Remove Bookmark %ld", @"Menu item title for removing a particular bookmark"), selectedBookmark];
        }
        [item setTitle:newTitle];
        return selectedBookmark != NSNotFound;
    }
    else if (action == @selector(saveDocument:)) {
        if ([controller editMode] == HFReadOnlyMode)
            return NO;
        // Fall through
    }

    return [super validateMenuItem:item];
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
    
    BOOL shouldProceed = [HFController prepareForChangeInFile:inAbsoluteURL fromWritingByteArray:[controller byteArray]];
    if (! shouldProceed) {
        /* Some other document has data that will be affected by this, and it doesn't want us to write it. */
        saveInProgress = NO;
        if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
        return NO;
    }
    
    showSaveViewAfterDelayTimer = [[NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(showSaveBannerHavingDelayed:) userInfo:nil repeats:NO] retain];
    
    if (! saveView) saveView = [self newOperationViewForNibName:@"SaveBanner" displayName:@"Saving" fixedHeight:YES];
    
    [[controller byteArray] incrementChangeLockCounter];
    
    [[saveView viewNamed:@"saveLabelField"] setStringValue:[NSString stringWithFormat:@"Saving \"%@\"", [self displayName]]];

    __block NSInteger saveResult = 0;
    [saveView startOperation:^id(HFProgressTracker *tracker) {
        id result = [self threadedSaveToURL:inAbsoluteURL trackingProgress:tracker error:outError];
        /* Retain the error so it can be autoreleased in the main thread */
        [*outError retain];
        return result;
    } completionHandler:^(id result) {
        saveResult = [result integerValue];
        
        /* Post an event so our event loop wakes up */
        [NSApp postEvent:[NSEvent otherEventWithType:NSApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:NULL subtype:0 data1:0 data2:0] atStart:NO];
    }];

    while ([saveView operationIsRunning]) {
        @autoreleasepool {
            @try {  
                NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
                if (event) [NSApp sendEvent:event];
            }
            @catch (NSException *localException) {
                NSLog(@"Exception thrown during save: %@", localException);
            }
        }
    }

    [*outError autorelease];

    [showSaveViewAfterDelayTimer invalidate];
    [showSaveViewAfterDelayTimer release];
    showSaveViewAfterDelayTimer = nil;
    
    [[controller byteArray] decrementChangeLockCounter];
    
    /* If we save to a file, then we've probably overwritten some source data, so just reset the document to reference the new file.  Only do this if there was no error.
     
     Note that this is actually quite wrong.  It's entirely possible that e.g. there was an error after the file was touched, e.g. when writing to the file.  In that case, we do want to just reference the file again.
     
     What we really need to know is "has a backing file been touched by this operation."  But we don't have access to that information yet.
     */
    if ((saveResult != HFSaveError) && (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation)) {
        HFFileReference *fileReference = [[[HFFileReference alloc] initWithPath:[inAbsoluteURL path] error:NULL] autorelease];
        if (fileReference) {
            HFByteArray *oldByteArray = [controller byteArray];

            HFByteArray *newByteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
            HFFileByteSlice *byteSlice = [[[HFFileByteSlice alloc] initWithFile:fileReference] autorelease];
            [newByteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
            
            /* Propogate attributes (like bookmarks) */
            HFByteRangeAttributeArray *oldAttributes = [oldByteArray byteRangeAttributeArray];
            HFByteRangeAttributeArray *newAttributes = [newByteArray byteRangeAttributeArray];
            if (oldAttributes && newAttributes) {
                HFRange range = HFRangeMake(0, MIN([oldByteArray length], [newByteArray length]));
                [newAttributes transferAttributesFromAttributeArray:oldAttributes range:range baseOffset:0 validator:NULL];
            }            
            [controller setByteArray:newByteArray];
        }
    }
    
    if (operationView != nil && operationView == saveView) [self hideBannerFirstThenDo:NULL];
    
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
        findReplaceView = [self newOperationViewForNibName:@"FindReplaceBanner" displayName:@"Finding" fixedHeight:NO];
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

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex {
    HFASSERT(splitView == containerView);
    CGFloat result = proposedMaximumPosition;
    /* If our operation view is fixed height, then don't allow it to grow beyond its initial height */
    if (operationView != nil && [operationView isFixedHeight]) {
        /* Make sure it's actually our view */
        if (dividerIndex == 0 && [[splitView subviews] objectAtIndex:0] == bannerView) {
            CGFloat maxHeight = [operationView defaultHeight];
            if (maxHeight > 0 && maxHeight < proposedMaximumPosition) {
                result = maxHeight;
            }
        }
    }
    return result;
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

- (id)threadedSaveToURL:(NSURL *)targetURL trackingProgress:(HFProgressTracker *)tracker error:(NSError **)error {
    HFByteArray *byteArray = [controller byteArray];
    BOOL result = [byteArray writeToFile:targetURL trackingProgress:tracker error:error];
    [tracker noteFinished:self];
    if (tracker->cancelRequested) return [NSNumber numberWithInt:HFSaveCancelled];
    else if (! result) return [NSNumber numberWithInt:HFSaveError];
    else return [NSNumber numberWithInt:HFSaveSuccessful];    
}

- (id)threadedFindBytes:(HFByteArray *)needle inBytes:(HFByteArray *)haystack inRange1:(HFRange)range1 range2:(HFRange)range2 forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)tracker {
    unsigned long long searchResult;
    [tracker setMaxProgress:[haystack length]];
    searchResult = [haystack indexOfBytesEqualToBytes:needle inRange:range1 searchingForwards:forwards trackingProgress:tracker];
    if (searchResult == ULLONG_MAX) {
        searchResult = [haystack indexOfBytesEqualToBytes:needle inRange:range2 searchingForwards:forwards trackingProgress:tracker];
    }
    if (tracker->cancelRequested) return nil;
    else return [NSNumber numberWithUnsignedLongLong:searchResult];
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
        
        [needle incrementChangeLockCounter];
        [haystack incrementChangeLockCounter];
        
        [findReplaceView startOperation:^id(HFProgressTracker *tracker) {
            return [self threadedFindBytes:needle inBytes:haystack inRange1:searchRange1 range2:searchRange2 forwards:forwards trackingProgress:tracker];
        } completionHandler:^(id result) {
            unsigned long long searchResult = result ? [result unsignedLongLongValue] : ULLONG_MAX;
            if (searchResult == ULLONG_MAX) {
                /* nil result means cancelled; we don't want to beep in that case */
                if (result) NSBeep();
            } else {
                HFRange resultRange = HFRangeMake(searchResult, [needle length]);
                [controller setSelectedContentsRanges:[HFRangeWrapper withRanges:&resultRange count:1]];
                [controller maximizeVisibilityOfContentsRange:resultRange];
                [self restoreFirstResponderToSavedResponder];
                [controller pulseSelection];
            }
            [needle decrementChangeLockCounter];
            [haystack decrementChangeLockCounter];
        }];        
    }
}

- (id)threadedReplaceBytes:(HFByteArray *)needle inBytes:(HFByteArray *)haystack withBytes:(HFByteArray *)replacementValue trackingProgress:(HFProgressTracker *)tracker {
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
    USE(sender);
    if ([operationView operationIsRunning]) {
        NSBeep();
        return;
    }
    HFByteArray *needle = [[findReplaceView viewNamed:@"searchField"] objectValue];
    if ([needle length] == 0) {
        NSBeep();
        return;
    }
    HFByteArray *replacementValue = [[findReplaceView viewNamed:@"replaceField"] objectValue];
    HFASSERT(replacementValue != NULL);
    HFByteArray *haystack = [controller byteArray];
    
    [needle incrementChangeLockCounter];
    [haystack incrementChangeLockCounter];
    [replacementValue incrementChangeLockCounter];
    
    [findReplaceView startOperation:^id(HFProgressTracker *tracker) {
        return [self threadedReplaceBytes:needle inBytes:haystack withBytes:replacementValue trackingProgress:tracker];
    } completionHandler:^(id newByteArray) {
        [needle decrementChangeLockCounter];
        [haystack decrementChangeLockCounter];
        [replacementValue decrementChangeLockCounter];
        if (newByteArray != nil) {
            [controller replaceByteArray:newByteArray];
        }
    }];
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

/* This is called from the segmented control in the Find/Replace view */
- (IBAction)performFindReplaceActionFromSelectedSegment:(id)sender {
    const SEL actions[] = {@selector(replaceAll:), @selector(replace:), @selector(replaceAndFind:), @selector(findPrevious:), @selector(findNext:)};
    NSUInteger selection = [sender selectedSegment];
    if (selection < sizeof actions / sizeof *actions) {
        [self performSelector:actions[selection] withObject:sender];
    } else {
        NSBeep();
    }
}

- (void)showNavigationBannerSettingExtendSelectionCheckboxTo:(BOOL)extend {
    if (moveSelectionByView == operationView && moveSelectionByView != nil) {
        [[moveSelectionByView viewNamed:@"extendSelectionByCheckbox"] setIntValue:extend];
        [self saveFirstResponderIfNotInBannerAndThenSetItTo:[moveSelectionByView viewNamed:@"moveSelectionByTextField"]];
        return;
    }
    if (! moveSelectionByView) moveSelectionByView = [self newOperationViewForNibName:@"MoveSelectionByBanner" displayName:@"Moving Selection" fixedHeight:YES];
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
    if (! jumpToOffsetView) jumpToOffsetView = [self newOperationViewForNibName:@"JumpToOffsetBanner" displayName:@"Jumping to Offset" fixedHeight:YES];
    [self prepareBannerWithView:jumpToOffsetView withTargetFirstResponder:[jumpToOffsetView viewNamed:@"moveSelectionByTextField"]];
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
    unsigned isNegative;
    if (parseNumericStringWithSuffix([[jumpToOffsetView viewNamed:@"moveSelectionByTextField"] stringValue], &value, &isNegative)) {
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
    unsigned isNegative;
    if (parseNumericStringWithSuffix([[moveSelectionByView viewNamed:@"moveSelectionByTextField"] stringValue], &value, &isNegative)) {
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

- (void)populateBookmarksMenu:(NSMenu *)bookmarksMenu {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSUInteger itemCount = [bookmarksMenu numberOfItems];
    HFASSERT(itemCount >= 2); //we never delete the first two items
    
    /* Get a list of the bookmarks. */
    NSIndexSet *bookmarks = [controller bookmarksInRange:HFRangeMake(0, [controller contentsLength])];
    const NSUInteger numberOfBookmarks = [bookmarks count];
    
    /* Initial two items, plus maybe a separator, plus two bookmark items per bookmark */
    NSUInteger desiredItemCount = 2 + (numberOfBookmarks > 0) + 2 * numberOfBookmarks;
    
    /* Delete items until we get to the desired amount */
    while (itemCount > desiredItemCount) [bookmarksMenu removeItemAtIndex:--itemCount];
    
    /* Add items until we get to the new amount */
    while (itemCount < desiredItemCount) {
        if (itemCount == 2) {
            [bookmarksMenu insertItem:[NSMenuItem separatorItem] atIndex:itemCount];
        }
        else {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"" action:@selector(self) keyEquivalent:@""];
            [bookmarksMenu insertItem:item atIndex:itemCount];
            [item release];
        }
        itemCount++;
    }
    
    /* Update the items */
    NSUInteger itemIndex = 3, bookmarkIndex = 0; //0 is an invalid bookmark
    while (itemIndex < itemCount) {
        /* Get this bookmark index */
        bookmarkIndex = [bookmarks indexGreaterThanIndex:bookmarkIndex];
        
        /* Compute our KE */
        NSString *keString;
        if (bookmarkIndex <= 10) {
            char ke = '0' + (bookmarkIndex % 10);
            keString = [[NSString alloc] initWithBytes:&ke length:1 encoding:NSASCIIStringEncoding];	
        }
        else {
            keString = [@"" retain];
        }
        
        /* The first item is Select Bookmark, the second (alternate) is Scroll To Bookmark */
        
        NSMenuItem *item;
        
        item = [bookmarksMenu itemAtIndex:itemIndex++];
        [item setTitle:[NSString stringWithFormat:@"Select Bookmark %lu", bookmarkIndex]];
        [item setKeyEquivalent:keString];
        [item setAction:@selector(selectBookmark:)];
        [item setKeyEquivalentModifierMask:NSCommandKeyMask];
        [item setAlternate:NO];
        [item setTag:bookmarkIndex];
        
        item = [bookmarksMenu itemAtIndex:itemIndex++];
        [item setKeyEquivalent:keString];
        [item setAction:@selector(scrollToBookmark:)];
        [item setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask];
        [item setAlternate:YES];
        [item setTitle:[NSString stringWithFormat:@"Scroll to Bookmark %lu", bookmarkIndex]];
        [item setTag:bookmarkIndex];
        
        [keString release];
    }
    
    [pool drain];
    
    HFASSERT([bookmarksMenu numberOfItems] >= 2); //we never delete the first two items
}

- (IBAction)showFontPanel:(id)sender {
    NSFontPanel *panel = [NSFontPanel sharedFontPanel];
    [panel orderFront:sender];
    [panel setPanelFont:[self font] isMultiple:NO];
}

- (void)changeFont:(id)sender {
    [self setFont:[sender convertFont:[self font]] registeringUndo:YES];
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

- (IBAction)setOverwriteMode:sender {
    USE(sender);
    [controller setEditMode:HFOverwriteMode];
    [self updateDocumentWindowTitle];
}

- (IBAction)setInsertMode:sender {
    USE(sender);
    [controller setEditMode:HFInsertMode];
    [self updateDocumentWindowTitle];    
}

- (IBAction)setReadOnlyMode:sender {
    USE(sender);
    [controller setEditMode:HFReadOnlyMode];
    [self updateDocumentWindowTitle];    
}

- (void)jumpToBookmarkIndex:(NSInteger)bookmark selecting:(BOOL)select {
    if (controller) {
        HFRange range = [controller rangeForBookmark:bookmark];
        if (range.location != ULLONG_MAX || range.length != ULLONG_MAX) {
            [controller maximizeVisibilityOfContentsRange:range];
            if (select) [controller setSelectedContentsRanges:[HFRangeWrapper withRanges:&range count:1]];
        }
    }    
}

- (IBAction)scrollToBookmark:sender {
    [self jumpToBookmarkIndex:[sender tag] selecting:NO];
}

- (IBAction)selectBookmark:sender {
    [self jumpToBookmarkIndex:[sender tag] selecting:YES];
}

- (BOOL)canSetBookmark {
    /* We can set a bookmark unless we're at the end (or have no HFController) */
    BOOL result = NO;
    NSArray *ranges = [controller selectedContentsRanges];
    if ([ranges count] > 0) {
        HFRange range = [[ranges objectAtIndex:0] HFRange];
        result = (range.length != 0 || range.location < [controller contentsLength]);
    }
    return result;
}

- (IBAction)setBookmark:sender {
    USE(sender);
    if (! [self canSetBookmark]) {
        NSBeep();
        return;
    }
    NSArray *ranges = [controller selectedContentsRanges];
    if ([ranges count] > 0) {
        HFRange range = [[ranges objectAtIndex:0] HFRange];
        /* We always set a bookmark on at least one byte */
        range.length = MAX(range.length, 1);
        NSIndexSet *usedBookmarks = [controller bookmarksInRange:HFRangeMake(0, [controller contentsLength])];
        
        /* Find the first index that bookmarks does not contain, excepting 0 */
        NSMutableIndexSet *availableBookmarks = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(1, NSNotFound - 2)];
        [availableBookmarks removeIndexes:usedBookmarks];
        NSUInteger newBookmark = [availableBookmarks firstIndex];
        
        if (newBookmark != NSNotFound) {
            [controller setRange:range forBookmark:newBookmark];
        }
        [availableBookmarks release];
    }
}

- (IBAction)deleteBookmark:sender {
    USE(sender);
    NSInteger bookmark = [self selectedBookmark];
    if (bookmark != NSNotFound) {
        [controller setRange:HFRangeMake(ULLONG_MAX, ULLONG_MAX) forBookmark:bookmark];
    }
}

- (BOOL)isTransient {
    return isTransient;
}

- (void)setTransient:(BOOL)flag {
    isTransient = flag;
}

/* When we're changed we're no longer transient */
- (void)updateChangeCount:(NSDocumentChangeType)change {
    [self setTransient:NO];
    [super updateChangeCount:change];
}

- (BOOL)isTransientAndCanBeReplaced {
    BOOL result = NO;
    if ([self isTransient]) {
        NSWindowController *controllerWithSheet = nil;
        FOREACH(NSWindowController *, localController, [self windowControllers]) {
            if ([[localController window] attachedSheet]) {
                controllerWithSheet = localController;
                break;
            }
        }
        result = (controllerWithSheet == nil);
    }
    return result;
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
    NSMutableDictionary *hint = [userInfo objectForKey:HFChangeInFileHintKey];
    NSArray *modifiedRanges = [userInfo objectForKey:HFChangeInFileModifiedRangesKey];
    NSArray *allDocuments = [[[NSDocumentController sharedDocumentController] documents] copy]; //we copy this because we may need to close them
    
    /* Determine which document contains this byte array so we can make a nice dialog */
    BaseDataDocument *documentForThisByteArray = nil;
    FOREACH(BaseDataDocument *, testDocument, allDocuments) {
        if ([testDocument->controller byteArray] == byteArray) {
            documentForThisByteArray = testDocument;
            break;
        }
    }
    HFASSERT(documentForThisByteArray != nil); //for now we require that saving a ByteArray is associated with a document save
    
    FOREACH(BaseDataDocument *, document, allDocuments) {
        if (! [document isKindOfClass:[BaseDataDocument class]]) {
            /* Paranoia in case other NSDocument classes slip in */
            continue;
        }
        
        if (document == documentForThisByteArray) {
            /* Skip the document being saved.  We'll come back to it.  We want to process it last (and all we need to do with it is clean up its undo stack) */
            continue;
        }
        
        HFByteArray *itsArray = [document->controller byteArray];
        if (! [itsArray clearDependenciesOnRanges:modifiedRanges inFile:fileReference hint:hint]) {
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
        
        /* If we cancelled, we're done */
        if (*cancellationPointer) {
            NSLog(@"Cancelled!");
            break;
        } else {
            /* If we didn't cancel, clean up the undo stack as best we can */
            [document->controller clearUndoManagerDependenciesOnRanges:modifiedRanges inFile:fileReference hint:hint];
        }
    }
    
    /* Clean up the undo stack of the document being saved,unless we cancelled */
    if (! *cancellationPointer) [documentForThisByteArray->controller clearUndoManagerDependenciesOnRanges:modifiedRanges inFile:fileReference hint:hint];
    
    [allDocuments release];
}

- (BOOL)requiresOverwriteMode
{
    return NO;
}

@end
