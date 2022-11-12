//
//  HFTextRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import "HFTextRepresenter_Internal.h"
#import <HexFiend/HFRepresenterTextView.h>
#if !TARGET_OS_IPHONE
#import <HexFiend/HFPasteboardOwner.h>
#endif
#import <HexFiend/HFByteArray.h>
#import <HexFiend/HFByteRangeAttributeArray.h>
#import "HFTextVisualStyleRun.h"
#import <HexFiend/HFByteRangeAttribute.h>
#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFAssert.h>
#import "HFColorRange.h"

@implementation HFTextRepresenter {
    NSUInteger _clickedLocation;
}

- (Class)_textViewClass {
    UNIMPLEMENTED();
}

+ (NSArray<HFColor *> *)defaultRowBackgroundColors {
#if TARGET_OS_IPHONE
    UIColor *color1 = [UIColor colorWithWhite:1.0 alpha:1.0];
    UIColor *color2 = [UIColor colorWithRed:.87 green:.89 blue:1. alpha:1.];
#else
    const BOOL useHFBlue = [NSUserDefaults.standardUserDefaults boolForKey:@"UseBlueAlternatingColor"];
    if (@available(macOS 10.14, *)) {
        if (HFDarkModeEnabled() || !useHFBlue) {
            return [NSColor alternatingContentBackgroundColors];
        }
    }
    NSColor *color1 = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
    NSColor *color2;
    if (useHFBlue) {
        color2 = [NSColor colorWithCalibratedRed:.87 green:.89 blue:1. alpha:1.];
    } else {
        // try to match alternatingContentBackgroundColors in light mode
        color2 = [NSColor colorWithCalibratedWhite:245/255.0 alpha:1.0];
    }
#endif
    return @[color1, color2];
}

- (NSArray<HFColor *> *)rowBackgroundColors {
    // If set use the customized value, otherwise return the default.
    // This must be dynamic and not stored so we can update live on redraw
    // when the appearance changes.
    if (_rowBackgroundColors) {
        return _rowBackgroundColors;
    }
    return [[self class] defaultRowBackgroundColors];
}

- (void)dealloc {
    if ([self isViewLoaded]) {
        [(HFRepresenterTextView *)[self view] clearRepresenter];
    }
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeBool:_behavesAsTextField forKey:@"HFBehavesAsTextField"];
    [coder encodeObject:_rowBackgroundColors forKey:@"HFRowBackgroundColors"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    _behavesAsTextField = [coder decodeBoolForKey:@"HFBehavesAsTextField"];
    _rowBackgroundColors = [coder decodeObjectForKey:@"HFRowBackgroundColors"];
    return self;
}

- (HFView *)createView {
    HFRepresenterTextView *view = [[[self _textViewClass] alloc] initWithRepresenter:self];
#if !TARGET_OS_IPHONE
    [view setAutoresizingMask:NSViewHeightSizable];
#endif
    return view;
}

- (HFByteArrayDataStringType)byteArrayDataStringType {
    UNIMPLEMENTED();
}

- (HFRange)entireDisplayedRange {
    HFController *controller = [self controller];
    unsigned long long contentsLength = [controller contentsLength];
    HFASSERT(controller != NULL);
    HFFPRange displayedLineRange = [controller displayedLineRange];
    NSUInteger bytesPerLine = [controller bytesPerLine];
    unsigned long long lineStart = HFFPToUL(floorl(displayedLineRange.location));
    unsigned long long lineEnd = HFFPToUL(ceill(displayedLineRange.location + displayedLineRange.length));
    HFASSERT(lineEnd >= lineStart);
    HFRange byteRange = HFRangeMake(HFProductULL(bytesPerLine, lineStart), HFProductULL(lineEnd - lineStart, bytesPerLine));
    if (byteRange.length == 0) {
        /* This can happen if we are too small to even show one line */
        return HFRangeMake(0, 0);
    }
    else {
        HFASSERT(byteRange.location <= contentsLength);
        byteRange.length = MIN(byteRange.length, contentsLength - byteRange.location);
        HFASSERT(HFRangeIsSubrangeOfRange(byteRange, HFRangeMake(0, [controller contentsLength])));
        return byteRange;
    }
}

