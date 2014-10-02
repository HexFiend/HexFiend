//
//  HFTextRepresenter.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFTextRepresenter_Internal.h>
#import <HexFiend/HFRepresenterTextView.h>
#import <HexFiend/HFPasteboardOwner.h>
#import <HexFiend/HFByteArray.h>
#import <HexFiend/HFByteRangeAttributeArray.h>
#import <HexFiend/HFTextVisualStyleRun.h>
#import <HexFiend/HFByteRangeAttribute.h>

@implementation HFTextRepresenter

- (Class)_textViewClass {
    UNIMPLEMENTED();
}

- (instancetype)init {
    self = [super init];
    
    NSColor *color1 = [NSColor colorWithCalibratedWhite:1.0 alpha:1.0];
    NSColor *color2 = [NSColor colorWithCalibratedRed:.87 green:.89 blue:1. alpha:1.];
    _rowBackgroundColors = [@[color1, color2] retain];
    
    return self;
}

- (void)dealloc {
    if ([self isViewLoaded]) {
        [[self view] clearRepresenter];
    }
    [_rowBackgroundColors release];
    [super dealloc];
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
    _rowBackgroundColors = [[coder decodeObjectForKey:@"HFRowBackgroundColors"] retain];
    return self;
}

- (NSView *)createView {
    HFRepresenterTextView *view = [[[self _textViewClass] alloc] initWithRepresenter:self];
    [view setAutoresizingMask:NSViewHeightSizable];
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

- (NSRect)furthestRectOnEdge:(NSRectEdge)edge forByteRange:(HFRange)byteRange {
    HFASSERT(byteRange.length > 0);
    HFRange displayedRange = [self entireDisplayedRange];
    HFRange intersection = HFIntersectionRange(displayedRange, byteRange);
    NSRect result;
    if (intersection.length > 0) {
        NSRange intersectionNSRange = NSMakeRange(ll2l(intersection.location - displayedRange.location), ll2l(intersection.length));
        if (intersectionNSRange.length > 0) {
            result = [[self view] furthestRectOnEdge:edge forRange:intersectionNSRange];
        }
    }
    else if (byteRange.location < displayedRange.location) {
        /* We're below it. */
        return NSMakeRect(-CGFLOAT_MAX, -CGFLOAT_MAX, 0, 0);
    }
    else if (byteRange.location >= HFMaxRange(displayedRange)) {
        /* We're above it */
        return NSMakeRect(CGFLOAT_MAX, CGFLOAT_MAX, 0, 0);
    }
    else {
        /* Shouldn't be possible to get here */
        [NSException raise:NSInternalInconsistencyException format:@"furthestRectOnEdge: expected an intersection, or a range below or above the byte range, but nothin'"];
    }
    return result;
}

- (NSPoint)locationOfCharacterAtByteIndex:(unsigned long long)index {
    NSPoint result;
    HFRange displayedRange = [self entireDisplayedRange];
    if (HFLocationInRange(index, displayedRange) || index == HFMaxRange(displayedRange)) {
        NSUInteger location = ll2l(index - displayedRange.location);
        result = [[self view] originForCharacterAtByteIndex:location];
    }
    else if (index < displayedRange.location) {
        result = NSMakePoint(-CGFLOAT_MAX, -CGFLOAT_MAX);
    }
    else {
        result = NSMakePoint(CGFLOAT_MAX, CGFLOAT_MAX);
    }
    return result;
}

- (HFTextVisualStyleRun *)styleForAttributes:(NSSet *)attributes range:(NSRange)range {
    HFTextVisualStyleRun *run = [[[HFTextVisualStyleRun alloc] init] autorelease];
    [run setRange:range];
    if ([attributes containsObject:kHFAttributeMagic]) {
        [run setForegroundColor:[NSColor blueColor]];
        [run setBackgroundColor:[NSColor orangeColor]];
    }
    else {
        [run setForegroundColor:[NSColor blackColor]];
    }
    if ([attributes containsObject:kHFAttributeUnmapped]) {
        [run setShouldDraw:NO];
    }
    if ([attributes containsObject:kHFAttributeUnreadable]) {
        [run setBackgroundColor:[NSColor colorWithCalibratedWhite:.5 alpha:.5]];
    }
    else if ([attributes containsObject:kHFAttributeWritable]) {
        [run setBackgroundColor:[NSColor colorWithCalibratedRed:.5 green:1. blue:.5 alpha:.5]];
    }
    else if ([attributes containsObject:kHFAttributeExecutable]) {
        [run setBackgroundColor:[NSColor colorWithCalibratedRed:1. green:.5 blue:0. alpha:.5]];
    }
    if ([attributes containsObject:kHFAttributeFocused]) {
        [run setBackgroundColor:[NSColor colorWithCalibratedRed:(CGFloat)128/255. green:(CGFloat)0/255. blue:0/255. alpha:1.]];
        [run setScale:1.15];
        [run setForegroundColor:[NSColor whiteColor]];
    }
    else if ([attributes containsObject:kHFAttributeDiffInsertion]) {
        CGFloat white = 180;
        [run setBackgroundColor:[NSColor colorWithCalibratedRed:(CGFloat)255./255. green:(CGFloat)white/255. blue:white/255. alpha:.7]];
    }
    
    /* Process bookmarks */
    NSMutableIndexSet *bookmarkExtents = nil;
    FOREACH(NSString *, attribute, attributes) {
        NSInteger bookmark = HFBookmarkFromBookmarkAttribute(attribute);
        if (bookmark != NSNotFound) {
            if (! bookmarkExtents) bookmarkExtents = [[NSMutableIndexSet alloc] init];
            [bookmarkExtents addIndex:bookmark];
        }
    }
    
    if (bookmarkExtents) {
        [run setBookmarkExtents:bookmarkExtents];
        [bookmarkExtents release];
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

- (void)updateText {
    HFController *controller = [self controller];
    HFRepresenterTextView *view = [self view];
    HFRange entireDisplayedRange = [self entireDisplayedRange];
    [view setData:[controller dataForRange:entireDisplayedRange]];
    [view setStyles:[self stylesForRange:entireDisplayedRange]];
    HFFPRange lineRange = [controller displayedLineRange];
    long double offsetLongDouble = lineRange.location - floorl(lineRange.location);
    CGFloat offset = ld2f(offsetLongDouble);
    [view setVerticalOffset:offset];
    [view setStartingLineBackgroundColorIndex:ll2l(HFFPToUL(floorl(lineRange.location)) % NSUIntegerMax)];
}

- (void)initializeView {
    [super initializeView];
    HFRepresenterTextView *view = [self view];
    HFController *controller = [self controller];
    if (controller) {
        [view setFont:[controller font]];
        [view setEditable:[controller editable]];
        [self updateText];
    }
    else {
        [view setFont:[NSFont fontWithName:HFDEFAULT_FONT size:HFDEFAULT_FONTSIZE]];
    }
}

- (void)scrollWheel:(NSEvent *)event {
    [[self controller] scrollWithScrollEvent:event];
}

- (void)selectAll:(id)sender {
    [[self controller] selectAll:sender];
}

- (double)selectionPulseAmount {
    return [[self controller] selectionPulseAmount];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerFont | HFControllerLineHeight)) {
        [[self view] setFont:[[self controller] font]];
    }
    if (bits & (HFControllerContentValue | HFControllerDisplayedLineRange | HFControllerByteRangeAttributes)) {
        [self updateText];
    }
    if (bits & (HFControllerSelectedRanges | HFControllerDisplayedLineRange)) {
        [[self view] updateSelectedRanges];
    }
    if (bits & (HFControllerSelectionPulseAmount)) {
        [[self view] updateSelectionPulse];
    }
    if (bits & (HFControllerEditable)) {
        [[self view] setEditable:[[self controller] editable]];
    }
    if (bits & (HFControllerAntialias)) {
        [[self view] setShouldAntialias:[[self controller] shouldAntialias]];
    }
    if (bits & (HFControllerShowCallouts)) {
        [[self view] setShouldDrawCallouts:[[self controller] shouldShowCallouts]];
    }
    if (bits & (HFControllerBookmarks | HFControllerDisplayedLineRange | HFControllerContentValue)) {
        [[self view] setBookmarks:[self displayedBookmarkLocations]];
    }
    if (bits & (HFControllerColorBytes)) {
        if([[self controller] shouldColorBytes]) {
            [[self view] setByteColoring: ^(uint8_t byte, uint8_t *r, uint8_t *g, uint8_t *b, uint8_t *a){
                *r = *g = *b = (uint8_t)(255 * ((255-byte)/255.0*0.6+0.4));
                *a = (uint8_t)(255 * 0.7);
            }];
        } else {
            [[self view] setByteColoring:NULL];
        }
    }
    [super controllerDidChange:bits];
}

- (double)maximumAvailableLinesForViewHeight:(CGFloat)viewHeight {
    return [[self view] maximumAvailableLinesForViewHeight:viewHeight];
}

- (NSUInteger)maximumBytesPerLineForViewWidth:(CGFloat)viewWidth {
    return [[self view] maximumBytesPerLineForViewWidth:viewWidth];
}

- (CGFloat)minimumViewWidthForBytesPerLine:(NSUInteger)bytesPerLine {
    return [[self view] minimumViewWidthForBytesPerLine:bytesPerLine];
}

- (NSUInteger)byteGranularity {
    HFRepresenterTextView *view = [self view];
    NSUInteger bytesPerColumn = MAX([view bytesPerColumn], 1u), bytesPerCharacter = [view bytesPerCharacter];
    return HFLeastCommonMultiple(bytesPerColumn, bytesPerCharacter);
}

- (NSArray *)displayedSelectedContentsRanges {
    HFController *controller = [self controller];
    NSArray *result;
    NSArray *selectedRanges = [controller selectedContentsRanges];
    HFRange displayedRange = [self entireDisplayedRange];
    
    HFASSERT(displayedRange.length <= NSUIntegerMax);
    NEW_ARRAY(NSValue *, clippedSelectedRanges, [selectedRanges count]);
    NSUInteger clippedRangeIndex = 0;
    FOREACH(HFRangeWrapper *, wrapper, selectedRanges) {
        HFRange selectedRange = [wrapper HFRange];
        BOOL clippedRangeIsVisible;
        NSRange clippedSelectedRange;
        /* Necessary because zero length ranges do not intersect anything */
        if (selectedRange.length == 0) {
            /* Remember that {6, 0} is considered a subrange of {3, 3} */
            clippedRangeIsVisible = HFRangeIsSubrangeOfRange(selectedRange, displayedRange);
            if (clippedRangeIsVisible) {
                HFASSERT(selectedRange.location >= displayedRange.location);
                clippedSelectedRange.location = ll2l(selectedRange.location - displayedRange.location);
                clippedSelectedRange.length = 0;
            }
        }
        else {
            // selectedRange.length > 0
            clippedRangeIsVisible = HFIntersectsRange(selectedRange, displayedRange);
            if (clippedRangeIsVisible) {
                HFRange intersectionRange = HFIntersectionRange(selectedRange, displayedRange);
                HFASSERT(intersectionRange.location >= displayedRange.location);
                clippedSelectedRange.location = ll2l(intersectionRange.location - displayedRange.location);
                clippedSelectedRange.length = ll2l(intersectionRange.length);
            }
        }
        if (clippedRangeIsVisible) clippedSelectedRanges[clippedRangeIndex++] = [NSValue valueWithRange:clippedSelectedRange];
    }
    result = [NSArray arrayWithObjects:clippedSelectedRanges count:clippedRangeIndex];
    FREE_ARRAY(clippedSelectedRanges);
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
            [key release];
            [value release];
        }
    }
    return result;
}

