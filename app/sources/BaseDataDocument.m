//
//  BaseDocument.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "BaseDataDocument.h"
#import "HFDocumentOperationView.h"
#import "DataInspectorRepresenter.h"
#import "TextDividerRepresenter.h"
#import "HFBinaryTemplateRepresenter.h"
#import "AppDebugging.h"
#import "AppUtilities.h"
#import "AppDelegate.h"
#import <HexFiend/HexFiend.h>
#import "HFPrompt.h"

static const char *const kProgressContext = "context";

NSString * const BaseDataDocumentDidChangeStringEncodingNotification = @"BaseDataDocumentDidChangeStringEncodingNotification";

enum {
    HFSaveSuccessful = 0,
    HFSaveCancelled,
    HFSaveError
};

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

@interface BaseDataDocument(LiveReloading)
- (void)pollLiveReload; //!< Queue up a live reload attempt. No actual polling involved.
- (BOOL)tryLiveReload;  //!< Attempt a live reload right now.
@end

@implementation BaseDataDocument
{
    BOOL _inLiveResize;
    HFRange _anchorRange;
    long double _startLineOffset;
    BOOL _resizeBinaryTemplate;
    NSRect _windowFrameBeforeResize;
    CGFloat _binaryTemplateWidthBeforeResize;
}

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

+ (CGFloat)binaryTemplateDefaultWidth {
    return 250;
}