- (CGRect)furthestRectOnEdge:(CGRectEdge)edge forByteRange:(HFRange)byteRange {
    HFASSERT(byteRange.length > 0);
    HFRange displayedRange = [self entireDisplayedRange];
    HFRange intersection = HFIntersectionRange(displayedRange, byteRange);
    CGRect result = CGRectZero;
    if (intersection.length > 0) {
        NSRange intersectionNSRange = NSMakeRange(ll2l(intersection.location - displayedRange.location), ll2l(intersection.length));
        if (intersectionNSRange.length > 0) {
            result = [(HFRepresenterTextView *)[self view] furthestRectOnEdge:edge forRange:intersectionNSRange];
        }
    }
    else if (byteRange.location < displayedRange.location) {
        /* We're below it. */
        return CGRectMake(-CGFLOAT_MAX, -CGFLOAT_MAX, 0, 0);
    }
    else if (byteRange.location >= HFMaxRange(displayedRange)) {
        /* We're above it */
        return CGRectMake(CGFLOAT_MAX, CGFLOAT_MAX, 0, 0);
    }
    else {
        /* Shouldn't be possible to get here */
        [NSException raise:NSInternalInconsistencyException format:@"furthestRectOnEdge: expected an intersection, or a range below or above the byte range, but nothin'"];
    }
    return result;
}

- (CGPoint)locationOfCharacterAtByteIndex:(unsigned long long)index {
    CGPoint result;
    HFRange displayedRange = [self entireDisplayedRange];
    if (HFLocationInRange(index, displayedRange) || index == HFMaxRange(displayedRange)) {
        NSUInteger location = ll2l(index - displayedRange.location);
        result = [(HFRepresenterTextView *)[self view] originForCharacterAtByteIndex:location];
    }
    else if (index < displayedRange.location) {
        result = CGPointMake(-CGFLOAT_MAX, -CGFLOAT_MAX);
    }
    else {
        result = CGPointMake(CGFLOAT_MAX, CGFLOAT_MAX);
    }
    return result;
}

- (HFTextVisualStyleRun *)styleForAttributes:(NSSet *)attributes range:(NSRange)range {
    HFTextVisualStyleRun *run = [[HFTextVisualStyleRun alloc] init];
    [run setRange:range];
    if ([attributes containsObject:kHFAttributeMagic]) {
        [run setForegroundColor:[HFColor blueColor]];
        [run setBackgroundColor:[HFColor orangeColor]];
    }
    else {
        HFColor *foregroundColor = [HFColor labelColor];
        [run setForegroundColor:foregroundColor];
    }
    if ([attributes containsObject:kHFAttributeUnmapped]) {
        [run setShouldDraw:NO];
    }
    if ([attributes containsObject:kHFAttributeUnreadable]) {
        [run setBackgroundColor:HFColorWithWhite(.5, .5)];
    }
    else if ([attributes containsObject:kHFAttributeWritable]) {
        [run setBackgroundColor:HFColorWithRGB(.5, 1., .5, .5)];
    }
    else if ([attributes containsObject:kHFAttributeExecutable]) {
        [run setBackgroundColor:HFColorWithRGB(1., .5, 0., .5)];
    }
    if ([attributes containsObject:kHFAttributeFocused]) {
        [run setBackgroundColor:HFColorWithRGB((CGFloat)128/255., (CGFloat)0/255., 0/255., 1.)];
        [run setScale:1.15];
        [run setForegroundColor:[HFColor whiteColor]];
    }
    else if ([attributes containsObject:kHFAttributeDiffInsertion]) {
        CGFloat white = 180;
        [run setBackgroundColor:HFColorWithRGB((CGFloat)255./255., (CGFloat)white/255., white/255., .7)];
    }
    
    /* Process bookmarks */
    NSMutableIndexSet *bookmarkExtents = nil;
    for(NSString * attribute in attributes) {
        NSInteger bookmark = HFBookmarkFromBookmarkAttribute(attribute);
        if (bookmark != NSNotFound) {
            if (! bookmarkExtents) bookmarkExtents = [[NSMutableIndexSet alloc] init];
            [bookmarkExtents addIndex:bookmark];
        }
    }
    
    if (bookmarkExtents) {
        [run setBookmarkExtents:bookmarkExtents];
    }
    return run;
}