- (unsigned long long)byteIndexForCharacterIndex:(NSUInteger)characterIndex {
    HFController *controller = [self controller];
    HFFPRange lineRange = [controller displayedLineRange];
    unsigned long long scrollAmount = HFFPToUL(floorl(lineRange.location));
    unsigned long long byteIndex = HFProductULL(scrollAmount, [controller bytesPerLine]) + characterIndex * [[self view] bytesPerCharacter];
    return byteIndex;
}

- (void)beginSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] beginSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}

- (void)continueSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] continueSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}

- (void)endSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex {
    [[self controller] endSelectionWithEvent:event forByteIndex:[self byteIndexForCharacterIndex:characterIndex]];
}

- (void)insertText:(NSString *)text {
    USE(text);
    UNIMPLEMENTED_VOID();
}

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
        return [HFPasteboardOwner unpackByteArrayFromPasteboard:pb] || [pb availableTypeFromArray:@[NSStringPboardType]];
    }
    return NO;
}

- (BOOL)canCut {
    /* We can cut if we are editable, we have at least one byte selected, and we are not in overwrite mode */
    HFController *controller = [self controller];
    if ([controller editMode] != HFInsertMode) return NO;
    if (! [controller editable]) return NO;
    
    FOREACH(HFRangeWrapper *, rangeWrapper, [controller selectedContentsRanges]) {
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
        NSString *stringType = [pb availableTypeFromArray:@[NSStringPboardType]];
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

@end