/* Register the default-defaults for this class. */
+ (void)registerDefaultDefaults {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *err = nil;
        /* Defaults common to all subclasses */
        NSDictionary *defs = @{
            @"AntialiasText"   : @YES,
            @"ShowCallouts"    : @YES,
            @"HideNullBytes"   : @NO,
            @"DefaultFontName" : HFDEFAULT_FONT,
            @"DefaultFontSize" : @(HFDEFAULT_FONTSIZE),
            @"BytesPerColumn"  : @4,
            @"DefaultEditMode" : @(HFInsertMode),
            //@"BinaryTemplateSelectionColor" : [NSKeyedArchiver archivedDataWithRootObject:[NSColor lightGrayColor]],
            @"BinaryTemplateSelectionColor" : [NSKeyedArchiver archivedDataWithRootObject:[NSColor lightGrayColor] requiringSecureCoding:NO error:&err],
            @"BinaryTemplateRepresenterWidth" : @(self.class.binaryTemplateDefaultWidth),
            @"BinaryTemplateScriptTimeout" : @(10),
            @"BinaryTemplatesSingleClickAction" : @(1), // scroll to offset
            @"BinaryTemplatesDoubleClickAction" : @(0), // do nothing
            @"BinaryTemplatesAutoCollapseValuedSections" : @NO,
            @"ResolveAliases": @YES,
        };
        [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
    });
    
    static NSMutableArray *sRegisteredDefaultsByIdentifier = nil;
    NSString *ident = [self layoutUserDefaultIdentifier];
    if (ident && ! [sRegisteredDefaultsByIdentifier containsObject:ident]) {
        /* Register defaults for this identifier */
        if (! sRegisteredDefaultsByIdentifier) sRegisteredDefaultsByIdentifier = [[NSMutableArray alloc] init];
        [sRegisteredDefaultsByIdentifier addObject:ident];
        
        NSDictionary *defs = @{
            USERDEFS_KEY_FOR_REP(columnRepresenter) : @NO,
            USERDEFS_KEY_FOR_REP(lineCountingRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(binaryRepresenter) : @NO,
            USERDEFS_KEY_FOR_REP(hexRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(asciiRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(dataInspectorRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(statusBarRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(scrollRepresenter) : @YES,
        };
        [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
    }
}

+ (void)initialize {
    if (self == [BaseDataDocument class]) {
        NSDictionary *defs = @{
            @"AntialiasText" : @YES,
            @"ShowCallouts" : @YES,
            @"HideNullBytes" : @NO,
            @"DefaultFontName" : HFDEFAULT_FONT,
            @"DefaultFontSize" : @(HFDEFAULT_FONTSIZE),
            @"BytesPerColumn" : @4,
            @"LineNumberFormat" : @0,
            USERDEFS_KEY_FOR_REP(columnRepresenter) : @NO,
            USERDEFS_KEY_FOR_REP(lineCountingRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(binaryRepresenter) : @NO,
            USERDEFS_KEY_FOR_REP(hexRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(asciiRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(dataInspectorRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(statusBarRepresenter) : @YES,
            USERDEFS_KEY_FOR_REP(scrollRepresenter) : @YES,
#if ! NDEBUG
            @"NSApplicationShowExceptions" : @YES,
#endif
        };
        [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
        
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
    return [windowControllers[0] window];
}

- (NSArray *)representers {
    return @[
        lineCountingRepresenter,
        binaryRepresenter,
        hexRepresenter,
        asciiRepresenter,
        scrollRepresenter,
        dataInspectorRepresenter,
        statusBarRepresenter,
        textDividerRepresenter,
        binaryTemplateRepresenter,
        columnRepresenter,
    ];
}

- (HFByteArray *)byteArray {
    return [controller byteArray];
}

- (BOOL)representerIsShown:(HFRepresenter *)representer {
    NSParameterAssert(representer);
    return [layoutRepresenter.representers containsObject:representer];
}

- (void)showViewForRepresenter:(HFRepresenter *)rep {
    HFASSERT([[rep view] superview] == nil && [[rep view] window] == nil);
    if (rep == statusBarRepresenter) {
        NSView *view = rep.view;
        [self.window setContentBorderThickness:view.frame.size.height forEdge:NSRectEdgeMinY];
        [self.window setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    }
    [controller addRepresenter:rep];
    [layoutRepresenter addRepresenter:rep];
}

- (void)hideViewForRepresenter:(HFRepresenter *)rep {
    HFASSERT(rep != NULL);
    HFASSERT([layoutRepresenter.representers indexOfObjectIdenticalTo:rep] != NSNotFound);
    if (rep == statusBarRepresenter) {
        [self.window setContentBorderThickness:0 forEdge:NSRectEdgeMinY];
        [self.window setAutorecalculatesContentBorderThickness:NO forEdge:NSMinYEdge];
    }
    [controller removeRepresenter:rep];
    [layoutRepresenter removeRepresenter:rep];
}

- (BOOL)dividerRepresenterShouldBeShown {
    return ([self representerIsShown:binaryRepresenter] || [self representerIsShown:hexRepresenter]) && [self representerIsShown:asciiRepresenter];
}

/* Called to show or hide the divider representer. This should be shown when both our text representers are visible */
- (void)showOrHideDividerRepresenter {
    BOOL dividerRepresenterShouldBeShown = [self dividerRepresenterShouldBeShown];
    BOOL dividerRepresenterIsShown = [self representerIsShown:textDividerRepresenter];
    if (dividerRepresenterShouldBeShown && ! dividerRepresenterIsShown) {
        [self showViewForRepresenter:textDividerRepresenter];
    } else if (! dividerRepresenterShouldBeShown && dividerRepresenterIsShown) {
        [self hideViewForRepresenter:textDividerRepresenter];
    }
}

/* Code to save to user defs (NO) or apply from user defs (YES) the default representers to show. */
- (void)saveOrApplyDefaultRepresentersToDisplay:(BOOL)isApplying {
    NSMapTable *shownRepresentersData = [NSMapTable strongToWeakObjectsMapTable];
    [shownRepresentersData setObject:columnRepresenter
        forKey:USERDEFS_KEY_FOR_REP(columnRepresenter)];
    [shownRepresentersData setObject:lineCountingRepresenter forKey:USERDEFS_KEY_FOR_REP(lineCountingRepresenter)];
    [shownRepresentersData setObject:binaryRepresenter forKey:USERDEFS_KEY_FOR_REP(binaryRepresenter)];
    [shownRepresentersData setObject:hexRepresenter forKey:USERDEFS_KEY_FOR_REP(hexRepresenter)];
    [shownRepresentersData setObject:asciiRepresenter forKey:USERDEFS_KEY_FOR_REP(asciiRepresenter)];
    [shownRepresentersData setObject:dataInspectorRepresenter forKey:USERDEFS_KEY_FOR_REP(dataInspectorRepresenter)];
    [shownRepresentersData setObject:statusBarRepresenter forKey:USERDEFS_KEY_FOR_REP(statusBarRepresenter)];
    [shownRepresentersData setObject:scrollRepresenter forKey:USERDEFS_KEY_FOR_REP(scrollRepresenter)];
    [shownRepresentersData setObject:binaryTemplateRepresenter forKey:USERDEFS_KEY_FOR_REP(binaryTemplateRepresenter)];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSEnumerator *keysEnum = [shownRepresentersData keyEnumerator];
    NSString *name = nil;
    while (name = [keysEnum nextObject]) {
        HFRepresenter *rep = [shownRepresentersData objectForKey:name];
        if (isApplying) {
            /* Read from user defaults */
            NSNumber *boolObject = [defs objectForKey:name];
            if (boolObject != nil) {
                BOOL shouldShow = [boolObject boolValue];
                if (shouldShow != [self representerIsShown:rep]) {
                    if (shouldShow) [self showViewForRepresenter:rep];
                    else [self hideViewForRepresenter:rep];
                }
            }
        }
        else {
            /* Save to user defaults */
            BOOL isShown = [self representerIsShown:rep];
            [defs setBool:isShown forKey:name];
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
    default:
        HFASSERT(0); // this shouldn't happen
        break;
    }

    BOOL hasAppendedProgressMarker = NO;
    NSArray *runningViews = [self runningOperationViews];
    for(HFDocumentOperationView *view in runningViews) {
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
        }
    }
}

- (NSSize)minimumWindowFrameSizeForProposedSize:(NSSize)frameSize {
    // If the command key was held down at the start of the window resize, and the binary templates
    // are visible, only resize the binary templates view. Otherwise, resize the layout.
    if (_resizeBinaryTemplate) {
        const CGFloat widthDiff = frameSize.width - _windowFrameBeforeResize.size.width;
        const CGFloat minBinaryTemplateWidth = self.class.binaryTemplateDefaultWidth;
        const CGFloat minFrameWidth = (_windowFrameBeforeResize.size.width - _binaryTemplateWidthBeforeResize) + minBinaryTemplateWidth;
        CGFloat binaryTemplateWidth = _binaryTemplateWidthBeforeResize + widthDiff;
        NSSize resultSize = frameSize;
        if (binaryTemplateWidth < minBinaryTemplateWidth) {
            binaryTemplateWidth = minBinaryTemplateWidth;
            resultSize.width = minFrameWidth;
        }
        binaryTemplateRepresenter.viewWidth = binaryTemplateWidth;
        return resultSize;
    }
    NSView *layoutView = [layoutRepresenter view];
    NSSize proposedSizeInLayoutCoordinates = [layoutView convertSize:frameSize fromView:nil];
    CGFloat resultingWidthInLayoutCoordinates = [layoutRepresenter minimumViewWidthForLayoutInProposedWidth:proposedSizeInLayoutCoordinates.width];
    NSSize resultSize = [layoutView convertSize:NSMakeSize(resultingWidthInLayoutCoordinates, proposedSizeInLayoutCoordinates.height) toView:nil];
    return resultSize;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
    USE(sender);
    if (layoutRepresenter == nil) return frameSize;
    if (@available(macOS 10.12, *)) {
        NSSize size = NSZeroSize;
        NSArray *windows = self.window.tabbedWindows.count ? self.window.tabbedWindows : @[self.window];
        for (NSWindow *window in windows) {
            NSSize windowSize = [window.windowController.document minimumWindowFrameSizeForProposedSize:frameSize];
            size = NSMakeSize(MAX(size.width, windowSize.width), MAX(size.height, windowSize.height));
        }
        return size;
    }
    return [self minimumWindowFrameSizeForProposedSize:frameSize];
}

- (void)windowDidResize:(NSNotification * __unused)notification
{
    [self saveWindowState];
    [self scrollToAnchoredOffset];
}

- (void)windowDidMove:(NSNotification * __unused)notification
{
    [self saveWindowState];
}

- (void)windowWillStartLiveResize:(NSNotification * __unused)notification {
    const BOOL isOptionKeyDown = (self.window.currentEvent.modifierFlags & NSEventModifierFlagCommand) != 0;
    _resizeBinaryTemplate = isOptionKeyDown && [NSUserDefaults.standardUserDefaults boolForKey:USERDEFS_KEY_FOR_REP(binaryTemplateRepresenter)];
    _windowFrameBeforeResize = self.window.frame;
    _binaryTemplateWidthBeforeResize = binaryTemplateRepresenter.viewWidth;
    _inLiveResize = YES;
    [self updateScrollAnchorOffset];
}

- (void)windowDidEndLiveResize:(NSNotification *__unused)notification {
    if (_resizeBinaryTemplate) {
        [NSUserDefaults.standardUserDefaults setDouble:binaryTemplateRepresenter.viewWidth forKey:@"BinaryTemplateRepresenterWidth"];
        _resizeBinaryTemplate = NO;
    }
    _inLiveResize = NO;
}

- (void)updateScrollAnchorOffset {
    const HFFPRange displayedLineRange = controller.displayedLineRange;
    const HFRange selectionRange = ((HFRangeWrapper *)controller.selectedContentsRanges[0]).HFRange;
    const HFFPRange selectionFPRange = HFFPRangeMake([controller lineForRange:selectionRange], 1);
    if (HFFPIntersectsRange(selectionFPRange, displayedLineRange)) {
        _anchorRange = selectionRange;
    } else {
        // Selection is not visible, so anchor on the first fully visible line's first byte
        const unsigned long long loc = (unsigned long long)ceill(displayedLineRange.location) * controller.bytesPerLine;
        _anchorRange = HFRangeMake(loc, 0);
    }
    const unsigned long long startLine = [controller lineForRange:_anchorRange];
    _startLineOffset = startLine - displayedLineRange.location;
}

- (void)scrollToAnchoredOffset {
    if (!_inLiveResize) {
        return;
    }
    HFFPRange displayedLineRange = controller.displayedLineRange;
    const unsigned long long startLine = [controller lineForRange:_anchorRange];
    displayedLineRange.location = startLine - _startLineOffset;
    [controller adjustDisplayRangeAsNeeded:&displayedLineRange];
    controller.displayedLineRange = displayedLineRange;
}

- (void)saveWindowState
{
    if (loadingWindow) {
        return;
    }
    NSInteger bpl = [controller bytesPerLine];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setInteger:bpl forKey:@"BytesPerLine"];
    const NSRect frame = [[self window] frame];
    [ud setDouble:frame.size.height forKey:@"WindowHeight"];
    [ud setObject:NSStringFromPoint(frame.origin) forKey:@"WindowOrigin"];
}

/* Relayout the window, optionally changing its size based on the representer */
- (void)relayoutAndResizeWindowForRepresenter:(HFRepresenter *)rep {
    NSWindow *window = [self window];
    NSRect windowFrame = [window frame];
    // hack: expand the window width by the rep's view width for some reps
    if (rep && ([rep isKindOfClass:[HFBinaryTemplateRepresenter class]] || [rep isKindOfClass:[HFLineCountingRepresenter class]])) {
        NSView *view = rep.view;
        CGFloat minWidth = view.frame.size.width;
        if (view.window) {
            windowFrame.size.width += minWidth;
        } else {
            windowFrame.size.width -= minWidth;
        }
    }
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

/* Shared point for setting up a window, optionally setting a bytes per line */
- (void)setupWindowEnforcingBytesPerLine:(NSUInteger)bplOrZero {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    loadingWindow = YES;

    layoutRepresenter = [[HFLayoutRepresenter alloc] init];
    [controller addRepresenter:layoutRepresenter];
    
    NSView *layoutView = [layoutRepresenter view];
    [layoutView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    if (containerView) {
        [layoutView setFrame:[containerView bounds]];
        [containerView addSubview:layoutView];
    }
    [self applyDefaultRepresentersToDisplay];
    
    if (bplOrZero > 0) {
        /* Here we probably get larger */
        [self relayoutAndResizeWindowForBytesPerLine:bplOrZero];
    } else {
        /* Here we probably get smaller */
        NSNumber *bpl = [ud objectForKey:@"BytesPerLine"];
        if (!bpl || ![bpl isKindOfClass:[NSNumber class]]) {
            [self relayoutAndResizeWindowForRepresenter:nil];
        } else {
            [self relayoutAndResizeWindowForBytesPerLine:bpl.integerValue];
        }
    }

    if ([ud objectForKey:@"WindowOrigin"] && [ud objectForKey:@"WindowHeight"]) {
        NSRect frame = [[self window] frame];
        frame.origin = NSPointFromString([ud objectForKey:@"WindowOrigin"]);
        frame.size.height = [ud doubleForKey:@"WindowHeight"];
        [[self window] setFrame:frame display:YES];
    }

    loadingWindow = NO;
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
    
    /* Find the container view */
    NSView *contentView = [window contentView];
    containerView = contentView;
    
    /* Remove all of its subviews */
    contentView.subviews = @[];

    /* Set up the window */
    [self setupWindowEnforcingBytesPerLine:oldBPL];
}

/* When our line counting view needs more space, we increase the size of our window, and also move it left by the same amount so that the other content does not appear to move. */
- (void)lineCountingViewChangedWidth:(NSNotification *)note {
    USE(note);
    HFASSERT([note object] == lineCountingRepresenter);
    NSView *lineCountingView = [lineCountingRepresenter view];
    
    CGFloat newWidth = [lineCountingRepresenter preferredWidth];
    
    // Always update column representer
    [columnRepresenter setLineCountingWidth:newWidth];

    /* Don't do anything window changing if we're not in a window yet */
    NSWindow *lineCountingViewWindow = [lineCountingView window];
    if (! lineCountingViewWindow) return;
    
    HFASSERT(lineCountingViewWindow == [self window]);
    
    CGFloat currentWidth = NSWidth([lineCountingView frame]);
    if (newWidth != currentWidth) {
        CGFloat widthChange = newWidth - currentWidth; //if we shrink, widthChange will be negative
        CGFloat windowWidthChange = [[lineCountingView superview] convertSize:NSMakeSize(widthChange, 0) toView:nil].width;
        windowWidthChange = (windowWidthChange < 0 ? HFFloor(windowWidthChange) : HFCeil(windowWidthChange));
        
        /* convertSize: has a nasty habit of stomping on negatives.  Make our window width change negative if our view-space horizontal change was negative. */
#if CGFLOAT_IS_DOUBLE
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

- (void)columnRepresenterViewHeightChanged:(NSNotification *)note {
    USE(note);
    HFASSERT([note object] == columnRepresenter);

    NSView *columnView = [columnRepresenter view];
    
    /* Don't do anything window changing if we're not in a window yet */
    NSWindow *columnViewWindow = [columnView window];
    if (!columnViewWindow) {
        return;
    }
    
    CGFloat newHeight = [columnRepresenter preferredHeight];
    
    HFASSERT(columnViewWindow == [self window]);
    
    CGFloat currentHeight = columnView.frame.size.height;
    if (newHeight != currentHeight) {
        CGFloat heightChange = newHeight - currentHeight; //if we shrink, heightChange will be negative
        CGFloat windowHeightChange = [columnView.superview convertSize:NSMakeSize(0, heightChange) toView:nil].height;
        windowHeightChange = (windowHeightChange < 0 ? HFFloor(windowHeightChange) : HFCeil(windowHeightChange));
        
        /* convertSize: has a nasty habit of stomping on negatives.  Make our window height change negative if our view-space vertical change was negative. */
#if CGFLOAT_IS_DOUBLE
        windowHeightChange = copysign(windowHeightChange, heightChange);
#else
        windowHeightChange = copysignf(windowHeightChange, heightChange);
#endif
        
        NSRect windowFrame = columnViewWindow.frame;
        windowFrame.size.height += windowHeightChange;
        
        /* If we are not setting the font, we want to grow the window top, so that the content area is preserved.  If we are setting the font, grow the window bottom. */
        if (!currentlySettingFont) {
            windowFrame.origin.y -= windowHeightChange;
        }
        [columnViewWindow setFrame:windowFrame display:YES animate:NO];
    }
}

- (void)lineCountingRepCycledLineNumberFormat:(NSNotification*)note {
    USE(note);
    [self saveLineNumberFormat];
}

- (void)dataInspectorDeletedAllRows:(NSNotification *)note {
    DataInspectorRepresenter *inspector = [note object];
    [self hideViewForRepresenter:inspector];
    [self saveDefaultRepresentersToDisplay]; // Save the representers in UserDefaults so we start out next time the same way
}

/* Called when our data inspector changes its size (number of rows) */
- (void)dataInspectorChangedRowCount:(NSNotification *)note {
    DataInspectorRepresenter *inspector = [note object];
    CGFloat newHeight = (CGFloat)[[note userInfo][@"height"] doubleValue];
    NSView *dataInspectorView = [inspector view];
    NSSize size = [dataInspectorView frame].size;
    size.height = newHeight;
    [dataInspectorView setFrameSize:size];
    [layoutRepresenter performLayout];
}

- (instancetype)init {
    self = [super init];
    
    /* Make sure we register our defaults for this class */
    [[self class] registerDefaultDefaults];
    
    columnRepresenter = [[HFColumnRepresenter alloc] init];
    lineCountingRepresenter = [[HFLineCountingRepresenter alloc] init];
    binaryRepresenter = [[HFBinaryTextRepresenter alloc] init];
    hexRepresenter = [[HFHexTextRepresenter alloc] init];
    asciiRepresenter = [[HFStringEncodingTextRepresenter alloc] init];
    scrollRepresenter = [[HFVerticalScrollerRepresenter alloc] init];
    statusBarRepresenter = [[HFStatusBarRepresenter alloc] init];
    dataInspectorRepresenter = [[DataInspectorRepresenter alloc] init];
    textDividerRepresenter = [[TextDividerRepresenter alloc] init];
    binaryTemplateRepresenter = [[HFBinaryTemplateRepresenter alloc] init];
    binaryTemplateRepresenter.viewWidth = [NSUserDefaults.standardUserDefaults doubleForKey:@"BinaryTemplateRepresenterWidth"];

    /* We will create layoutRepresenter when the window is actually shown
     * so that it will never exist in an inconsistent state */
    
    [(NSView *)[binaryRepresenter view] setAutoresizingMask:NSViewHeightSizable];
    [(NSView *)[hexRepresenter view] setAutoresizingMask:NSViewHeightSizable];
    [(NSView *)[asciiRepresenter view] setAutoresizingMask:NSViewHeightSizable];
    [(NSView *)[lineCountingRepresenter view] setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(lineCountingViewChangedWidth:) name:HFLineCountingRepresenterMinimumViewWidthChanged object:lineCountingRepresenter];
    [center addObserver:self selector:@selector(columnRepresenterViewHeightChanged:) name:HFColumnRepresenterViewHeightChanged object:columnRepresenter];
    [center addObserver:self selector:@selector(lineCountingRepCycledLineNumberFormat:) name:HFLineCountingRepresenterCycledLineNumberFormat object:lineCountingRepresenter];
    [center addObserver:self selector:@selector(dataInspectorChangedRowCount:) name:DataInspectorDidChangeRowCount object:dataInspectorRepresenter];
    [center addObserver:self selector:@selector(dataInspectorDeletedAllRows:) name:DataInspectorDidDeleteAllRows object:dataInspectorRepresenter];

    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    
    lineCountingRepresenter.lineNumberFormat = (HFLineNumberFormat)[defs integerForKey:@"LineNumberFormat"];

    [columnRepresenter setLineCountingWidth:lineCountingRepresenter.preferredWidth];
    
    controller = [[HFController alloc] init];
    [controller setShouldAntialias:[defs boolForKey:@"AntialiasText"]];
    [controller setShouldColorBytes:[defs boolForKey:@"ColorBytes"]];
    [controller setShouldShowCallouts:[defs boolForKey:@"ShowCallouts"]];
    [controller setShouldHideNullBytes:[defs boolForKey:@"HideNullBytes"]];
    [controller setShouldLiveReload:[defs boolForKey:@"LiveReload"]];
    [controller setUndoManager:[self undoManager]];
    [controller setBytesPerColumn:[defs integerForKey:@"BytesPerColumn"]];
    
    [self setShouldLiveReload:[controller shouldLiveReload]];
    
    NSString *fontName = [defs stringForKey:@"DefaultFontName"];
    CGFloat fontSize = [defs floatForKey:@"DefaultFontSize"];
    NSFont *font = [NSFont fontWithName:fontName size:fontSize];
    if (font != nil) {
        [controller setFont: font];
    }
    
    [self setStringEncoding:[(AppDelegate *)NSApp.delegate defaultStringEncoding]];
    
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
    
    /* Release and stop observing our banner views.  Note that any of these may be nil. */
    HFDocumentOperationView *views[] = {findReplaceView, moveSelectionByView, jumpToOffsetView, saveView};
    for (NSUInteger i = 0; i < sizeof views / sizeof *views; i++) {
        [views[i] removeObserver:self forKeyPath:@"progress"];
    }
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
    HFDocumentOperationView *result = [HFDocumentOperationView viewWithNibNamed:name owner:self];
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
    NSRect containerBounds = [containerView bounds];
    if (! bannerView) {
        NSRect bannerFrame = NSMakeRect(NSMinX(containerBounds), NSMaxY(containerBounds), NSWidth(containerBounds), 0);
        bannerView = [[NSView alloc] initWithFrame:bannerFrame];
    }
    bannerView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    bannerStartTime = 0;
    bannerIsShown = YES;
    bannerGrowing = YES;
    targetFirstResponderInBanner = targetFirstResponder;
    
    if (newSubview) {
        NSSize newSubviewSize = [newSubview frame].size;
        if (newSubviewSize.width != NSWidth(containerBounds)) {
            newSubviewSize.width = NSWidth(containerBounds);
            [newSubview setFrameSize:newSubviewSize];
        }
        [bannerView addSubview:newSubview];
    }
    [bannerResizeTimer invalidate];
    bannerResizeTimer = [NSTimer scheduledTimerWithTimeInterval:1. / 60. target:self selector:@selector(animateBanner:) userInfo:nil repeats:YES];
    [self updateDocumentWindowTitle];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender {
    NSArray *files = [sender.draggingPasteboard propertyListForType:NSPasteboardTypeFileURL];
    for(NSString *filename in files) {
        NSURL *fileURL = [NSURL fileURLWithPath:filename];
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES completionHandler:^(NSDocument * _Nullable __unused document, BOOL __unused documentWasAlreadyOpen, NSError * _Nullable __unused error) {
        }];
    }
    return YES;
}

+ (HFByteArray *)byteArrayfromURL:(NSURL *)absoluteURL error:(NSError **)outError {
    HFASSERT([absoluteURL isFileURL]);
    HFFileReference *fileReference = [[HFFileReference alloc] initWithPath:[absoluteURL path] error:outError];
    if (!fileReference) {
        return nil;
    }
    HFFileByteSlice *byteSlice = [[HFFileByteSlice alloc] initWithFile:fileReference];
    HFByteArray *byteArray = [[preferredByteArrayClass() alloc] init];
    [byteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
    return byteArray;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError {
    USE(typeName);
    USE(outError);
    BOOL result = NO;
    HFByteArray *byteArray = [[self class] byteArrayfromURL:absoluteURL error:outError];
    if (byteArray) {
        [controller setByteArray:byteArray];
        cleanGenerationCount = [byteArray changeGenerationCount];
        result = YES;
    }
    return result;
}

- (IBAction)toggleVisibleControllerView:(id)sender {
    USE(sender);
    NSUInteger arrayIndex = [sender tag] - 1;
    NSArray *representers = self.representers;
    if (arrayIndex >= [representers count]) {
        NSBeep();
    }
    else {
        HFRepresenter *rep = representers[arrayIndex];
        BOOL isLineCounting = [rep isKindOfClass:[HFLineCountingRepresenter class]];
        if ([self representerIsShown:rep]) {
            [self hideViewForRepresenter:rep];
            [self showOrHideDividerRepresenter];
            [self relayoutAndResizeWindowForRepresenter:rep];
            if (isLineCounting) {
                [columnRepresenter setLineCountingWidth:0];
            }
        }
        else {
            [self showViewForRepresenter:rep];
            [self showOrHideDividerRepresenter];
            [self relayoutAndResizeWindowForRepresenter:rep];
            if (isLineCounting) {
                [columnRepresenter setLineCountingWidth:((NSView *)lineCountingRepresenter.view).frame.size.width];
            }
        }
        [self saveDefaultRepresentersToDisplay];
    }
}

- (void)setFont:(NSFont *)font registeringUndo:(BOOL)undo {
    HFASSERT(font != nil);
    
//    TODO: Figure out how to use undo manager without dirtying document
    USE(undo);

    NSWindow *window = [self window];
    NSUInteger bytesPerLine = [controller bytesPerLine];
    /* Record that we are currently setting the font.  We use this to decide which direction to grow the window if our line numbers change. */
    currentlySettingFont = YES;
    [controller setFont:font];
    [self relayoutAndResizeWindowForBytesPerLine:bytesPerLine];
    currentlySettingFont = NO;
    [window display];
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    [defs setDouble:[font pointSize] forKey:@"DefaultFontSize"];
    [defs setObject:[font fontName] forKey:@"DefaultFontName"];
}

- (void)setFont:(NSFont *)val {
    [self setFont:val registeringUndo:NO];
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

- (HFStringEncoding *)stringEncoding {
    return [(HFStringEncodingTextRepresenter *)asciiRepresenter encoding];
}

- (void)setStringEncoding:(HFStringEncoding *)encoding {
    NSUInteger bytesPerLine = [controller bytesPerLine];
    [(HFStringEncodingTextRepresenter *)asciiRepresenter setEncoding:encoding];
    if ([[self windowControllers] count] > 0) {
        [self relayoutAndResizeWindowForBytesPerLine:bytesPerLine];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:BaseDataDocumentDidChangeStringEncodingNotification object:self userInfo:nil];
}

- (void)setStringEncodingFromMenuItem:(NSMenuItem *)item {
    [self setStringEncoding:item.representedObject];
    
    /* Call to the delegate so it sets the default */
    [(AppDelegate*)[NSApp delegate] setStringEncodingFromMenuItem:item];
}


- (IBAction)setAntialiasFromMenuItem:(id)sender {
    USE(sender);
    BOOL newVal = ! [controller shouldAntialias];
    [controller setShouldAntialias:newVal];
    [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"AntialiasText"];
}

- (IBAction)setShowCalloutsFromMenuItem:(id)sender {
    USE(sender);
    BOOL newVal = ! [controller shouldShowCallouts];
    [controller setShouldShowCallouts:newVal];
    [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"ShowCallouts"];
}

- (IBAction)setShowNullBytesFromMenuItem:(id)sender {
    USE(sender);
    BOOL newVal = ! [controller shouldHideNullBytes];
    [controller setShouldHideNullBytes:newVal];
    [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"HideNullBytes"];
}


- (IBAction)setColorBytesFromMenuItem:(id)sender {
    USE(sender);
    BOOL newVal = ! [controller shouldColorBytes];
    [controller setShouldColorBytes:newVal];
    [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"ColorBytes"];
}


/* Returns the selected bookmark, or NSNotFound. If more than one bookmark is selected, returns the largest. */
- (NSInteger)selectedBookmark {
    NSInteger result = NSNotFound;
    NSArray *ranges = [controller selectedContentsRanges];
    if ([ranges count] > 0) {
        HFRange range = [ranges[0] HFRange];
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
        NSArray *representers = self.representers;
        if (arrayIndex >= [representers count]) {
            return NO;
        }
        else {
            HFRepresenter *rep = representers[arrayIndex];
            [item setState:[controller.representers containsObject:rep]];
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
    else if (action == @selector(setColorBytesFromMenuItem:)) {
        [item setState:[controller shouldColorBytes]];
        return YES;
    }
    else if (action == @selector(setShowCalloutsFromMenuItem:)) {
        [item setState:[controller shouldShowCallouts]];
        return YES;
    }
    else if (action == @selector(setShowNullBytesFromMenuItem:)) {
        [item setState:[controller shouldHideNullBytes]];
        return YES;
    }
    else if (action == @selector(setLiveReloadFromMenuItem:)) {
        [item setState:[controller shouldLiveReload]];
        return YES;
    }
    else if (action == @selector(setOverwriteMode:)) {
        [item setState:[controller editMode] == HFOverwriteMode];
        /* We can toggle overwrite mode only if the controller doesn't require that it be on */
        return controller.savable;
    }
    else if (action == @selector(setInsertMode:)) {
        [item setState:[controller editMode] == HFInsertMode];
        return controller.savable && ![self requiresOverwriteMode];
    }
    else if (action == @selector(setReadOnlyMode:)) {
        [item setState:[controller editMode] == HFReadOnlyMode];
        return controller.savable;
    }
    else if (action == @selector(modifyByteGrouping:)) {
        [item setState:(NSUInteger)[item tag] == [controller bytesPerColumn]];
        return YES;
    }
    else if (action == @selector(setLineNumberFormat:)) {
        item.state = item.tag == (NSInteger)lineCountingRepresenter.lineNumberFormat ? NSControlStateValueOn : NSControlStateValueOff;
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
        [operationView removeFromSuperview];
        [bannerView removeFromSuperview];
        [[[bannerView subviews] copy] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        bannerView = nil;
        operationView = nil;
        [self updateDocumentWindowTitle];
        [containerView setNeedsDisplay:YES];
        if (commandToRunAfterBannerIsDoneHiding) {
            dispatch_block_t command = commandToRunAfterBannerIsDoneHiding;
            commandToRunAfterBannerIsDoneHiding = NULL;
            command();
        }
    } else if (commandToRunAfterBannerPrepared) {
        commandToRunAfterBannerPrepared();
        commandToRunAfterBannerPrepared = nil;
    }
}

- (void)restoreFirstResponderToSavedResponder {
    NSWindow *window = [self window];
    NSMutableArray *views = [NSMutableArray array];
    for(HFRepresenter *rep in self.representers) {
        NSView *view = [rep view];
        if ([view window] == window) {
            /* If we're the saved first responder, try it first */
            if (view == savedFirstResponder) [views insertObject:view atIndex:0];
            else [views addObject:view];
        }
    }
    
    /* Try each view we identified */
    for(NSView *view in views) {
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
    NSView *bannerRelativeView = [self bannerAssociateView];
    if (bannerGrowing && diff >= 0 && [bannerView superview] != containerView) {
        NSAssert([bannerRelativeView superview] == containerView, @"oops");
        [containerView addSubview:bannerView positioned:NSWindowBelow relativeTo:bannerRelativeView];
        if (targetFirstResponderInBanner) {
            NSWindow *window = [self window];
            savedFirstResponder = [window firstResponder];
            [window makeFirstResponder:targetFirstResponderInBanner];
        }
    }
    CGFloat height = (CGFloat)round(bannerTargetHeight * amount);
    NSRect bannerFrame = [bannerView frame];
    bannerFrame.size.height = height;
    bannerFrame.origin.y = NSMaxY(containerView.frame) - height;
    [bannerView setFrame:bannerFrame];
    NSRect layoutFrame = bannerRelativeView.frame;
    layoutFrame.size.height = containerView.frame.size.height - height;
    bannerRelativeView.frame = layoutFrame;

    if (isFirstCall) {
        /* The first display can take some time, which can cause jerky animation; so we start the animation after it */
        bannerStartTime = CFAbsoluteTimeGetCurrent();
    }
    if ((bannerGrowing && amount >= 1.) || (!bannerGrowing && amount <= 0.)) {
        if (timer == bannerResizeTimer && bannerResizeTimer != nil) {
            [bannerResizeTimer invalidate];
            bannerResizeTimer = nil;
        }
        [self finishedAnimation];
    }
}

- (NSView *)bannerAssociateView
{
    return [layoutRepresenter view];
}

- (BOOL)canSwitchToNewBanner {
    return operationView == nil || operationView != saveView;
}

- (void)hideBannerFirstThenDo:(dispatch_block_t)command {
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
    bannerResizeTimer = [NSTimer scheduledTimerWithTimeInterval:1. / 60. target:self selector:@selector(animateBanner:) userInfo:nil repeats:YES];
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
        @autoreleasepool {
        [self animateBanner:nil];
        [window displayIfNeeded];
        }
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
    
    showSaveViewAfterDelayTimer = [NSTimer scheduledTimerWithTimeInterval:.5 target:self selector:@selector(showSaveBannerHavingDelayed:) userInfo:nil repeats:NO];
    
    if (! saveView) saveView = [self newOperationViewForNibName:@"SaveBanner" displayName:@"Saving"];
    
    [[controller byteArray] incrementChangeLockCounter];
    
    [(NSTextField*)[saveView viewNamed:@"saveLabelField"] setStringValue:[NSString stringWithFormat:@"Saving \"%@\"", [self displayName]]];

    __block NSInteger saveResult = 0;
    __block NSError *operationError = nil;
    [saveView startOperation:^id(HFProgressTracker *tracker) {
        id result = [self threadedSaveToURL:inAbsoluteURL trackingProgress:tracker error:&operationError];
        return result;
    } completionHandler:^(id result) {
        saveResult = [result integerValue];
        
        /* Post an event so our event loop wakes up */
        [NSApp postEvent:[NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:NULL subtype:0 data1:0 data2:0] atStart:NO];
    }];

    if (operationError && outError) {
        *outError = operationError;
    }

    while ([saveView operationIsRunning]) {
        @autoreleasepool {
            @try {  
                NSEvent *event = [NSApp nextEventMatchingMask:NSUIntegerMax untilDate:[NSDate distantFuture] inMode:NSDefaultRunLoopMode dequeue:YES];
                if (event) [NSApp sendEvent:event];
            }
            @catch (NSException *localException) {
                NSLog(@"Exception thrown during save: %@", localException);
            }
        }
    }

    [showSaveViewAfterDelayTimer invalidate];
    showSaveViewAfterDelayTimer = nil;
    
    [[controller byteArray] decrementChangeLockCounter];
    
    /* If we save to a file, then we've probably overwritten some source data, so just reset the document to reference the new file.  Only do this if there was no error.
     
     Note that this is actually quite wrong.  It's entirely possible that e.g. there was an error after the file was touched, e.g. when writing to the file.  In that case, we do want to just reference the file again.
     
     TODO:
 What we really need to know is "has a backing file been touched by this operation."  But we don't have access to that information yet.
     */
    if ((saveResult != HFSaveError) && (saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation)) {
        HFFileReference *fileReference = [[HFFileReference alloc] initWithPath:[inAbsoluteURL path] error:NULL];
        if (fileReference) {
            HFByteArray *oldByteArray = [controller byteArray];

            HFByteArray *newByteArray = [[preferredByteArrayClass() alloc] init];
            HFFileByteSlice *byteSlice = [[HFFileByteSlice alloc] initWithFile:fileReference];
            [newByteArray insertByteSlice:byteSlice inRange:HFRangeMake(0, 0)];
            
            /* Propogate attributes (like bookmarks) */
            HFByteRangeAttributeArray *oldAttributes = [oldByteArray byteRangeAttributeArray];
            HFByteRangeAttributeArray *newAttributes = [newByteArray byteRangeAttributeArray];
            if (oldAttributes && newAttributes) {
                HFRange range = HFRangeMake(0, MIN([oldByteArray length], [newByteArray length]));
                [newAttributes transferAttributesFromAttributeArray:oldAttributes range:range baseOffset:0 validator:NULL];
            }            
            [controller setByteArray:newByteArray];
            cleanGenerationCount = [newByteArray changeGenerationCount];
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
    dispatch_block_t selectText = ^{
        NSView *field = [self->findReplaceView viewNamed:@"searchField"];
        HFASSERT([field isKindOfClass:[HFTextField class]]);
        [(HFTextField*)field selectAll:nil];
    };

    if (operationView != nil && operationView == findReplaceView) {
        [self saveFirstResponderIfNotInBannerAndThenSetItTo:[findReplaceView viewNamed:@"searchField"]];
        selectText();
        return;
    }
    if (! [self canSwitchToNewBanner]) {
        NSBeep();
        return;
    }
    USE(item);
    if (bannerIsShown) {
        [self hideBannerFirstThenDo:^(){[self showFindPanel:item];}];
        return;
    }
    
    if (! findReplaceView) {
        findReplaceView = [self newOperationViewForNibName:@"FindReplaceBanner" displayName:@"Finding"];
        [(HFTextField*)[findReplaceView viewNamed:@"searchField"] setTarget:self];
        [(HFTextField*)[findReplaceView viewNamed:@"searchField"] setAction:@selector(findNext:)];
        [(HFTextField*)[findReplaceView viewNamed:@"replaceField"] setTarget:self];
        [(HFTextField*)[findReplaceView viewNamed:@"replaceField"] setAction:@selector(findNext:)]; //yes, this should be findNext:, not replace:, because when you just hit return in the replace text field, it only finds; replace is for the replace button
    }
    
    commandToRunAfterBannerPrepared = selectText;
    [self prepareBannerWithView:findReplaceView withTargetFirstResponder:[findReplaceView viewNamed:@"searchField"]];
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
    if (tracker->cancelRequested) return @(HFSaveCancelled);
    else if (! result) return @(HFSaveError);
    else return @(HFSaveSuccessful);    
}

- (id)threadedFindBytes:(HFByteArray *)needle inBytes:(HFByteArray *)haystack inRange1:(HFRange)range1 range2:(HFRange)range2 forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)tracker {
    unsigned long long searchResult;
    [tracker setMaxProgress:[haystack length]];
    searchResult = [haystack indexOfBytesEqualToBytes:needle inRange:range1 searchingForwards:forwards trackingProgress:tracker];
    if (searchResult == ULLONG_MAX) {
        searchResult = [haystack indexOfBytesEqualToBytes:needle inRange:range2 searchingForwards:forwards trackingProgress:tracker];
    }
    if (tracker->cancelRequested) return nil;
    else return @(searchResult);
}

- (void)findEnded:(NSNumber *)val {
    NSDictionary *userInfo = [[findReplaceView progressTracker] userInfo];
    HFByteArray *needle = userInfo[@"needle"];
    HFByteArray *haystack = userInfo[@"haystack"];
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
    HFByteArray *needle = [(HFTextField*)[findReplaceView viewNamed:@"searchField"] objectValue];
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
                [self->controller setSelectedContentsRanges:[HFRangeWrapper withRanges:&resultRange count:1]];
                [self->controller maximizeVisibilityOfContentsRange:resultRange];
                [self restoreFirstResponderToSavedResponder];
                [self->controller pulseSelection];
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
    HFByteArray *newHaystack = [haystack mutableCopy];
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
    HFByteArray *replaceArray = [(HFTextField*)[findReplaceView viewNamed:@"replaceField"] objectValue];
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
    HFByteArray *needle = [(HFTextField*)[findReplaceView viewNamed:@"searchField"] objectValue];
    if ([needle length] == 0) {
        NSBeep();
        return;
    }
    HFByteArray *replacementValue = [(HFTextField*)[findReplaceView viewNamed:@"replaceField"] objectValue];
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
            [self->controller replaceByteArray:newByteArray];
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
    NSUInteger selection = [sender selectedSegment];
    switch (selection) {
        case 0:
            [self replaceAll:sender];
            break;
        case 1:
            [self replace:sender];
            break;
        case 2:
            [self replaceAndFind:sender];
            break;
        case 3:
            [self findPrevious:sender];
            break;
        case 4:
            [self findNext:sender];
            break;
        default:
            NSBeep();
            HFASSERT(0);
            break;
    }
}

- (void)showNavigationBannerSettingExtendSelectionCheckboxTo:(BOOL)extend {
    if (moveSelectionByView == operationView && moveSelectionByView != nil) {
        [(NSButton*)[moveSelectionByView viewNamed:@"extendSelectionByCheckbox"] setIntValue:extend];
        [self saveFirstResponderIfNotInBannerAndThenSetItTo:[moveSelectionByView viewNamed:@"moveSelectionByTextField"]];
        return;
    }
    if (! moveSelectionByView) moveSelectionByView = [self newOperationViewForNibName:@"MoveSelectionByBanner" displayName:@"Moving Selection"];
    [(NSButton*)[moveSelectionByView viewNamed:@"extendSelectionByCheckbox"] setIntValue:extend];
    [self prepareBannerWithView:moveSelectionByView withTargetFirstResponder:[moveSelectionByView viewNamed:@"moveSelectionByTextField"]];
    
}

- (void)moveSelectionForwards:(NSMenuItem *)sender {
    USE(sender);
    if (! [self canSwitchToNewBanner]) {
        NSBeep();
        return;
    }
    if (operationView != nil && operationView != moveSelectionByView) {
        [self hideBannerFirstThenDo:^(){[self moveSelectionForwards:sender];}];
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
        [self hideBannerFirstThenDo:^(){[self extendSelectionForwards:sender];}];
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
        [self hideBannerFirstThenDo:^(){[self jumpToOffset:sender];}];
        return;
    }
    if (! jumpToOffsetView) jumpToOffsetView = [self newOperationViewForNibName:@"JumpToOffsetBanner" displayName:@"Jumping to Offset"];
    if (operationView == jumpToOffsetView) {
        [self saveFirstResponderIfNotInBannerAndThenSetItTo:[jumpToOffsetView viewNamed:@"moveSelectionByTextField"]];
    } else {
        [self prepareBannerWithView:jumpToOffsetView withTargetFirstResponder:[jumpToOffsetView viewNamed:@"moveSelectionByTextField"]];
    }
}

- (BOOL)movingRanges:(NSArray *)ranges byAmount:(unsigned long long)value isNegative:(BOOL)isNegative isValidForLength:(unsigned long long)length {
    for(HFRangeWrapper *wrapper in ranges) {
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
    if (parseNumericStringWithSuffix([(NSTextField*)[jumpToOffsetView viewNamed:@"moveSelectionByTextField"] stringValue], &value, &isNegative)) {
        unsigned long long length = [controller contentsLength];
        if (length >= value) {
            const unsigned long long offset = (isNegative ? length - value : value);
            const HFRange contentsRange = HFRangeMake(offset, 0);
            [controller setSelectedContentsRanges:@[[HFRangeWrapper withRange:contentsRange]]];
            [controller maximizeVisibilityOfContentsRange:contentsRange];
            [controller pulseSelection];
            success = YES;
        }
    }
    if (! success) NSBeep();
    else [self restoreFirstResponderToSavedResponder];
}

- (IBAction)moveSelectionByAction:(id)sender {
    USE(sender);
    BOOL success = NO;
    unsigned long long value;
    BOOL isNegative;
    if (parseNumericStringWithSuffix([(NSTextField*)[moveSelectionByView viewNamed:@"moveSelectionByTextField"] stringValue], &value, &isNegative)) {
        if ([self movingRanges:[controller selectedContentsRanges] byAmount:value isNegative:isNegative isValidForLength:[controller contentsLength]]) {
            BOOL extendSelection = !![(NSTextField*)[moveSelectionByView viewNamed:@"extendSelectionByCheckbox"] intValue];
            HFControllerMovementDirection direction = (isNegative ? HFControllerDirectionLeft : HFControllerDirectionRight);
            HFControllerSelectionTransformation transformation = (extendSelection ? HFControllerExtendSelection : HFControllerShiftSelection);
            [controller moveInDirection:direction byByteCount:value withSelectionTransformation:transformation usingAnchor:NO];
            [controller maximizeVisibilityOfContentsRange:[[controller selectedContentsRanges][0] HFRange]];
            [controller pulseSelection];
            success = YES;
        }
    }
    if (! success) NSBeep();
    else [self restoreFirstResponderToSavedResponder];
}

- (NSArray *)copyBookmarksMenuItems {
    NSMutableArray *items = [[NSMutableArray alloc] init];
    @autoreleasepool {
    
    /* Get a list of the bookmarks. */
    NSIndexSet *bookmarks = [controller bookmarksInRange:HFRangeMake(0, [controller contentsLength])];
    const NSUInteger numberOfBookmarks = [bookmarks count];
    
    NSUInteger bookmarkIndex = 0; //0 is an invalid bookmark
    for(NSUInteger i = 0; i < numberOfBookmarks; i++) {
        /* Get this bookmark index */
        bookmarkIndex = [bookmarks indexGreaterThanIndex:bookmarkIndex];
        
        /* Compute our KE */
        NSString *keString = @"";
        if (bookmarkIndex <= 10) {
            char ke = '0' + (bookmarkIndex % 10);
            keString = [[NSString alloc] initWithBytes:&ke length:1 encoding:NSASCIIStringEncoding];
        }
        
        /* The first item is Select Bookmark, the second (alternate) is Scroll To Bookmark */
        
        NSMenuItem *item;

        item = [[NSMenuItem alloc]
                initWithTitle:[NSString stringWithFormat:@"Select Bookmark %lu", (unsigned long)bookmarkIndex]
                action:@selector(selectBookmark:)
                keyEquivalent:keString];
        [item setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
        [item setAlternate:NO];
        [item setTag:bookmarkIndex];
        [items addObject:item];
        
        item = [[NSMenuItem alloc]
                initWithTitle:[NSString stringWithFormat:@"Scroll to Bookmark %lu", (unsigned long)bookmarkIndex]
                action:@selector(scrollToBookmark:)
                keyEquivalent:keString];
        [item setKeyEquivalentModifierMask:NSEventModifierFlagCommand | NSEventModifierFlagShift];
        [item setAlternate:YES];
        [item setTag:bookmarkIndex];
        [items addObject:item];
    }
    
    } // @autoreleasepool
    return items;
}

- (IBAction)showFontPanel:(id)sender {
    NSFontPanel *panel = [NSFontPanel sharedFontPanel];
    [panel orderFront:sender];
    [panel setPanelFont:[self font] isMultiple:NO];
}

- (void)changeFont:(id)sender {
    [self setFont:[sender convertFont:[self font]] registeringUndo:YES];
}

- (NSFontPanelModeMask)validModesForFontPanel:(NSFontPanel * __unused)fontPanel {
    // NSFontPanel can choose color and style, but Hex Fiend only supports
    // customizing the font face, so only return that for the mask. This method
    // is part of the NSFontChanging protocol.
    // Note: as of 10.15.2, even with no other mask set, the font panel still shows
    // a gear pop up button that allows bringing up the Color panel.
    return NSFontPanelModeMaskFace;
}

- (IBAction)modifyByteGrouping:(id)sender {
    NSUInteger newBytesPerColumn = (NSUInteger)[sender tag];
    [self setByteGrouping:newBytesPerColumn];
}

- (void)setByteGrouping:(NSUInteger)newBytesPerColumn {
    NSUInteger bytesPerLine = [controller bytesPerLine], newDesiredBytesPerLine;
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

- (IBAction)customByteGrouping:(id __unused)sender {
    NSString *byteGrouping = HFPromptForValue(NSLocalizedString(@"Enter a custom byte grouping", ""));
    if (byteGrouping) {
        NSInteger value = byteGrouping.integerValue;
        if (value >= 0) {
            [self setByteGrouping:value];
            [(AppDelegate *)NSApp.delegate buildByteGroupingMenu];
        }
    }
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

- (IBAction)setLineNumberFormat:(id)sender
{
    const NSInteger tag = ((NSMenuItem*)sender).tag;
    const HFLineNumberFormat format = (HFLineNumberFormat)tag;
    HFASSERT(format == HFLineNumberFormatDecimal || format == HFLineNumberFormatHexadecimal);
    lineCountingRepresenter.lineNumberFormat = format;
    [self saveLineNumberFormat];
}

- (void)saveLineNumberFormat
{
    [[NSUserDefaults standardUserDefaults] setInteger:lineCountingRepresenter.lineNumberFormat forKey:@"LineNumberFormat"];
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
        HFRange range = [ranges[0] HFRange];
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
        HFRange range = [ranges[0] HFRange];
        /* We always set a bookmark on at least one byte */
        range.length = MAX(range.length, 1u);
        NSIndexSet *usedBookmarks = [controller bookmarksInRange:HFRangeMake(0, [controller contentsLength])];
        
        /* Find the first index that bookmarks does not contain, excepting 0 */
        NSMutableIndexSet *availableBookmarks = [[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(1, NSNotFound - 2)];
        [availableBookmarks removeIndexes:usedBookmarks];
        NSUInteger newBookmark = [availableBookmarks firstIndex];
        
        if (newBookmark != NSNotFound) {
            [controller setRange:range forBookmark:newBookmark];
        }
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
        for(NSWindowController *localController in [self windowControllers]) {
            if ([[localController window] attachedSheet]) {
                controllerWithSheet = localController;
                break;
            }
        }
        result = (controllerWithSheet == nil);
    }
    return result;
}

+ (void)prepareForChangeInFileByBreakingFileDependencies:(NSNotification *)note {
    HFFileReference *fileReference = [note object];
    NSDictionary *userInfo = [note userInfo];
    
    BOOL *cancellationPointer = [userInfo[HFChangeInFileShouldCancelKey] pointerValue];
    if (*cancellationPointer) return; //don't do anything if someone requested cancellation
    
    HFByteArray *byteArray = userInfo[HFChangeInFileByteArrayKey];
    NSMutableDictionary *hint = userInfo[HFChangeInFileHintKey];
    NSArray *modifiedRanges = userInfo[HFChangeInFileModifiedRangesKey];
    NSArray *allDocuments = [[[NSDocumentController sharedDocumentController] documents] copy]; //we copy this because we may need to close them
    
    /* Determine which document contains this byte array so we can make a nice dialog */
    BaseDataDocument *documentForThisByteArray = nil;
    for(BaseDataDocument *testDocument in allDocuments) {
        if ([testDocument->controller byteArray] == byteArray) {
            documentForThisByteArray = testDocument;
            break;
        }
    }
    HFASSERT(documentForThisByteArray != nil); //for now we require that saving a ByteArray is associated with a document save
    
    for(BaseDataDocument *document in allDocuments) {
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
            [alert setInformativeText:NSLocalizedString(@"To save that document, you must close this one.", "")];
            [alert addButtonWithTitle:NSLocalizedString(@"Cancel Save", "")];
            [alert addButtonWithTitle:NSLocalizedString(@"Close, Discarding Any Changes", "")];
            [alert beginSheetModalForWindow:[document windowForSheet] completionHandler:^(NSModalResponse returnCode) {
                [NSApp stopModalWithCode:returnCode];
            }];
            NSInteger modalResult = [NSApp runModalForWindow:[alert window]];
            
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
}

- (BOOL)requiresOverwriteMode
{
    return NO;
}

- (BOOL)shouldLiveReload {
    return shouldLiveReload;
}

- (void)setShouldLiveReload:(BOOL)flag {
    shouldLiveReload = flag;
    if(flag) [self pollLiveReload];
}

- (IBAction)setLiveReloadFromMenuItem:(id)sender {
    USE(sender);
    BOOL newVal = ![controller shouldLiveReload];
    [controller setShouldLiveReload:newVal];
    [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"LiveReload"];
    [self setShouldLiveReload:[controller shouldLiveReload]];
}

- (void)insertData:(NSData *)data {
    [controller insertData:data replacingPreviousBytes:0 allowUndoCoalescing:NO];
}

@end

// Let the compiler know about the 10.9 -[NSTimer setTolerance:] selector
// even though we're targeting several versions behind that.
@protocol MyNSTimerSetToleranceProtocol
- (void)setTolerance:(NSTimeInterval)tolerance;
@end

@implementation BaseDataDocument(LiveReloading)

// TODO: Some of the other NSFilePresenter methods could be used to make a
// more versitle live-updating option.

// Also, there may be a race conditon here: if a file being operated on
// is swapped with another file during the live reload and just before the
// live reload actually starts reverting, it may be that we revert to the
// swapped in file rather than the actual file. I'm dubious that the use
// of NSFileCoordinator here saves us from this, but it might. Even with
// the race, there's no strong data loss concern; it just might happen that,
// in extreme conditions, an unmodified document becomes a different document.
// TODO: Investigate this.

#define LiveReloadTimeTolerance 1.0 // Allow the timer lots of slack.
#define LiveReloadTimeThrottle 1.0  // Auto reload at most every second.

- (void)presentedItemDidChange {
    // Stay in sync with changes if there are no outstanding edits and an
    // update check is not already scheduled.
    [self pollLiveReload];
}

- (void)pollLiveReload {
    if(!shouldLiveReload) return;
    if([self isDocumentEdited]) return; // Don't clobber changes.
    if(liveReloadTimer && [liveReloadTimer isValid]) return; // A live reload is already scheduled.

    NSDate *nextDate;
    if(liveReloadDate && [liveReloadDate timeIntervalSinceNow] > -LiveReloadTimeThrottle) {
        // Happened recently, throttle a bit.
        nextDate = [liveReloadDate dateByAddingTimeInterval:LiveReloadTimeThrottle];
    } else {
        // Did not update recently, update soon.
        nextDate = [NSDate date];
    }
    
    liveReloadTimer = [[NSTimer alloc] initWithFireDate:nextDate interval:0 target:self selector:@selector(tryLiveReload) userInfo:nil repeats:NO];
    
    if([liveReloadTimer respondsToSelector:@selector(setTolerance:)]) {
        [(id<MyNSTimerSetToleranceProtocol>)liveReloadTimer setTolerance:LiveReloadTimeTolerance];
    }
    [[NSRunLoop mainRunLoop] addTimer:liveReloadTimer forMode:NSDefaultRunLoopMode];
}

- (BOOL)tryLiveReload {
    if(!shouldLiveReload) return NO;
    if([self isDocumentEdited]) return NO; // Don't clobber changes.
    
    NSError *error = nil;
    __block BOOL gotError = NO;
    
    NSFileCoordinator *filecoord = [[NSFileCoordinator alloc] initWithFilePresenter:self];
    [filecoord coordinateReadingItemAtURL:[self fileURL] options:0 error:&error byAccessor:^ (NSURL *url) {
        NSError *attrsError = nil;
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:[[url filePathURL] path] error:&attrsError];
        if(attrsError) {
            gotError = YES;
            return;
        }
        if([attrs[NSFileModificationDate] isGreaterThan:[self fileModificationDate]]) {
            // Perhaps find a way to make this revert part of the undo buffer.
            NSError *revertError = nil;
            [self revertToContentsOfURL:url ofType:[self fileType] error:&revertError];
            if (revertError) {
                gotError = YES;
            }
        }
    }];
    
    liveReloadDate = [NSDate date];
    
    return error || gotError ? NO : YES;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
    savePanel.allowedFileTypes = nil;
    savePanel.allowsOtherFileTypes = YES;
    savePanel.treatsFilePackagesAsDirectories = YES;
    savePanel.showsHiddenFiles = YES;
    savePanel.accessoryView = nil; // defeat useless "File Format" accessory view
    return YES;
}

- (BOOL)isInViewingMode {
    // NSDocument override
    return !controller.savable || super.isInViewingMode;
}

@end