- (NSArray *)stylesForRange:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax);
    HFByteRangeAttributeArray *runs = [[self controller] attributesForBytesInRange:range];
    if (! runs) return nil;
    NSMutableArray *result = [NSMutableArray array];
    HFRange remainingRange = range;
    NSUInteger localOffset = 0;
    while (remainingRange.length > 0) {
        unsigned long long attributeRunLength = 0;
        NSSet *attributes = [runs attributesAtIndex:remainingRange.location length:&attributeRunLength];
        NSUInteger boundedRunLength = ll2l(MIN(attributeRunLength, remainingRange.length));
        [result addObject:[self styleForAttributes:attributes range:NSMakeRange(localOffset, boundedRunLength)]];
        localOffset += boundedRunLength;
        remainingRange.length = HFSubtract(remainingRange.length, boundedRunLength);
        remainingRange.location = HFSum(remainingRange.location, boundedRunLength);
    }
    return result;
}

+ (CGFloat)verticalOffsetForLineRange:(HFFPRange)range {
    long double offsetLongDouble = range.location - floorl(range.location);
    CGFloat offset = ld2f(offsetLongDouble);
    return offset;
}

- (void)updateText {
    HFController *controller = [self controller];
    HFRepresenterTextView *view = (HFRepresenterTextView *)[self view];
    HFRange entireDisplayedRange = [self entireDisplayedRange];
    [view setData:[controller dataForRange:entireDisplayedRange]];
    [view setStyles:[self stylesForRange:entireDisplayedRange]];
    HFFPRange lineRange = [controller displayedLineRange];
    [view setVerticalOffset:[[self class] verticalOffsetForLineRange:lineRange]];
    [view setStartingLineBackgroundColorIndex:ll2l(HFFPToUL(floorl(lineRange.location)) % NSUIntegerMax)];
}

- (void)initializeView {
    [super initializeView];
    HFRepresenterTextView *view = (HFRepresenterTextView *)[self view];
    HFController *controller = [self controller];
    if (controller) {
        [view setFont:[controller font]];
        [view setEditable:[controller editable]];
        [self updateText];
    }
    else {
#if !TARGET_OS_IPHONE
        [view setFont:[NSFont fontWithName:HFDEFAULT_FONT size:HFDEFAULT_FONTSIZE]];
#endif
    }
}

#if !TARGET_OS_IPHONE
- (void)scrollWheel:(NSEvent *)event {
    [[self controller] scrollWithScrollEvent:event];
}
#endif

- (void)selectAll:(id)sender {
    [[self controller] selectAll:sender];
}

- (double)selectionPulseAmount {
    return [[self controller] selectionPulseAmount];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerFont | HFControllerLineHeight)) {
        [(HFRepresenterTextView *)[self view] setFont:[[self controller] font]];
    }
    if (bits & (HFControllerContentValue | HFControllerDisplayedLineRange | HFControllerByteRangeAttributes)) {
        [self updateText];
    }
    if (bits & (HFControllerSelectedRanges | HFControllerDisplayedLineRange)) {
        [(HFRepresenterTextView *)[self view] updateSelectedRanges];
    }
    if (bits & (HFControllerSelectionPulseAmount)) {
        [(HFRepresenterTextView *)[self view] updateSelectionPulse];
    }
    if (bits & (HFControllerEditable)) {
        [(HFRepresenterTextView *)[self view] setEditable:[[self controller] editable]];
    }
    if (bits & (HFControllerAntialias)) {
        [(HFRepresenterTextView *)[self view] setShouldAntialias:[[self controller] shouldAntialias]];
    }
    if (bits & (HFControllerShowCallouts)) {
        [(HFRepresenterTextView *)[self view] setShouldDrawCallouts:[[self controller] shouldShowCallouts]];
    }
    if (bits & (HFControllerBookmarks | HFControllerDisplayedLineRange | HFControllerContentValue)) {
        [(HFRepresenterTextView *)[self view] setBookmarks:[self displayedBookmarkLocations]];
    }
    if (bits & (HFControllerColorBytes)) {
        if([[self controller] shouldColorBytes]) {
            [(HFRepresenterTextView *)[self view] setByteColoring: ^(uint8_t byte, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a){
                *r = *g = *b = (uint8_t)(255 * ((255-byte)/255.0*0.6+0.4));
                *a = (uint8_t)(255 * 0.7);
                if (HFDarkModeEnabled()) {
                    *r = 255 - *r;
                    *g = 255 - *g;
                    *b = 255 - *b;
                }
            }];
        } else {
            [(HFRepresenterTextView *)[self view] setByteColoring:NULL];
        }
    }
    if (bits & (HFControllerColorRanges)) {
        [(HFRepresenterTextView *)[self view] updateSelectedRanges];
#if TARGET_OS_IPHONE
        [[self view] setNeedsDisplay];
#else
        [[self view] setNeedsDisplay:YES];
#endif
    }
    [super controllerDidChange:bits];
}

- (double)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
    return [(HFRepresenterTextView *)[self view] maximumAvailableLinesForViewHeight:viewHeight];
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    return [(HFRepresenterTextView *)[self view] maximumBytesPerLineForViewWidth:viewWidth];
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    return [(HFRepresenterTextView *)[self view] minimumViewWidthForBytesPerLine:bytesPerLine];
}

- (NSUInteger)byteGranularity {
    HFRepresenterTextView *view = (HFRepresenterTextView *)[self view];
    NSUInteger bytesPerColumn = MAX([view bytesPerColumn], 1u), bytesPerCharacter = [view bytesPerCharacter];
    return HFLeastCommonMultiple(bytesPerColumn, bytesPerCharacter);
}

- (NSArray *)displayedSelectedContentsRanges {
    HFController *controller = [self controller];
    NSArray *selectedRanges = [controller selectedContentsRanges];
    return [self displayedRanges:selectedRanges];
}

- (NSArray<NSDictionary*> *)displayedColorRanges {
    NSMutableArray<NSDictionary*> *a = [NSMutableArray array];
    [self.controller.colorRanges enumerateObjectsUsingBlock:^(HFColorRange *obj, NSUInteger idx __unused, BOOL *stop __unused) {
        if (!obj.color) {
            return;
        }
        HFRangeWrapper *wrapper = obj.range;
        NSArray *displayed = [self displayedRanges:@[wrapper]];
        if (displayed.count > 0) {
            [a addObject:@{@"color" : obj.color, @"range" : displayed.firstObject}];
        }
    }];
    return a;
}

- (NSArray<NSValue*> *)displayedRanges:(NSArray *)ranges
{
    const HFRange displayedRange = [self entireDisplayedRange];
    HFASSERT(displayedRange.length <= NSUIntegerMax);
    NEW_OBJ_ARRAY(NSValue *, clippedRanges, [ranges count]);
    NSUInteger clippedRangeIndex = 0;
    for(HFRangeWrapper * wrapper in ranges) {
        const HFRange range = [wrapper HFRange];
        BOOL clippedRangeIsVisible;
        NSRange clippedRange;
        /* Necessary because zero length ranges do not intersect anything */
        if (range.length == 0) {
            /* Remember that {6, 0} is considered a subrange of {3, 3} */
            clippedRangeIsVisible = HFRangeIsSubrangeOfRange(range, displayedRange);
            if (clippedRangeIsVisible) {
                HFASSERT(range.location >= displayedRange.location);
                clippedRange.location = ll2l(range.location - displayedRange.location);
                clippedRange.length = 0;
            }
        }
        else {
            // selectedRange.length > 0
            clippedRangeIsVisible = HFIntersectsRange(range, displayedRange);
            if (clippedRangeIsVisible) {
                HFRange intersectionRange = HFIntersectionRange(range, displayedRange);
                HFASSERT(intersectionRange.location >= displayedRange.location);
                clippedRange.location = ll2l(intersectionRange.location - displayedRange.location);
                clippedRange.length = ll2l(intersectionRange.length);
            }
        }
        if (clippedRangeIsVisible) clippedRanges[clippedRangeIndex++] = [NSValue valueWithRange:clippedRange];
    }
    NSArray *result = [NSArray arrayWithObjects:clippedRanges count:clippedRangeIndex];
    FREE_OBJ_ARRAY(clippedRanges, [ranges count]);
    return result;
}

//maps bookmark keys as NSNumber to byte locations as NSNumbers. Because bookmark callouts may extend beyond the lines containing them, allow a larger range by 10 lines.
- (NSDictionary *)displayedBookmarkLocations {
    NSMutableDictionary *result = nil;
    HFController *controller = [self controller];
    NSUInteger rangeExtension = 10 * [controller bytesPerLine];
    HFRange displayedRange = [self entireDisplayedRange];
    
    HFRange includedRange = displayedRange;
    
    /* Extend the bottom */
    unsigned long long bottomExtension = MIN(includedRange.location, rangeExtension);
    includedRange.location -= bottomExtension;
    includedRange.length += bottomExtension;
    
    /* Extend the top */
    unsigned long long topExtension = MIN([controller contentsLength] - HFMaxRange(includedRange), rangeExtension);
    includedRange.length = HFSum(includedRange.length, topExtension);
    
    NSIndexSet *allBookmarks = [controller bookmarksInRange:includedRange];
    for (unsigned long mark = [allBookmarks firstIndex]; mark != NSNotFound; mark = [allBookmarks indexGreaterThanIndex:mark]) {
        HFRange bookmarkRange = [controller rangeForBookmark:mark];
        if (HFLocationInRange(bookmarkRange.location, includedRange)) {
            if (! result) result = [NSMutableDictionary dictionary];
            
            NSNumber *key = [[NSNumber alloc] initWithUnsignedInteger:mark];
            NSNumber *value = [[NSNumber alloc] initWithInteger:(long)(bookmarkRange.location - displayedRange.location)];
            result[key] = value;
        }
    }
    return result;
}

- (unsigned long long)byteIndexForCharacterIndex:(NSUInteger)characterIndex {
    HFController *controller = [self controller];
    HFFPRange lineRange = [controller displayedLineRange];
    unsigned long long scrollAmount = HFFPToUL(floorl(lineRange.location));
    unsigned long long byteIndex = HFProductULL(scrollAmount, [controller bytesPerLine]) + characterIndex * [(HFRepresenterTextView *)[self view] bytesPerCharacter];
    return byteIndex;
}

#if !TARGET_OS_IPHONE
- (void)beginSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] beginSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}

- (void)continueSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] continueSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}

- (void)endSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] endSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}
#endif

- (void)insertText:(NSString *)text {
    USE(text);
    UNIMPLEMENTED_VOID();
}

#if !TARGET_OS_IPHONE
- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb {
    USE(pb);
    UNIMPLEMENTED_VOID();
}

- (void)cutSelectedBytesToPasteboard:(NSPasteboard *)pb {
    [self copySelectedBytesToPasteboard:pb];
    [[self controller] deleteSelection];
}

- (NSData *)dataFromPasteboardString:(NSString *)string {
    USE(string);
    UNIMPLEMENTED();
}

- (BOOL)canPasteFromPasteboard:(NSPasteboard *)pb {
    REQUIRE_NOT_NULL(pb);
    if ([[self controller] editable]) {
        // we can paste if the pboard contains text or contains an HFByteArray
        return [HFPasteboardOwner unpackByteArrayFromPasteboard:pb] || [pb availableTypeFromArray:@[NSPasteboardTypeString]];
    }
    return NO;
}

- (BOOL)canCut {
    /* We can cut if we are editable, we have at least one byte selected, and we are not in overwrite mode */
    HFController *controller = [self controller];
    if ([controller editMode] != HFInsertMode) return NO;
    if (! [controller editable]) return NO;
    
    for(HFRangeWrapper *rangeWrapper in [controller selectedContentsRanges]) {
        if ([rangeWrapper HFRange].length > 0) return YES; //we have something selected
    }
    return NO; // we did not find anything selected
}

- (BOOL)pasteBytesFromPasteboard:(NSPasteboard *)pb {
    REQUIRE_NOT_NULL(pb);
    BOOL result = NO;
    HFByteArray *byteArray = [HFPasteboardOwner unpackByteArrayFromPasteboard:pb];
    if (byteArray) {
        [[self controller] insertByteArray:byteArray replacingPreviousBytes:0 allowUndoCoalescing:NO];
        result = YES;
    }
    else {
        NSString *stringType = [pb availableTypeFromArray:@[NSPasteboardTypeString]];
        if (stringType) {
            NSString *stringValue = [pb stringForType:stringType];
            if (stringValue) {
                NSData *data = [self dataFromPasteboardString:stringValue];
                if (data) {
                    [[self controller] insertData:data replacingPreviousBytes:0 allowUndoCoalescing:NO];
                }
            }
        }
    }
    return result;
}

- (void)representerTextView:(HFRepresenterTextView * __unused)sender menu:(NSMenu *)menu forEvent:(NSEvent * __unused)event atPosition:(NSUInteger)position {
    BOOL add = YES;
    for (NSInteger i = 0; i < menu.numberOfItems; i++) {
        NSMenuItem *item = [menu itemAtIndex:i];
        if (item.action == @selector(highlightSelection:)) {
            add = NO;
            break;
        }
    }
    if (!add) {
        return;
    }
    if (menu.numberOfItems > 0) {
        [menu addItem:[NSMenuItem separatorItem]];
    }
    NSMenuItem *menuItem;
    menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Highlight Selection", nil) action:@selector(highlightSelection:) keyEquivalent:@""];
    menuItem.target = self;
    NSArray *ranges = self.controller.selectedContentsRanges;
    _clickedLocation = position;
    BOOL clickedOnColorRange = NO;
    for (HFColorRange *colorRange in self.controller.colorRanges) {
        if (HFLocationInRange(_clickedLocation, colorRange.range.HFRange)) {
            clickedOnColorRange = YES;
            break;
        }
    }
    BOOL canHighlightSelection = ranges.count > 0 && [(HFRangeWrapper *)ranges[0] HFRange].length > 0;
    menuItem.enabled = canHighlightSelection;
    [menu addItem:menuItem];
    menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Remove Highlight", nil) action:@selector(removeHighlight:) keyEquivalent:@""];
    menuItem.target = self;
    menuItem.enabled = clickedOnColorRange;
    [menu addItem:menuItem];
    menuItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Remove All Highlights", nil) action:@selector(removeAllHighlights:) keyEquivalent:@""];
    menuItem.target = self;
    menuItem.enabled = self.controller.colorRanges.count > 0;
    [menu addItem:menuItem];
}
#endif

- (void)highlightSelection:(id __unused)sender {
    HFColorRange *range = [[HFColorRange alloc] init];
    range.range = self.controller.selectedContentsRanges[0];
    [self.controller.colorRanges addObject:range];
#if !TARGET_OS_IPHONE
    NSColorPanel *panel = [NSColorPanel sharedColorPanel];
    id windowObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSWindowWillCloseNotification object:panel queue:nil usingBlock:^(NSNotification *note __unused) {
        [NSApp stopModal];
    }];
    id colorObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSColorPanelColorDidChangeNotification object:panel queue:nil usingBlock:^(NSNotification * __unused note) {
        range.color = panel.color;
        [self.controller colorRangesDidChange];
    }];
    panel.continuous = YES;
    (void)[NSApp runModalForWindow:panel];
    [[NSNotificationCenter defaultCenter] removeObserver:colorObserver];
    [[NSNotificationCenter defaultCenter] removeObserver:windowObserver];
#endif
}

- (void)removeHighlight:(id __unused)sender {
    NSEnumerator *enumerator = [self.controller.colorRanges reverseObjectEnumerator];
    HFColorRange *colorRangeToRemove = nil;
    for (HFColorRange *colorRange in enumerator) {
        if (HFLocationInRange(_clickedLocation, colorRange.range.HFRange)) {
            colorRangeToRemove = colorRange;
            break;
        }
    }
    if (colorRangeToRemove) {
        [self.controller.colorRanges removeObject:colorRangeToRemove];
        [self.controller colorRangesDidChange];
    }
}

- (void)removeAllHighlights:(id __unused)sender {
    [self.controller.colorRanges removeAllObjects];
}

@end

