//
//  HFController.m
//  HexFiend_2
//
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFController.h>
#import <HexFiend/HFRepresenter_Internal.h>
#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFFullMemoryByteArray.h>
#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFAttributedByteArray.h>
#import <HexFiend/HFByteRangeAttribute.h>
#import <HexFiend/HFFullMemoryByteSlice.h>
#import <HexFiend/HFControllerCoalescedUndo.h>
#import <HexFiend/HFSharedMemoryByteSlice.h>
#import <HexFiend/HFRandomDataByteSlice.h>
#import <HexFiend/HFFileReference.h>
#import <HexFiend/HFByteRangeAttributeArray.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <objc/objc-auto.h>

/* Used for the anchor range and location */
#define NO_SELECTION ULLONG_MAX

#if ! NDEBUG
#define VALIDATE_SELECTION() [self _ensureSelectionIsValid]
#else
#define VALIDATE_SELECTION() do { } while (0)
#endif

#define BENCHMARK_BYTEARRAYS 0

#define BEGIN_TRANSACTION() NSUInteger token = [self beginPropertyChangeTransaction]
#define END_TRANSACTION() [self endPropertyChangeTransaction:token]

static const CGFloat kScrollMultiplier = (CGFloat)1.5;

static const CFTimeInterval kPulseDuration = .2;

static void *KVOContextChangesAreLocked = &KVOContextChangesAreLocked;

NSString * const HFPrepareForChangeInFileNotification = @"HFPrepareForChangeInFileNotification";
NSString * const HFChangeInFileByteArrayKey = @"HFChangeInFileByteArrayKey";
NSString * const HFChangeInFileModifiedRangesKey = @"HFChangeInFileModifiedRangesKey";
NSString * const HFChangeInFileShouldCancelKey = @"HFChangeInFileShouldCancelKey";
NSString * const HFChangeInFileHintKey = @"HFChangeInFileHintKey";

NSString * const HFControllerDidChangePropertiesNotification = @"HFControllerDidChangePropertiesNotification";
NSString * const HFControllerChangedPropertiesKey = @"HFControllerChangedPropertiesKey";


typedef enum {
    eSelectResult,
    eSelectAfterResult,
    ePreserveSelection,
    NUM_SELECTION_ACTIONS
} SelectionAction_t;

@interface HFController (ForwardDeclarations)
- (void)_commandInsertByteArrays:(NSArray *)byteArrays inRanges:(NSArray *)ranges withSelectionAction:(SelectionAction_t)selectionAction;
- (void)_endTypingUndoCoalescingIfActive;
- (void)_removeUndoManagerNotifications;
- (void)_removeAllUndoOperations;
- (void)_registerUndoOperationForInsertingByteArrays:(NSArray *)byteArrays inRanges:(NSArray *)ranges withSelectionAction:(SelectionAction_t)selectionAction;

- (void)_updateBytesPerLine;
- (void)_updateDisplayedRange;
@end

@interface NSEvent (HFLionStuff)
- (CGFloat)scrollingDeltaY;
- (BOOL)hasPreciseScrollingDeltas;
- (CGFloat)deviceDeltaY;
@end

static inline Class preferredByteArrayClass(void) {
    return [HFAttributedByteArray class];
}

@implementation HFController

- (void)_sharedInit {
    selectedContentsRanges = [[NSMutableArray alloc] initWithObjects:[HFRangeWrapper withRange:HFRangeMake(0, 0)], nil];
    byteArray = [[preferredByteArrayClass() alloc] init];
    [byteArray addObserver:self forKeyPath:@"changesAreLocked" options:0 context:KVOContextChangesAreLocked];
    selectionAnchor = NO_SELECTION;
    undoOperations = [[NSMutableSet alloc] init];
}

- (id)init {
    self = [super init];
    [self _sharedInit];
    bytesPerLine = 16;
    bytesPerColumn = 1;
    _hfflags.editable = YES;
    _hfflags.antialias = YES;
    _hfflags.selectable = YES;
    representers = [[NSMutableArray alloc] init];
    [self setFont:[NSFont fontWithName:@"Monaco" size:10.f]];
    return self;
}

- (void)dealloc {
    [representers makeObjectsPerformSelector:@selector(_setController:) withObject:nil];
    [representers release];
    [selectedContentsRanges release];
    [self _removeUndoManagerNotifications];
    [self _removeAllUndoOperations];
    [undoOperations release];
    [undoManager release];
    [undoCoalescer release];
    [font release];
    [byteArray removeObserver:self forKeyPath:@"changesAreLocked"];
    [byteArray release];
    [cachedData release];
    [additionalPendingTransactions release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [coder encodeObject:representers forKey:@"HFRepresenters"];
    [coder encodeInt64:bytesPerLine forKey:@"HFBytesPerLine"];
    [coder encodeInt64:bytesPerColumn forKey:@"HFBytesPerColumn"];
    [coder encodeObject:font forKey:@"HFFont"];
    [coder encodeDouble:lineHeight forKey:@"HFLineHeight"];
    [coder encodeBool:_hfflags.antialias forKey:@"HFAntialias"];
    [coder encodeInt:_hfflags.editMode forKey:@"HFEditMode"];
    [coder encodeBool:_hfflags.editable forKey:@"HFEditable"];
    [coder encodeBool:_hfflags.selectable forKey:@"HFSelectable"];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super init];
    [self _sharedInit];
    bytesPerLine = (NSUInteger)[coder decodeInt64ForKey:@"HFBytesPerLine"];
    bytesPerColumn = (NSUInteger)[coder decodeInt64ForKey:@"HFBytesPerColumn"];
    font = [[coder decodeObjectForKey:@"HFFont"] retain];
    lineHeight = (CGFloat)[coder decodeDoubleForKey:@"HFLineHeight"];
    _hfflags.antialias = [coder decodeBoolForKey:@"HFAntialias"];
    
    if ([coder containsValueForKey:@"HFEditMode"])
        _hfflags.editMode = [coder decodeIntForKey:@"HFEditMode"];
    else {
        _hfflags.editMode = ([coder decodeBoolForKey:@"HFOverwriteMode"]
                             ? HFOverwriteMode : HFInsertMode);
    }

    _hfflags.editable = [coder decodeBoolForKey:@"HFEditable"];
    _hfflags.selectable = [coder decodeBoolForKey:@"HFSelectable"];
    representers = [[coder decodeObjectForKey:@"HFRepresenters"] retain];
    return self;
}

- (NSArray *)representers {
    return [NSArray arrayWithArray:representers];
}

- (void)notifyRepresentersOfChanges:(HFControllerPropertyBits)bits {
    FOREACH(HFRepresenter*, rep, representers) {
        [rep controllerDidChange:bits];
    }
    
    /* Post the HFControllerDidChangePropertiesNotification */
#if __LP64__
    NSNumber *number = [[NSNumber alloc] initWithUnsignedInteger:bits];
#else
    NSNumber *number = [[NSNumber alloc] initWithUnsignedInt:bits];
#endif
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjects:&number forKeys:(id *)&HFControllerChangedPropertiesKey count:1];
    [number release];
    [[NSNotificationCenter defaultCenter] postNotificationName:HFControllerDidChangePropertiesNotification object:self userInfo:userInfo];
    [userInfo release];
}

- (void)_firePropertyChanges {
    NSMutableArray *pendingTransactions = additionalPendingTransactions;
    NSUInteger pendingTransactionCount = [pendingTransactions count];
    additionalPendingTransactions = nil;
    HFControllerPropertyBits propertiesToUpdate = propertiesToUpdateInCurrentTransaction;
    propertiesToUpdateInCurrentTransaction = 0;
    if (pendingTransactionCount > 0 || propertiesToUpdate != 0) {
        BEGIN_TRANSACTION();
        while (pendingTransactionCount--) {
#if __LP64__
            HFControllerPropertyBits propertiesInThisTransaction = [[pendingTransactions objectAtIndex:0] unsignedIntegerValue];
#else
            HFControllerPropertyBits propertiesInThisTransaction = [[pendingTransactions objectAtIndex:0] unsignedIntValue];
#endif
            [pendingTransactions removeObjectAtIndex:0];
            HFASSERT(propertiesInThisTransaction != 0);
            [self notifyRepresentersOfChanges:propertiesInThisTransaction];
        }
        [pendingTransactions release];
        if (propertiesToUpdate) {
            [self notifyRepresentersOfChanges:propertiesToUpdate];
        }
        END_TRANSACTION();
    }
}

/* Inserts a "fence" so that all prior property change bits will be complete before any new ones */
- (void)_insertPropertyChangeFence {
    if (currentPropertyChangeToken == 0) {
        HFASSERT(additionalPendingTransactions == nil);
        /* There can be no prior property changes */
        HFASSERT(propertiesToUpdateInCurrentTransaction == 0);
        return;
    }
    if (propertiesToUpdateInCurrentTransaction == 0) {
        /* Nothing to fence */
        return;
    }
    if (additionalPendingTransactions == nil) additionalPendingTransactions = [[NSMutableArray alloc] init];
    [additionalPendingTransactions addObject:[NSNumber numberWithUnsignedInteger:propertiesToUpdateInCurrentTransaction]];
    propertiesToUpdateInCurrentTransaction = 0;
}

- (void)_addPropertyChangeBits:(HFControllerPropertyBits)bits {
    propertiesToUpdateInCurrentTransaction |= bits;
    if (currentPropertyChangeToken == 0) {
        [self _firePropertyChanges];
    }
}

- (NSUInteger)beginPropertyChangeTransaction {
    HFASSERT(currentPropertyChangeToken < NSUIntegerMax);
    return ++currentPropertyChangeToken;
}

- (void)endPropertyChangeTransaction:(NSUInteger)token {
    if (currentPropertyChangeToken != token) {
        [NSException raise:NSInvalidArgumentException format:@"endPropertyChangeTransaction passed token %lu, but expected token %lu", (unsigned long)token, (unsigned long)currentPropertyChangeToken];
    }
    HFASSERT(currentPropertyChangeToken > 0);
    if (--currentPropertyChangeToken == 0) [self _firePropertyChanges];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (context == KVOContextChangesAreLocked) {
        HFASSERT([keyPath isEqual:@"changesAreLocked"]);
        [self _addPropertyChangeBits:HFControllerEditable];
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)addRepresenter:(HFRepresenter *)representer {
    REQUIRE_NOT_NULL(representer);
    HFASSERT([representers indexOfObjectIdenticalTo:representer] == NSNotFound);
    HFASSERT([representer controller] == nil);
    [representer _setController:self];
    [representers addObject:representer];
    [representer controllerDidChange: -1];
}

- (void)removeRepresenter:(HFRepresenter *)representer {
    REQUIRE_NOT_NULL(representer);    
    HFASSERT([representers indexOfObjectIdenticalTo:representer] != NSNotFound);
    [representers removeObjectIdenticalTo:representer];
    [representer _setController:nil];
}

- (HFRange)_maximumDisplayedRangeSet {
    unsigned long long contentsLength = [self contentsLength];
    HFRange maximumDisplayedRangeSet = HFRangeMake(0, HFRoundUpToNextMultipleSaturate(contentsLength, bytesPerLine));
    return maximumDisplayedRangeSet;
}

- (unsigned long long)totalLineCount {
    return HFDivideULLRoundingUp(HFRoundUpToNextMultipleSaturate([self contentsLength], bytesPerLine), bytesPerLine);
}

- (HFFPRange)displayedLineRange {
#if ! NDEBUG
    HFASSERT(displayedLineRange.location >= 0);
    HFASSERT(displayedLineRange.length >= 0);
    HFASSERT(displayedLineRange.location + displayedLineRange.length <= HFULToFP([self totalLineCount]));
#endif
    return displayedLineRange;
}

- (void)setDisplayedLineRange:(HFFPRange)range {
#if ! NDEBUG
    HFASSERT(range.location >= 0);
    HFASSERT(range.length >= 0);
    HFASSERT(range.location + range.length <= HFULToFP([self totalLineCount]));
#endif
    if (! HFFPRangeEqualsRange(range, displayedLineRange)) {
        displayedLineRange = range;
        [self _addPropertyChangeBits:HFControllerDisplayedLineRange];
    }
}

- (CGFloat)lineHeight {
    return lineHeight;
}

- (NSFont *)font {
    return font;
}

- (void)setFont:(NSFont *)val {
    if (val != font) {
        CGFloat priorLineHeight = [self lineHeight];
        
        [font release];
        font = [val copy];
        
        NSLayoutManager *manager = [[NSLayoutManager alloc] init];
        lineHeight = [manager defaultLineHeightForFont:font];
        [manager release];
        
        HFControllerPropertyBits bits = HFControllerFont;
        if (lineHeight != priorLineHeight) bits |= HFControllerLineHeight;
        [self _addPropertyChangeBits:bits];
        [self _insertPropertyChangeFence];
        [self _addPropertyChangeBits:HFControllerViewSizeRatios];
        [self _updateDisplayedRange];
    }
}

- (BOOL)shouldAntialias {
    return _hfflags.antialias;
}

- (void)setShouldAntialias:(BOOL)antialias {
    antialias = !! antialias;
    if (antialias != _hfflags.antialias) {
        _hfflags.antialias = antialias;
        [self _addPropertyChangeBits:HFControllerAntialias];
    }
}

- (void)setBytesPerColumn:(NSUInteger)val {
    if (val != bytesPerColumn) {
        bytesPerColumn = val;
        [self _addPropertyChangeBits:HFControllerBytesPerColumn];
    }
}

- (NSUInteger)bytesPerColumn {
    return bytesPerColumn;
}

- (BOOL)_shouldInvertSelectedRangesByAnchorRange {
    return _hfflags.selectionInProgress && _hfflags.commandExtendSelection;
}

- (NSArray *)_invertedSelectedContentsRanges {
    HFASSERT([selectedContentsRanges count] > 0);
    HFASSERT(selectionAnchorRange.location != NO_SELECTION);
    if (selectionAnchorRange.length == 0) return [NSArray arrayWithArray:selectedContentsRanges];
    
    NSArray *cleanedRanges = [HFRangeWrapper organizeAndMergeRanges:selectedContentsRanges];
    NSMutableArray *result = [NSMutableArray array];
    
    /* Our algorithm works as follows - add any ranges outside of the selectionAnchorRange, clipped by the selectionAnchorRange.  Then extract every "index" in our cleaned selected arrays that are within the selectionAnchorArray.  An index is the location where a range starts or stops.  Then use those indexes to create the inverted arrays.  A range parity of 1 means that we are adding the range. */
    
    /* Add all the ranges that are outside of selectionAnchorRange, clipping them if necessary */
    HFASSERT(HFSumDoesNotOverflow(selectionAnchorRange.location, selectionAnchorRange.length));
    FOREACH(HFRangeWrapper*, outsideWrapper, cleanedRanges) {
        HFRange range = [outsideWrapper HFRange];
        if (range.location < selectionAnchorRange.location) {
            HFRange clippedRange;
            clippedRange.location = range.location;
            HFASSERT(MIN(HFMaxRange(range), selectionAnchorRange.location) >= clippedRange.location);
            clippedRange.length = MIN(HFMaxRange(range), selectionAnchorRange.location) - clippedRange.location;
            [result addObject:[HFRangeWrapper withRange:clippedRange]];
        }
        if (HFMaxRange(range) > HFMaxRange(selectionAnchorRange)) {
            HFRange clippedRange;
            clippedRange.location = MAX(range.location, HFMaxRange(selectionAnchorRange));
            HFASSERT(HFMaxRange(range) >= clippedRange.location);
            clippedRange.length = HFMaxRange(range) - clippedRange.location;
            [result addObject:[HFRangeWrapper withRange:clippedRange]];
        }
    }
    
    HFASSERT(HFSumDoesNotOverflow(selectionAnchorRange.location, selectionAnchorRange.length));
    
    NEW_ARRAY(unsigned long long, partitions, 2*[cleanedRanges count] + 2);
    NSUInteger partitionCount, partitionIndex = 0;
    
    partitions[partitionIndex++] = selectionAnchorRange.location;
    FOREACH(HFRangeWrapper*, wrapper, cleanedRanges) {
        HFRange range = [wrapper HFRange];
        if (! HFIntersectsRange(range, selectionAnchorRange)) continue;
        
        partitions[partitionIndex++] = MAX(selectionAnchorRange.location, range.location);
        partitions[partitionIndex++] = MIN(HFMaxRange(selectionAnchorRange), HFMaxRange(range));
    }
    
    // For some reason, using HFMaxRange confuses the static analyzer
    partitions[partitionIndex++] = HFSum(selectionAnchorRange.location, selectionAnchorRange.length);
    
    partitionCount = partitionIndex;
    HFASSERT((partitionCount % 2) == 0);
    
    partitionIndex = 0;
    while (partitionIndex < partitionCount) {
        HFASSERT(partitionIndex + 1 < partitionCount);
        HFASSERT(partitions[partitionIndex] <= partitions[partitionIndex + 1]);
        if (partitions[partitionIndex] < partitions[partitionIndex + 1]) {
            HFRange range = HFRangeMake(partitions[partitionIndex], partitions[partitionIndex + 1] - partitions[partitionIndex]);
            [result addObject:[HFRangeWrapper withRange:range]];
        }
        partitionIndex += 2;
    }
    
    FREE_ARRAY(partitions);
    
    if ([result count] == 0) [result addObject:[HFRangeWrapper withRange:HFRangeMake(selectionAnchor, 0)]];
    
    return [HFRangeWrapper organizeAndMergeRanges:result];
}

#if ! NDEBUG
- (void)_ensureSelectionIsValid {
    HFASSERT(selectedContentsRanges != nil);
    HFASSERT([selectedContentsRanges count] > 0);
    BOOL onlyOneWrapper = ([selectedContentsRanges count] == 1);
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        EXPECT_CLASS(wrapper, HFRangeWrapper);
        HFRange range = [wrapper HFRange];
        HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
        if (onlyOneWrapper == NO) HFASSERT(range.length > 0); /* If we have more than one wrapper, then none of them should be zero length */
    }
}
#endif

- (void)_setSingleSelectedContentsRange:(HFRange)newSelection {
    HFASSERT(HFRangeIsSubrangeOfRange(newSelection, HFRangeMake(0, [self contentsLength])));
    BOOL selectionChanged;
    if ([selectedContentsRanges count] == 1) {
        selectionChanged = ! HFRangeEqualsRange([[selectedContentsRanges objectAtIndex:0] HFRange], newSelection);
    }
    else {
        selectionChanged = YES;
    }
    
    if (selectionChanged) {
        [selectedContentsRanges removeAllObjects];
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:newSelection]];
        [self _addPropertyChangeBits:HFControllerSelectedRanges];
    }
    VALIDATE_SELECTION();
}

- (NSArray *)selectedContentsRanges {
    VALIDATE_SELECTION();
    if ([self _shouldInvertSelectedRangesByAnchorRange]) return [self _invertedSelectedContentsRanges];
    else return [NSArray arrayWithArray:selectedContentsRanges];
}

- (unsigned long long)contentsLength {
    if (! byteArray) return 0;
    else return [byteArray length];
}

- (NSData *)dataForRange:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax); // it doesn't make sense to ask for a buffer larger than can be stored in memory
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
    
    NSUInteger newGenerationIndex = [byteArray changeGenerationCount];
    if (cachedData == nil || newGenerationIndex != cachedGenerationIndex || ! HFRangeIsSubrangeOfRange(range, cachedRange)) {
        [cachedData release];
        cachedGenerationIndex = newGenerationIndex;
        cachedRange = range;
        NSUInteger length = ll2l(range.length);
        unsigned char *data = check_malloc(length);
        [byteArray copyBytes:data range:range];
        cachedData = [[NSData alloc] initWithBytesNoCopy:data length:length freeWhenDone:YES];
    }
    
    if (HFRangeEqualsRange(range, cachedRange)) {
        return cachedData;
    }
    else {
        HFASSERT(cachedRange.location <= range.location);
        NSRange cachedDataSubrange;
        cachedDataSubrange.location = ll2l(range.location - cachedRange.location);
        cachedDataSubrange.length = ll2l(range.length);
        return [cachedData subdataWithRange:cachedDataSubrange];
    }
}

- (void)copyBytes:(unsigned char *)bytes range:(HFRange)range {
    HFASSERT(range.length <= NSUIntegerMax); // it doesn't make sense to ask for a buffer larger than can be stored in memory
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
    [byteArray copyBytes:bytes range:range];
}

- (HFByteRangeAttributeArray *)byteRangeAttributeArray {
    return [byteArray byteRangeAttributeArray];
}

- (HFByteRangeAttributeArray *)attributesForBytesInRange:(HFRange)range {
    return [[self byteArray] attributesForBytesInRange:range];
}

- (HFRange)rangeForBookmark:(NSInteger)bookmark {
    HFRange result = HFRangeMake(ULLONG_MAX, ULLONG_MAX);
    HFByteRangeAttributeArray *attributes = [byteArray byteRangeAttributeArray];
    if (attributes != nil) {
        NSString *attribute = HFBookmarkAttributeFromBookmark(bookmark);
        result = [attributes rangeOfAttribute:attribute];
    }
    return result;
}

- (void)setRange:(HFRange)range forBookmark:(NSInteger)bookmark {
    HFASSERT(range.length > 0);
    HFByteRangeAttributeArray *attributeArray = [byteArray byteRangeAttributeArray];
    if (attributeArray) {
        
        /* Support undo */
        HFRange existingRange = [self rangeForBookmark:bookmark];
        NSUndoManager *undoer = [self undoManager];
        [[undoer prepareWithInvocationTarget:self] setRange:existingRange forBookmark:bookmark];
        [undoer setActionName:@"Bookmark"];
        
        NSString *attribute = HFBookmarkAttributeFromBookmark(bookmark);
        [attributeArray removeAttribute:attribute];
        if (! (range.location == ULLONG_MAX && range.location == ULLONG_MAX)) {
            [attributeArray addAttribute:attribute range:range];
        }
        [self _addPropertyChangeBits:HFControllerByteRangeAttributes | HFControllerBookmarks];
    }
}

- (NSIndexSet *)bookmarksInRange:(HFRange)range {
    id result = nil;
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
    HFByteRangeAttributeArray *attributeArray = [byteArray byteRangeAttributeArray]; //may be nil
    NSSet *attributes = [attributeArray attributesInRange:range];
    if (! [attributes count]) {
        result = [NSIndexSet indexSet];
    } else {
        result = [NSMutableIndexSet indexSet];
        FOREACH(NSString *, attribute, attributes) {
            NSInteger bookmark = HFBookmarkFromBookmarkAttribute(attribute);
            if (bookmark != NSNotFound) [result addIndex:bookmark];
        }
    }
    return result;
}

- (void)_updateDisplayedRange {
    HFRange proposedNewDisplayRange;
    HFFPRange proposedNewLineRange;
    HFRange maxRangeSet = [self _maximumDisplayedRangeSet];
    NSUInteger maxBytesForViewSize = NSUIntegerMax;
    double maxLines = DBL_MAX;
    FOREACH(HFRepresenter*, rep, representers) {
        NSView *view = [rep view];
        double repMaxLines = [rep maximumAvailableLinesForViewHeight:NSHeight([view frame])];
        if (repMaxLines != DBL_MAX) {
            /* bytesPerLine may be ULONG_MAX.  We want to compute the smaller of maxBytesForViewSize and ceil(repMaxLines) * bytesPerLine.  If the latter expression overflows, the smaller is the former. */
            NSUInteger repMaxLinesUInt = (NSUInteger)ceil(repMaxLines);
            NSUInteger maxLinesTimesBytesPerLine =  repMaxLinesUInt * bytesPerLine;
            /* Check if we overflowed */
            BOOL overflowed = (repMaxLinesUInt != 0 && (maxLinesTimesBytesPerLine / repMaxLinesUInt != bytesPerLine));
            if (! overflowed) {
                maxBytesForViewSize = MIN(maxLinesTimesBytesPerLine, maxBytesForViewSize);
            }
        }
        maxLines = MIN(repMaxLines, maxLines);
    }
    if (maxLines == DBL_MAX) {
        proposedNewDisplayRange = HFRangeMake(0, 0);
        proposedNewLineRange = (HFFPRange){0, 0};
    }
    else {
        unsigned long long maximumDisplayedBytes = MIN(maxRangeSet.length, maxBytesForViewSize);
        HFASSERT(HFMaxRange(maxRangeSet) >= maximumDisplayedBytes);
        
        proposedNewDisplayRange.location = MIN(HFMaxRange(maxRangeSet) - maximumDisplayedBytes, displayedContentsRange.location);
        proposedNewDisplayRange.location -= proposedNewDisplayRange.location % bytesPerLine;
        proposedNewDisplayRange.length = MIN(HFMaxRange(maxRangeSet) - proposedNewDisplayRange.location, maxBytesForViewSize);
        if (maxBytesForViewSize % bytesPerLine != 0) {
            NSLog(@"Bad max bytes: %lu (%lu)", (unsigned long)maxBytesForViewSize, (unsigned long)bytesPerLine);
        }
        if (HFMaxRange(maxRangeSet) != ULLONG_MAX && (HFMaxRange(maxRangeSet) - proposedNewDisplayRange.location) % bytesPerLine != 0) {
            NSLog(@"Bad max range minus: %llu (%lu)", HFMaxRange(maxRangeSet) - proposedNewDisplayRange.location, (unsigned long)bytesPerLine);
        }
        
        long double lastLine = HFULToFP([self totalLineCount]);
        proposedNewLineRange.length = MIN(maxLines, lastLine);
        proposedNewLineRange.location = MIN(displayedLineRange.location, lastLine - proposedNewLineRange.length);
    }
    HFASSERT(HFRangeIsSubrangeOfRange(proposedNewDisplayRange, maxRangeSet));
    HFASSERT(proposedNewDisplayRange.location % bytesPerLine == 0);
    if (! HFRangeEqualsRange(proposedNewDisplayRange, displayedContentsRange) || ! HFFPRangeEqualsRange(proposedNewLineRange, displayedLineRange)) {
        displayedContentsRange = proposedNewDisplayRange;
        displayedLineRange = proposedNewLineRange;
        [self _addPropertyChangeBits:HFControllerDisplayedLineRange];
    }
}

- (void)_ensureVisibilityOfLocation:(unsigned long long)location {
    HFASSERT(location <= [self contentsLength]);
    unsigned long long lineInt = location / bytesPerLine;
    long double line = HFULToFP(lineInt);
    HFASSERT(line >= 0);
    HFASSERT(line <= HFULToFP([self totalLineCount]));
    HFFPRange lineRange = [self displayedLineRange];
    HFFPRange newLineRange = lineRange;
    if (line < lineRange.location) {
        newLineRange.location = line;
    }
    else if (line >= lineRange.location + lineRange.length) {
        HFASSERT(lineRange.location + lineRange.length >= 1);
        newLineRange.location = lineRange.location + (line - (lineRange.location + lineRange.length - 1));
    }
    [self setDisplayedLineRange:newLineRange];
}

- (void)maximizeVisibilityOfContentsRange:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
    HFFPRange displayRange = [self displayedLineRange];
    HFFPRange newDisplayRange = displayRange;
    unsigned long long startLine = range.location / bytesPerLine;
    unsigned long long endLine = HFDivideULLRoundingUp(HFRoundUpToNextMultipleSaturate(HFMaxRange(range), bytesPerLine), bytesPerLine);
    HFASSERT(endLine > startLine || endLine == ULLONG_MAX);
    long double linesInRange = HFULToFP(endLine - startLine);
    long double linesToDisplay = MIN(displayRange.length, linesInRange);
    HFASSERT(linesToDisplay <= linesInRange);
    long double linesToMoveDownToMakeLastLineVisible = HFULToFP(endLine) - (displayRange.location + displayRange.length);
    long double linesToMoveUpToMakeFirstLineVisible = displayRange.location - HFULToFP(startLine);
    //HFASSERT(linesToMoveUpToMakeFirstLineVisible <= 0 || linesToMoveDownToMakeLastLineVisible <= 0);
    // in general, we expect either linesToMoveUpToMakeFirstLineVisible to be <= zero, or linesToMoveDownToMakeLastLineVisible to be <= zero.  However, if the available space is smaller than one line, then that won't be true.
    if (linesToMoveDownToMakeLastLineVisible > 0) {
        newDisplayRange.location += linesToMoveDownToMakeLastLineVisible;
    }
    else if (linesToMoveUpToMakeFirstLineVisible > 0 && linesToDisplay >= 1) {
        // the >= 1 check prevents some wacky behavior when we have less than one line's worth of space, that caused bouncing between the top and bottom of the line
        newDisplayRange.location -= linesToMoveUpToMakeFirstLineVisible;
    }
    [self setDisplayedLineRange:newDisplayRange];
}

- (void)centerContentsRange:(HFRange)range {
    HFASSERT(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, [self contentsLength])));
    HFFPRange displayRange = [self displayedLineRange];
    const long double numDisplayedLines = displayRange.length;
    HFFPRange newDisplayRange;
    unsigned long long startLine = range.location / bytesPerLine;
    unsigned long long endLine = HFDivideULLRoundingUp(HFRoundUpToNextMultipleSaturate(HFMaxRange(range), bytesPerLine), bytesPerLine);
    HFASSERT(endLine > startLine || endLine == ULLONG_MAX);
    long double linesInRange = HFULToFP(endLine - startLine);
    
    /* Handle the case of a line range bigger than we can display by choosing the top lines. */
    if (numDisplayedLines <= linesInRange) {
        newDisplayRange = (HFFPRange){startLine, numDisplayedLines};
    }
    else {
        /* Construct a newDisplayRange that centers {startLine, endLine} */
        long double center = startLine + (endLine - startLine) / 2.;
        newDisplayRange = (HFFPRange){center - numDisplayedLines / 2., numDisplayedLines};
    }
    
    /* Move the newDisplayRange up or down as necessary */
    newDisplayRange.location = fmaxl(newDisplayRange.location, (long double)0.);
    newDisplayRange.location = fminl(newDisplayRange.location, HFULToFP([self totalLineCount]) - numDisplayedLines);
    [self setDisplayedLineRange:newDisplayRange];
}

/* Clips the selection to a given length.  If this would clip the entire selection, returns a zero length selection at the end.  Indicates HFControllerSelectedRanges if the selection changes. */
- (void)_clipSelectedContentsRangesToLength:(unsigned long long)newLength {
    NSMutableArray *newTempSelection = [selectedContentsRanges mutableCopy];
    NSUInteger i, max = [newTempSelection count];
    for (i=0; i < max; i++) {
        HFRange range = [[newTempSelection objectAtIndex:i] HFRange];
        if (HFMaxRange(range) > newLength) {
            if (range.location > newLength) {
                /* The range starts past our new max.  Just remove this range entirely */
                [newTempSelection removeObjectAtIndex:i];
                i--;
                max--;
            }
            else {
                /* Need to clip this range */
                range.length = newLength - range.location;
                [newTempSelection replaceObjectAtIndex:i withObject:[HFRangeWrapper withRange:range]];
            }
        }
    }
    [newTempSelection setArray:[HFRangeWrapper organizeAndMergeRanges:newTempSelection]];
    
    /* If there are multiple empty ranges, remove all but the first */
    BOOL foundEmptyRange = NO;
    max = [newTempSelection count];
    for (i=0; i < max; i++) {
        HFRange range = [[newTempSelection objectAtIndex:i] HFRange];
        HFASSERT(HFMaxRange(range) <= newLength);
        if (range.length == 0) {
            if (foundEmptyRange) {
                [newTempSelection removeObjectAtIndex:i];
                i--;
                max--;
            }
            foundEmptyRange = YES;
        }
    }
    if (max == 0) {
        /* Removed all ranges - insert one at the end */
        [newTempSelection addObject:[HFRangeWrapper withRange:HFRangeMake(newLength, 0)]];
    }
    
    /* If something changed, set the new selection and post the change bit */
    if (! [selectedContentsRanges isEqualToArray:newTempSelection]) {
        [selectedContentsRanges setArray:newTempSelection];
        [self _addPropertyChangeBits:HFControllerSelectedRanges];
    }
    
    [newTempSelection release];
}

- (void)setByteArray:(HFByteArray *)val {
    REQUIRE_NOT_NULL(val);
    BEGIN_TRANSACTION();
    [byteArray removeObserver:self forKeyPath:@"changesAreLocked"];
    [val retain];
    [byteArray release];
    byteArray = val;
    [cachedData release];
    cachedData = nil;
    [byteArray addObserver:self forKeyPath:@"changesAreLocked" options:0 context:KVOContextChangesAreLocked];
    [self _updateDisplayedRange];
    [self _addPropertyChangeBits: HFControllerContentValue | HFControllerContentLength];
    [self _clipSelectedContentsRangesToLength:[byteArray length]];
    END_TRANSACTION();
}

- (HFByteArray *)byteArray {
    return byteArray;
}

- (void)_performMultiRangeUndo:(HFControllerMultiRangeUndo *)undoer {
    /* We expect to only be called with an undo operation we know about (i.e. is in our set) */
    HFASSERT(undoOperations != nil);
    HFASSERT([undoOperations containsObject:undoer]);
    [undoer retain];
    [undoOperations removeObject:undoer];
    [self _commandInsertByteArrays:[undoer byteArrays] inRanges:[undoer replacementRanges] withSelectionAction:[undoer selectionAction]];
    [undoer invalidate];
    [undoer release];
}

- (void)_registerUndoOperationForInsertingByteArrays:(NSArray *)byteArrays inRanges:(NSArray *)ranges withSelectionAction:(SelectionAction_t)selectionAction {
    if (undoManager) {
        HFControllerMultiRangeUndo *undoer = [[HFControllerMultiRangeUndo alloc] initForInsertingByteArrays:byteArrays inRanges:ranges withSelectionAction:selectionAction];
        HFASSERT(undoOperations != nil);
        [undoOperations addObject:undoer];
        [undoManager registerUndoWithTarget:self selector:@selector(_performMultiRangeUndo:) object:undoer];
        [undoer release];
    }
}

- (void)_undoNotification:note {
    USE(note);
    [self _endTypingUndoCoalescingIfActive];
}

- (void)_removeUndoManagerNotifications {
    if (undoManager) {
        NSNotificationCenter *noter = [NSNotificationCenter defaultCenter];
        [noter removeObserver:self name:NSUndoManagerWillUndoChangeNotification object:undoManager];
    }
}

- (void)_addUndoManagerNotifications {
    if (undoManager) {
        NSNotificationCenter *noter = [NSNotificationCenter defaultCenter];
        [noter addObserver:self selector:@selector(_undoNotification:) name:NSUndoManagerWillUndoChangeNotification object:undoManager];
    }
}

- (void)_removeAllUndoOperations {
    /* Remove all the undo operations, because some undo operation is unsupported. Note that if we were smarter we would keep a stack of undo operations and only remove ones "up to" a certain point. */
    [undoManager removeAllActionsWithTarget:self];
    [undoOperations makeObjectsPerformSelector:@selector(invalidate)];
    [undoOperations removeAllObjects];
}

- (void)setUndoManager:(NSUndoManager *)manager {
    [self _removeUndoManagerNotifications];
    [self _removeAllUndoOperations];
    [manager retain];
    [undoManager release];
    undoManager = manager;
    [self _addUndoManagerNotifications];
}

- (NSUndoManager *)undoManager {
    return undoManager;
}

- (NSUInteger)bytesPerLine {
    return bytesPerLine;
}

- (BOOL)editable {
    return _hfflags.editable && ! [byteArray changesAreLocked] && _hfflags.editMode != HFReadOnlyMode;
}

- (void)setEditable:(BOOL)flag {
    if (flag != _hfflags.editable) {
        _hfflags.editable = flag;
        [self _addPropertyChangeBits:HFControllerEditable];
    }
}

- (void)_updateBytesPerLine {
    NSUInteger newBytesPerLine = NSUIntegerMax;
    FOREACH(HFRepresenter*, rep, representers) {
        NSView *view = [rep view];
        CGFloat width = [view frame].size.width;
        NSUInteger repMaxBytesPerLine = [rep maximumBytesPerLineForViewWidth:width];
        HFASSERT(repMaxBytesPerLine > 0);
        newBytesPerLine = MIN(repMaxBytesPerLine, newBytesPerLine);
    }
    if (newBytesPerLine != bytesPerLine) {
        HFASSERT(newBytesPerLine > 0);
        bytesPerLine = newBytesPerLine;
        BEGIN_TRANSACTION();
        [self _addPropertyChangeBits:HFControllerBytesPerLine];
        END_TRANSACTION();
    }
}

- (void)representer:(HFRepresenter *)rep changedProperties:(HFControllerPropertyBits)properties {
    USE(rep);
    HFControllerPropertyBits remainingProperties = properties;
    BEGIN_TRANSACTION();
    if (remainingProperties & HFControllerBytesPerLine) {
        [self _updateBytesPerLine];
        remainingProperties &= ~HFControllerBytesPerLine;
    }
    if (remainingProperties & HFControllerDisplayedLineRange) {
        [self _updateDisplayedRange];
        remainingProperties &= ~HFControllerDisplayedLineRange;
    }
    if (remainingProperties & HFControllerByteRangeAttributes) {
        [self _addPropertyChangeBits:HFControllerByteRangeAttributes];
        remainingProperties &= ~HFControllerByteRangeAttributes;
    }
    if (remainingProperties & HFControllerViewSizeRatios) {
        [self _addPropertyChangeBits:HFControllerViewSizeRatios];
        remainingProperties &= ~HFControllerViewSizeRatios;
    }
    if (remainingProperties) {
        NSLog(@"Unknown properties: %lx", (long)remainingProperties);
    }
    END_TRANSACTION();
}

- (HFByteArray *)byteArrayForSelectedContentsRanges {
    HFByteArray *result = nil;
    HFByteArray *bytes = [self byteArray];
    VALIDATE_SELECTION();
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange range = [wrapper HFRange];
        HFByteArray *additionalBytes = [bytes subarrayWithRange:range];
        if (! result) {
            result = additionalBytes;
        }
        else {
            [result insertByteArray:additionalBytes inRange:HFRangeMake([result length], 0)];
        }
    }
    return result;
}

/* Flattens the selected range to a single range (the selected range becomes any character within or between the selected ranges).  Modifies the selectedContentsRanges and returns the new single HFRange.  Does not call notifyRepresentersOfChanges: */
- (HFRange)_flattenSelectionRange {
    HFASSERT([selectedContentsRanges count] >= 1);
    
    HFRange resultRange = [[selectedContentsRanges objectAtIndex:0] HFRange];
    if ([selectedContentsRanges count] == 1) return resultRange; //already flat
    
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange selectedRange = [wrapper HFRange];
        if (selectedRange.location < resultRange.location) {
            /* Extend our result range backwards */
            resultRange.length += resultRange.location - selectedRange.location;
            resultRange.location = selectedRange.location;
        }
        if (HFRangeExtendsPastRange(selectedRange, resultRange)) {
            HFASSERT(selectedRange.location >= resultRange.location); //must be true by if statement above
            resultRange.length = HFSum(selectedRange.location - resultRange.location, selectedRange.length);
        }
    }
    [self _setSingleSelectedContentsRange:resultRange];
    return resultRange;
}

- (unsigned long long)_minimumSelectionLocation {
    HFASSERT([selectedContentsRanges count] >= 1);
    unsigned long long minSelection = ULLONG_MAX;
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange range = [wrapper HFRange];
        minSelection = MIN(minSelection, range.location);
    }
    return minSelection;
}

- (unsigned long long)_maximumSelectionLocation {
    HFASSERT([selectedContentsRanges count] >= 1);
    unsigned long long maxSelection = 0;
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange range = [wrapper HFRange];
        maxSelection = MAX(maxSelection, HFMaxRange(range));
    }
    return maxSelection;
}

- (unsigned long long)minimumSelectionLocation {
    return [self _minimumSelectionLocation];
}

- (unsigned long long)maximumSelectionLocation {
    return [self _maximumSelectionLocation];
}

/* Put the selection at the left or right end of the current selection, with zero length.  Modifies the selectedContentsRanges and returns the new single HFRange.  Does not call notifyRepresentersOfChanges: */
- (HFRange)_telescopeSelectionRangeInDirection:(HFControllerMovementDirection)direction {
    HFRange resultRange;
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    resultRange.location = (direction == HFControllerDirectionLeft ? [self _minimumSelectionLocation] : [self _maximumSelectionLocation]);
    resultRange.length = 0;
    [self _setSingleSelectedContentsRange:resultRange];
    return resultRange;
}

- (void)beginSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)characterIndex {
    USE(event);
    HFASSERT(characterIndex <= [self contentsLength]);
    
    /* Determine how to perform the selection - normally, with command key, or with shift key.  Command + shift is the same as command. The shift key closes the selection - the selected range becomes the single range containing the first and last selected character. */
    _hfflags.shiftExtendSelection = NO;
    _hfflags.commandExtendSelection = NO;
    NSUInteger flags = [event modifierFlags];
    if (flags & NSCommandKeyMask) _hfflags.commandExtendSelection = YES;
    else if (flags & NSShiftKeyMask) _hfflags.shiftExtendSelection = YES;
    
    selectionAnchor = NO_SELECTION;
    selectionAnchorRange = HFRangeMake(NO_SELECTION, 0);
    
    _hfflags.selectionInProgress = YES;
    if (_hfflags.commandExtendSelection) {
        /* The selection anchor is used to track the "invert" range.  All characters within this range have their selection inverted.  This is tracked by the _shouldInvertSelectedRangesByAnchorRange method. */
        selectionAnchor = characterIndex;
        selectionAnchorRange = HFRangeMake(characterIndex, 0);
    }
    else if (_hfflags.shiftExtendSelection) {
        /* The selection anchor is used to track the single (flattened) selected range. */
        HFRange selectedRange = [self _flattenSelectionRange];
        unsigned long long distanceFromRangeStart = HFAbsoluteDifference(selectedRange.location, characterIndex);
        unsigned long long distanceFromRangeEnd = HFAbsoluteDifference(HFMaxRange(selectedRange), characterIndex);
        if (selectedRange.length == 0) {    
            HFASSERT(distanceFromRangeStart == distanceFromRangeEnd);
            selectionAnchor = selectedRange.location;
            selectedRange.location = MIN(characterIndex, selectedRange.location);
            selectedRange.length = distanceFromRangeStart;
        }
        else if (distanceFromRangeStart >= distanceFromRangeEnd) {
            /* Push the "end forwards" */
            selectedRange.length = distanceFromRangeStart;
            selectionAnchor = selectedRange.location;
        }
        else {
            /* Push the "start back" */
            selectedRange.location = selectedRange.location + selectedRange.length - distanceFromRangeEnd;
            selectedRange.length = distanceFromRangeEnd;
            selectionAnchor = HFSum(selectedRange.length, selectedRange.location);
        }
        HFASSERT(HFRangeIsSubrangeOfRange(selectedRange, HFRangeMake(0, [self contentsLength])));
        selectionAnchorRange = selectedRange;
        [self _setSingleSelectedContentsRange:selectedRange];
    }
    else {
        /* No modifier key selection.  The selection anchor is not used.  */
        [self _setSingleSelectedContentsRange:HFRangeMake(characterIndex, 0)];
        selectionAnchor = characterIndex;
    }
}

- (void)continueSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)byteIndex {
    USE(event);
    HFASSERT(_hfflags.selectionInProgress);
    HFASSERT(byteIndex <= [self contentsLength]);
    BEGIN_TRANSACTION();
    if (_hfflags.commandExtendSelection) {
        /* Clear any zero-length ranges, unless there's only one */
        NSUInteger rangeCount = [selectedContentsRanges count];
        NSUInteger rangeIndex = rangeCount;
        while (rangeIndex-- > 0) {
            if (rangeCount > 1 && [[selectedContentsRanges objectAtIndex:rangeIndex] HFRange].length == 0) {
                [selectedContentsRanges removeObjectAtIndex:rangeIndex];
                rangeCount--;
            }
        }
        selectionAnchorRange.location = MIN(byteIndex, selectionAnchor);
        selectionAnchorRange.length = MAX(byteIndex, selectionAnchor) - selectionAnchorRange.location;
        [self _addPropertyChangeBits:HFControllerSelectedRanges];
    }
    else if (_hfflags.shiftExtendSelection) {
        HFASSERT(selectionAnchorRange.location != NO_SELECTION);
        HFASSERT(selectionAnchor != NO_SELECTION);
        HFRange range;
        if (! HFLocationInRange(byteIndex, selectionAnchorRange)) {
            /* The character index is outside of the selection anchor range.  The new range is just the selected anchor range combined with the character index. */
            range.location = MIN(byteIndex, selectionAnchorRange.location);
            unsigned long long rangeEnd = MAX(byteIndex, HFSum(selectionAnchorRange.location, selectionAnchorRange.length));
            HFASSERT(rangeEnd >= range.location);
            range.length = rangeEnd - range.location;
        }
        else {
            /* The character is within the selection anchor range.  We use the selection anchor index to determine which "side" of the range is selected. */
            range.location = MIN(selectionAnchor, byteIndex);
            range.length = HFAbsoluteDifference(selectionAnchor, byteIndex);
        }
        [self _setSingleSelectedContentsRange:range];
    }
    else {
        /* No modifier key selection */
        HFRange range;
        range.location = MIN(byteIndex, selectionAnchor);
        range.length = MAX(byteIndex, selectionAnchor) - range.location;
        [self _setSingleSelectedContentsRange:range];
    }
    END_TRANSACTION();
    VALIDATE_SELECTION();
}

- (void)endSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)characterIndex {
    USE(event);
    HFASSERT(_hfflags.selectionInProgress);
    HFASSERT(characterIndex <= [self contentsLength]);
    if (_hfflags.commandExtendSelection) {
        selectionAnchorRange.location = MIN(characterIndex, selectionAnchor);
        selectionAnchorRange.length = MAX(characterIndex, selectionAnchor) - selectionAnchorRange.location;
        
        /* "Commit" our selectionAnchorRange */
        NSArray *newSelection = [self _invertedSelectedContentsRanges];
        [selectedContentsRanges setArray:newSelection];
    }
    else if (_hfflags.shiftExtendSelection) {
        HFASSERT(selectionAnchorRange.location != NO_SELECTION);
        HFASSERT(selectionAnchor != NO_SELECTION);
        HFRange range;
        if (! HFLocationInRange(characterIndex, selectionAnchorRange)) {
            /* The character index is outside of the selection anchor range.  The new range is just the selected anchor range combined with the character index. */
            range.location = MIN(characterIndex, selectionAnchorRange.location);
            unsigned long long rangeEnd = MAX(characterIndex, HFSum(selectionAnchorRange.location, selectionAnchorRange.length));
            HFASSERT(rangeEnd >= range.location);
            range.length = rangeEnd - range.location;
        }
        else {
            /* The character is within the selection anchor range.  We use the selection anchor index to determine which "side" of the range is selected. */
            range.location = MIN(selectionAnchor, characterIndex);
            range.length = HFAbsoluteDifference(selectionAnchor, characterIndex);
        }
        [self _setSingleSelectedContentsRange:range];
    }
    else {
        /* No modifier key selection */
        HFRange range;
        range.location = MIN(characterIndex, selectionAnchor);
        range.length = MAX(characterIndex, selectionAnchor) - range.location;
        [self _setSingleSelectedContentsRange:range];
    }
    
    _hfflags.selectionInProgress = NO;    
    _hfflags.shiftExtendSelection = NO;
    _hfflags.commandExtendSelection = NO;
    selectionAnchor = NO_SELECTION;
}

- (double)selectionPulseAmount {
    double result = 0;
    if (pulseSelectionStartTime > 0) {
        CFTimeInterval diff = pulseSelectionCurrentTime - pulseSelectionStartTime;
        if (diff > 0 && diff < kPulseDuration) {
            result = 1. - fabs(diff * 2 - kPulseDuration) / kPulseDuration;
        }
    }
    return result;
}

- (void)firePulseTimer:(NSTimer *)timer {
    USE(timer);
    HFASSERT(pulseSelectionStartTime != 0);
    pulseSelectionCurrentTime = CFAbsoluteTimeGetCurrent();
    [self _addPropertyChangeBits:HFControllerSelectionPulseAmount];
    if (pulseSelectionCurrentTime - pulseSelectionStartTime > kPulseDuration) {
        [pulseSelectionTimer invalidate];
        [pulseSelectionTimer release];
        pulseSelectionTimer = nil;
    }
}

- (void)pulseSelection {
    pulseSelectionStartTime = CFAbsoluteTimeGetCurrent();
    if (pulseSelectionTimer == nil) {
        pulseSelectionTimer = [[NSTimer scheduledTimerWithTimeInterval:(1. / 30.) target:self selector:@selector(firePulseTimer:) userInfo:nil repeats:YES] retain];
    }
}

- (void)scrollByLines:(long double)lines {
    HFFPRange lineRange = [self displayedLineRange];
    HFASSERT(HFULToFP([self totalLineCount]) >= lineRange.length);
    long double maxScroll = HFULToFP([self totalLineCount]) - lineRange.length;
    if (lines < 0) {
        lineRange.location -= MIN(lineRange.location, -lines);
    }
    else {
        lineRange.location = MIN(maxScroll, lineRange.location + lines);
    }
    [self setDisplayedLineRange:lineRange];
}

- (void)scrollWithScrollEvent:(NSEvent *)scrollEvent {
    HFASSERT(scrollEvent != NULL);
    HFASSERT([scrollEvent type] == NSScrollWheel);
    CGFloat preciseScroll;
    BOOL hasPreciseScroll;
    
    /* Prefer precise deltas */
    if ([scrollEvent respondsToSelector:@selector(hasPreciseScrollingDeltas)]) {
        hasPreciseScroll = [scrollEvent hasPreciseScrollingDeltas];
        if (hasPreciseScroll) {
            /* In this case, we're going to scroll by a certain number of points */
            preciseScroll = [scrollEvent scrollingDeltaY];
        }
    } else if ([scrollEvent respondsToSelector:@selector(deviceDeltaY)]) {
        /* Legacy (SnowLeopard) support */
        hasPreciseScroll = ([scrollEvent subtype] == 1);
        if (hasPreciseScroll) {
            preciseScroll = [scrollEvent deviceDeltaY];
        }
    } else {
        hasPreciseScroll = NO;
    }
    
    long double scrollY = 0;
    if (! hasPreciseScroll) {
        scrollY = -kScrollMultiplier * [scrollEvent deltaY];
    } else {
        scrollY = -preciseScroll / [self lineHeight];
    }
    [self scrollByLines:scrollY];
}

- (void)setSelectedContentsRanges:(NSArray *)selectedRanges {
    REQUIRE_NOT_NULL(selectedRanges);
    [selectedContentsRanges setArray:selectedRanges];
    VALIDATE_SELECTION();
    selectionAnchor = NO_SELECTION;
    [self _addPropertyChangeBits:HFControllerSelectedRanges];
}

- (IBAction)selectAll:sender {
    USE(sender);
    if (_hfflags.selectable) {
        [self _setSingleSelectedContentsRange:HFRangeMake(0, [self contentsLength])];
    }
}

- (void)_addRangeToSelection:(HFRange)range {
    [selectedContentsRanges addObject:[HFRangeWrapper withRange:range]];
    [selectedContentsRanges setArray:[HFRangeWrapper organizeAndMergeRanges:selectedContentsRanges]];
    VALIDATE_SELECTION();
}

- (void)_removeRangeFromSelection:(HFRange)inputRange withCursorLocationIfAllSelectionRemoved:(unsigned long long)cursorLocation {
    NSUInteger selectionCount = [selectedContentsRanges count];
    HFASSERT(selectionCount > 0 && selectionCount <= NSUIntegerMax / 2);
    NSUInteger rangeIndex = 0;
    NSArray *wrappers;
    NEW_ARRAY(HFRange, tempRanges, selectionCount * 2);
    FOREACH(HFRangeWrapper*, wrapper, selectedContentsRanges) {
        HFRange range = [wrapper HFRange];
        if (! HFIntersectsRange(range, inputRange)) {
            tempRanges[rangeIndex++] = range;
        }
        else {
            if (range.location < inputRange.location) {
                tempRanges[rangeIndex++] = HFRangeMake(range.location, inputRange.location - range.location);
            }
            if (HFMaxRange(range) > HFMaxRange(inputRange)) {
                tempRanges[rangeIndex++] = HFRangeMake(HFMaxRange(inputRange), HFMaxRange(range) - HFMaxRange(inputRange));
            }
        }
    }
    if (rangeIndex == 0 || (rangeIndex == 1 && tempRanges[0].length == 0)) {
        /* We removed all of our ranges.  Telescope us. */
        HFASSERT(cursorLocation <= [self contentsLength]);
        [self _setSingleSelectedContentsRange:HFRangeMake(cursorLocation, 0)];
    }
    else {
        wrappers = [HFRangeWrapper withRanges:tempRanges count:rangeIndex];
        [selectedContentsRanges setArray:[HFRangeWrapper organizeAndMergeRanges:wrappers]];
    }
    FREE_ARRAY(tempRanges);
    VALIDATE_SELECTION();    
}

- (void)_moveDirectionDiscardingSelection:(HFControllerMovementDirection)direction byAmount:(unsigned long long)amountToMove {
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    BEGIN_TRANSACTION();
    BOOL selectionWasEmpty = ([selectedContentsRanges count] == 1 && [[selectedContentsRanges objectAtIndex:0] HFRange].length == 0);
    BOOL directionIsForward = (direction == HFControllerDirectionRight);
    HFRange selectedRange = [self _telescopeSelectionRangeInDirection: (directionIsForward ? HFControllerDirectionRight : HFControllerDirectionLeft)];
    HFASSERT(selectedRange.length == 0);
    HFASSERT([self contentsLength] >= selectedRange.location);
    /* A movement of just 1 with a selection only clears the selection; it does not move the cursor */
    if (selectionWasEmpty || amountToMove > 1) {
        if (direction == HFControllerDirectionLeft) {
            selectedRange.location -= MIN(amountToMove, selectedRange.location);
        }
        else {
            selectedRange.location += MIN(amountToMove, [self contentsLength] - selectedRange.location);
        }
    }
    selectionAnchor = NO_SELECTION;
    [self _setSingleSelectedContentsRange:selectedRange];
    [self _ensureVisibilityOfLocation:selectedRange.location];
    END_TRANSACTION();
}

/* In _extendSelectionInDirection:byAmount:, we only allow left/right movement.  up/down is not allowed. */
- (void)_extendSelectionInDirection:(HFControllerMovementDirection)direction byAmount:(unsigned long long)amountToMove {
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    unsigned long long minSelection = [self _minimumSelectionLocation];
    unsigned long long maxSelection = [self _maximumSelectionLocation];
    BOOL selectionChanged = NO;
    unsigned long long locationToMakeVisible = NO_SELECTION;
    unsigned long long contentsLength = [self contentsLength];
    if (selectionAnchor == NO_SELECTION) {
        /* Pick the anchor opposite the choice of direction */
        if (direction == HFControllerDirectionLeft) selectionAnchor = maxSelection;
        else selectionAnchor = minSelection;
    }
    if (direction == HFControllerDirectionLeft) {
        if (minSelection >= selectionAnchor && maxSelection > minSelection) {
            unsigned long long amountToRemove = llmin(maxSelection - selectionAnchor, amountToMove);
            unsigned long long amountToAdd = amountToMove - amountToRemove;
            if (amountToRemove > 0) [self _removeRangeFromSelection:HFRangeMake(maxSelection - amountToRemove, amountToRemove) withCursorLocationIfAllSelectionRemoved:minSelection];
            if (amountToAdd > 0) [self _addRangeToSelection:HFRangeMake(selectionAnchor - amountToAdd, amountToAdd)];
            selectionChanged = YES;
            locationToMakeVisible = (amountToAdd > 0 ? selectionAnchor - amountToAdd : maxSelection - amountToRemove);
        }
        else {
            if (minSelection > 0) {
                NSUInteger amountToAdd = ll2l(llmin(minSelection, amountToMove));
                if (amountToAdd > 0) [self _addRangeToSelection:HFRangeMake(minSelection - amountToAdd, amountToAdd)];
                selectionChanged = YES;
                locationToMakeVisible = minSelection - amountToAdd;
            }
        }
    }
    else if (direction == HFControllerDirectionRight) {
        if (maxSelection <= selectionAnchor && maxSelection > minSelection) {
            HFASSERT(contentsLength >= maxSelection);
            unsigned long long amountToRemove = ll2l(llmin(maxSelection - minSelection, amountToMove));
            unsigned long long amountToAdd = amountToMove - amountToRemove;
            if (amountToRemove > 0) [self _removeRangeFromSelection:HFRangeMake(minSelection, amountToRemove) withCursorLocationIfAllSelectionRemoved:maxSelection];
            if (amountToAdd > 0) [self _addRangeToSelection:HFRangeMake(maxSelection, amountToAdd)];
            selectionChanged = YES;
            locationToMakeVisible = llmin(contentsLength, (amountToAdd > 0 ? maxSelection + amountToAdd : minSelection + amountToRemove));
        }
        else {
            if (maxSelection < contentsLength) {
                NSUInteger amountToAdd = ll2l(llmin(contentsLength - maxSelection, amountToMove));
                [self _addRangeToSelection:HFRangeMake(maxSelection, amountToAdd)];
                selectionChanged = YES;
                locationToMakeVisible = maxSelection + amountToAdd;
            }
        }
    }
    if (selectionChanged) {
        BEGIN_TRANSACTION();
        [self _addPropertyChangeBits:HFControllerSelectedRanges];
        if (locationToMakeVisible != NO_SELECTION) [self _ensureVisibilityOfLocation:locationToMakeVisible];
        END_TRANSACTION();
    }
}

/* Returns the distance to the next "word" (at least 1, unless we are empty).  Here a word is identified as a column.  If there are no columns, a word is a line.  This is used for word movement (e.g. option + right arrow) */
- (unsigned long long)_distanceToWordBoundaryForDirection:(HFControllerMovementDirection)direction {
    unsigned long long result = 0, locationToConsider;
    
    /* Figure out how big a word is.  By default, it's the column width, unless we have no columns, in which case it's the bytes per line. */
    NSUInteger wordGranularity = [self bytesPerColumn];
    if (wordGranularity == 0) wordGranularity = MAX(1, [self bytesPerLine]);
    if (selectionAnchor == NO_SELECTION) {
        /* Pick the anchor inline with the choice of direction */
        if (direction == HFControllerDirectionLeft) locationToConsider = [self _minimumSelectionLocation];
        else locationToConsider = [self _maximumSelectionLocation];
    } else {
        /* Just use the anchor */
        locationToConsider = selectionAnchor;
    }
    if (direction == HFControllerDirectionRight) {
        result = HFRoundUpToNextMultipleSaturate(locationToConsider, wordGranularity) - locationToConsider;
    } else {
        result = locationToConsider % wordGranularity;
        if (result == 0) result = wordGranularity;
    }
    return result;
    
}

/* Anchored selection is not allowed; neither is up/down movement */
- (void)_shiftSelectionInDirection:(HFControllerMovementDirection)direction byAmount:(unsigned long long)amountToMove {
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    HFASSERT(selectionAnchor == NO_SELECTION);
    NSUInteger i, max = [selectedContentsRanges count];
    const unsigned long long maxLength = [self contentsLength];
    NSMutableArray *newRanges = [NSMutableArray arrayWithCapacity:max];
    BOOL hasAddedNonemptyRange = NO;
    for (i=0; i < max; i++) {
        HFRange range = [[selectedContentsRanges objectAtIndex:i] HFRange];
        HFASSERT(range.location <= maxLength && HFMaxRange(range) <= maxLength);
        if (direction == HFControllerDirectionRight) {
            unsigned long long offset = MIN(maxLength - range.location, amountToMove);
            unsigned long long lengthToSubtract = MIN(range.length, amountToMove - offset);
            range.location += offset;
            range.length -= lengthToSubtract;
        }
        else { /* direction == HFControllerDirectionLeft */
            unsigned long long negOffset = MIN(amountToMove, range.location);
            unsigned long long lengthToSubtract = MIN(range.length, amountToMove - negOffset);
            range.location -= negOffset;
            range.length -= lengthToSubtract;
        }
        [newRanges addObject:[HFRangeWrapper withRange:range]];
        hasAddedNonemptyRange = hasAddedNonemptyRange || (range.length > 0);
    }
    
    newRanges = [[[HFRangeWrapper organizeAndMergeRanges:newRanges] mutableCopy] autorelease];
    
    BOOL hasFoundEmptyRange = NO;
    max = [newRanges count];
    for (i=0; i < max; i++) {
        HFRange range = [[newRanges objectAtIndex:i] HFRange];
        if (range.length == 0) {
            if (hasFoundEmptyRange || hasAddedNonemptyRange) {
                [newRanges removeObjectAtIndex:i];
                i--;
                max--;
            }
            hasFoundEmptyRange = YES;
        }
    }
    [selectedContentsRanges setArray:newRanges];
    VALIDATE_SELECTION();
    [self _addPropertyChangeBits:HFControllerSelectedRanges];
}

__attribute__((unused))
static BOOL rangesAreInAscendingOrder(NSEnumerator *rangeEnumerator) {
    unsigned long long index = 0;
    HFRangeWrapper *rangeWrapper;
    while ((rangeWrapper = [rangeEnumerator nextObject])) {
        HFRange range = [rangeWrapper HFRange];
        if (range.location < index) return NO;
        index = HFSum(range.location, range.length);
    }
    return YES;
}

- (BOOL)_registerCondemnedRangesForUndo:(NSArray *)ranges selectingRangesAfterUndo:(BOOL)selectAfterUndo {
    HFASSERT(ranges != NULL);
    HFASSERT(ranges != selectedContentsRanges); //selectedContentsRanges is mutable - we really don't want to stash it away with undo
    BOOL result = NO;
    NSUndoManager *manager = [self undoManager];
    NSUInteger rangeCount = [ranges count];
    if (! manager || ! rangeCount) return NO;
    
    HFASSERT(rangesAreInAscendingOrder([ranges objectEnumerator]));
    
    NSMutableArray *rangesToRestore = [NSMutableArray arrayWithCapacity:rangeCount];
    NSMutableArray *correspondingByteArrays = [NSMutableArray arrayWithCapacity:rangeCount];
    HFByteArray *bytes = [self byteArray];
    
    /* Enumerate the ranges in forward order so when we insert them, we insert later ranges before earlier ones, so we don't have to worry about shifting indexes */
    FOREACH(HFRangeWrapper *, rangeWrapper, ranges) {
        HFRange range = [rangeWrapper HFRange];
        if (range.length > 0) {
            [rangesToRestore addObject:[HFRangeWrapper withRange:HFRangeMake(range.location, 0)]];
            [correspondingByteArrays addObject:[bytes subarrayWithRange:range]];
            result = YES;
        }
    }
    
    if (result) [self _registerUndoOperationForInsertingByteArrays:correspondingByteArrays inRanges:rangesToRestore withSelectionAction:(selectAfterUndo ? eSelectResult : eSelectAfterResult)];    
    return result;
}

- (void)_commandDeleteRanges:(NSArray *)rangesToDelete {
    HFASSERT(rangesToDelete != selectedContentsRanges); //selectedContentsRanges is mutable - we really don't want to stash it away with undo
    HFASSERT(rangesAreInAscendingOrder([rangesToDelete objectEnumerator]));
    
    /* End this string of typing */
    [self _endTypingUndoCoalescingIfActive];
    
    /* Delete all the selection - in reverse order */
    unsigned long long minSelection = ULLONG_MAX;
    BOOL somethingWasDeleted = NO;
    [self _registerCondemnedRangesForUndo:rangesToDelete selectingRangesAfterUndo:YES];
    NSUInteger rangeIndex = [rangesToDelete count];
    HFASSERT(rangeIndex > 0);
    while (rangeIndex--) {
        HFRange range = [[rangesToDelete objectAtIndex:rangeIndex] HFRange];
        minSelection = llmin(range.location, minSelection);
        if (range.length > 0) {
            [byteArray deleteBytesInRange:range];
            somethingWasDeleted = YES;
        }
    }
    
    HFASSERT(minSelection != ULLONG_MAX);
    if (somethingWasDeleted) {
        BEGIN_TRANSACTION();
        [self _addPropertyChangeBits:HFControllerContentValue | HFControllerContentLength];
        [self _setSingleSelectedContentsRange:HFRangeMake(minSelection, 0)];
        [self _updateDisplayedRange];
        END_TRANSACTION();
    }
    else {
        NSBeep();
    }
}

- (void)_commandInsertByteArrays:(NSArray *)byteArrays inRanges:(NSArray *)ranges withSelectionAction:(SelectionAction_t)selectionAction {
    HFASSERT(selectionAction < NUM_SELECTION_ACTIONS);
    REQUIRE_NOT_NULL(byteArrays);
    REQUIRE_NOT_NULL(ranges);
    HFASSERT([ranges count] == [byteArrays count]);
    NSUInteger index, max = [ranges count];
    HFByteArray *bytes = [self byteArray];
    HFASSERT(rangesAreInAscendingOrder([ranges objectEnumerator]));
    
    /* End this string of typing */
    [self _endTypingUndoCoalescingIfActive];
    
    NSMutableArray *byteArraysToInsertOnUndo = [NSMutableArray arrayWithCapacity:max];
    NSMutableArray *rangesToInsertOnUndo = [NSMutableArray arrayWithCapacity:max];
    
    BEGIN_TRANSACTION();
    if (selectionAction == eSelectResult || selectionAction == eSelectAfterResult) {
        [selectedContentsRanges removeAllObjects];
    }
    unsigned long long endOfInsertedRanges = ULLONG_MAX;
    for (index = 0; index < max; index++) {
        HFRange range = [[ranges objectAtIndex:index] HFRange];
        HFByteArray *oldBytes = [bytes subarrayWithRange:range];
        [byteArraysToInsertOnUndo addObject:oldBytes];
        HFByteArray *newBytes = [byteArrays objectAtIndex:index];
        EXPECT_CLASS(newBytes, [HFByteArray class]);
        [bytes insertByteArray:newBytes inRange:range];
        HFRange insertedRange = HFRangeMake(range.location, [newBytes length]);
        HFRangeWrapper *insertedRangeWrapper = [HFRangeWrapper withRange:insertedRange];
        [rangesToInsertOnUndo addObject:insertedRangeWrapper];
        if (selectionAction == eSelectResult) {
            [selectedContentsRanges addObject:insertedRangeWrapper];
        }
        else {
            endOfInsertedRanges = HFMaxRange(insertedRange);
        }
    }
    if (selectionAction == eSelectAfterResult) {
        HFASSERT([ranges count] > 0);
        [selectedContentsRanges addObject:[HFRangeWrapper withRange:HFRangeMake(endOfInsertedRanges, 0)]];
    }
    
    if (selectionAction == ePreserveSelection) {
        HFASSERT([selectedContentsRanges count] > 0);
        [self _clipSelectedContentsRangesToLength:[self contentsLength]];
    }
    
    VALIDATE_SELECTION();
    HFASSERT([byteArraysToInsertOnUndo count] == [rangesToInsertOnUndo count]);
    [self _registerUndoOperationForInsertingByteArrays:byteArraysToInsertOnUndo inRanges:rangesToInsertOnUndo withSelectionAction:(selectionAction == ePreserveSelection ? ePreserveSelection : eSelectAfterResult)];
    [self _updateDisplayedRange];
    [self maximizeVisibilityOfContentsRange:[[selectedContentsRanges objectAtIndex:0] HFRange]];
    [self _addPropertyChangeBits:HFControllerContentValue | HFControllerContentLength | HFControllerSelectedRanges];
    END_TRANSACTION();
}

/* The user has hit undo after typing a string. */
- (void)_commandReplaceBytesAfterBytesFromBeginning:(unsigned long long)leftOffset upToBytesFromEnd:(unsigned long long)rightOffset withByteArray:(HFByteArray *)bytesToReinsert {
    HFASSERT(bytesToReinsert != NULL);
    
    /* End this string of typing */
    [self _endTypingUndoCoalescingIfActive];
    
    BEGIN_TRANSACTION();
    HFByteArray *bytes = [self byteArray];
    unsigned long long contentsLength = [self contentsLength];
    HFASSERT(leftOffset <= contentsLength);
    HFASSERT(rightOffset <= contentsLength);
    HFASSERT(contentsLength - rightOffset >= leftOffset);
    HFRange rangeToReplace = HFRangeMake(leftOffset, contentsLength - rightOffset - leftOffset);
    [self _registerCondemnedRangesForUndo:[HFRangeWrapper withRanges:&rangeToReplace count:1] selectingRangesAfterUndo:NO];
    [bytes insertByteArray:bytesToReinsert inRange:rangeToReplace];
    [self _updateDisplayedRange];
    [self _setSingleSelectedContentsRange:HFRangeMake(rangeToReplace.location, [bytesToReinsert length])];
    [self _addPropertyChangeBits:HFControllerContentValue | HFControllerContentLength | HFControllerSelectedRanges];
    END_TRANSACTION();
}

/* We use NSNumbers instead of long longs here because Tiger/PPC NSInvocation had trouble with long longs */
- (void)_commandValueObjectsReplaceBytesAfterBytesFromBeginning:(NSNumber *)leftOffset upToBytesFromEnd:(NSNumber *)rightOffset withByteArray:(HFByteArray *)bytesToReinsert {
    HFASSERT(leftOffset != NULL);
    HFASSERT(rightOffset != NULL);
    EXPECT_CLASS(leftOffset, NSNumber);
    EXPECT_CLASS(rightOffset, NSNumber);
    [self _commandReplaceBytesAfterBytesFromBeginning:[leftOffset unsignedLongLongValue] upToBytesFromEnd:[rightOffset unsignedLongLongValue] withByteArray:bytesToReinsert];
}

- (void)_endTypingUndoCoalescingIfActive {
    [undoCoalescer release];
    undoCoalescer = nil;
}

- (void)_performTypingUndo:(HFControllerCoalescedUndo *)undoer {
    REQUIRE_NOT_NULL(undoer);
    
    /* We expect to only be called with an undo operation we know about (i.e. is in our set).  Remove it from the set. */
    HFASSERT(undoOperations != nil);
    HFASSERT([undoOperations containsObject:undoer]);
    [undoer retain];
    [undoOperations removeObject:undoer];    
    
    BEGIN_TRANSACTION();
    
    HFByteArray *bytes = [self byteArray];
    HFControllerCoalescedUndo *redoer = [undoer invertWithByteArray:bytes];
    
    HFRange rangeToReplace = [undoer rangeToReplace];
    HFByteArray *deletedData = [undoer deletedData];
    HFRange rangeToSelect;
    if (deletedData == nil) {
        [bytes deleteBytesInRange:rangeToReplace];
        rangeToSelect = HFRangeMake(rangeToReplace.location, 0);
    }
    else {
        [bytes insertByteArray:deletedData inRange:rangeToReplace];
        rangeToSelect = HFRangeMake(rangeToReplace.location, [deletedData length]);
        /* We only ever put the cursor at the end on redo; TextEdit works this way */
        if ([[self undoManager] isRedoing]) rangeToSelect = HFRangeMake(HFMaxRange(rangeToSelect), 0);
    }
    [self _setSingleSelectedContentsRange:rangeToSelect];
    [self _updateDisplayedRange];
    [self maximizeVisibilityOfContentsRange:rangeToSelect];
    [self _addPropertyChangeBits:HFControllerContentValue | HFControllerContentLength];
    
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_performTypingUndo:) object:redoer];
    
    /* Add it as an undo operation */
    HFASSERT(undoOperations != nil);
    [undoOperations addObject:redoer];
    
    END_TRANSACTION();
    
    [undoer invalidate];
    [undoer release];
}

- (void)_beginNewUndoCoalescingWithData:(HFByteArray *)data isOverwriting:(BOOL)overwrite atAnchorLocation:(unsigned long long)anchorLocation {
    /* Replace our current undo coalescer */
    [undoCoalescer release];
    if (overwrite) {
        undoCoalescer = [[HFControllerCoalescedUndo alloc] initWithOverwrittenData:data atAnchorLocation:anchorLocation];
    } else {
        undoCoalescer = [[HFControllerCoalescedUndo alloc] initWithReplacedData:data atAnchorLocation:anchorLocation];
    }
    
    /* Add it as an undo operation */
    [[self undoManager] registerUndoWithTarget:self selector:@selector(_performTypingUndo:) object:undoCoalescer];
    
    /* Add it to our undo operations so that we can fix it up later in case its byte array will need to react to a file being changed out from under it. */
    HFASSERT(undoOperations != nil);
    [undoOperations addObject:undoCoalescer];
}

- (void)_activateTypingUndoCoalescingForOverwritingRange:(HFRange)rangeToReplace {
    HFASSERT(HFRangeIsSubrangeOfRange(rangeToReplace, HFRangeMake(0, [self contentsLength])));
    HFASSERT(rangeToReplace.length > 0);
    HFByteArray *bytes = [self byteArray];
    
    //undoCoalescer may be nil here
    BOOL replaceUndoCoalescer = ! [undoCoalescer canCoalesceOverwriteAtLocation:rangeToReplace.location];
    
    if (replaceUndoCoalescer) {
        [self _beginNewUndoCoalescingWithData:[bytes subarrayWithRange:rangeToReplace] isOverwriting:YES atAnchorLocation:rangeToReplace.location];
    }
    else {
        [undoCoalescer overwriteDataInRange:rangeToReplace withByteArray:bytes];
    }
    
}

- (void)_activateTypingUndoCoalescingForReplacingRange:(HFRange)rangeToReplace withDataOfLength:(unsigned long long)dataLength {
    HFASSERT(HFRangeIsSubrangeOfRange(rangeToReplace, HFRangeMake(0, [self contentsLength])));
    if (dataLength == 0 && rangeToReplace.length == 0) return; //nothing to do!
    
    BOOL replaceUndoCoalescer = YES, canCoalesceAppend = NO, canCoalesceDelete = NO;
    HFByteArray *bytes = [self byteArray];
    
    if (dataLength == 0 || rangeToReplace.length == 0) {
        if (undoCoalescer != nil) {
            canCoalesceAppend = (dataLength > 0 && [undoCoalescer canCoalesceAppendInRange:HFRangeMake(rangeToReplace.location, dataLength)]);
            canCoalesceDelete = (rangeToReplace.length > 0 && [undoCoalescer canCoalesceDeleteInRange:rangeToReplace]);
            replaceUndoCoalescer = (! canCoalesceAppend && ! canCoalesceDelete);
        }
    }
    
    if (replaceUndoCoalescer) {
        HFByteArray *replacedData = (rangeToReplace.length == 0 ? nil : [bytes subarrayWithRange:rangeToReplace]);
        [self _beginNewUndoCoalescingWithData:replacedData isOverwriting:NO atAnchorLocation:rangeToReplace.location];
        if (dataLength > 0) [undoCoalescer appendDataOfLength:dataLength];
    }
    else {
        HFASSERT(!canCoalesceAppend || !canCoalesceDelete);
        if (canCoalesceAppend) [undoCoalescer appendDataOfLength:dataLength];
        if (canCoalesceDelete) [undoCoalescer deleteDataOfLength:rangeToReplace.length withByteArray:bytes];
    }
}

- (void)moveInDirection:(HFControllerMovementDirection)direction byByteCount:(unsigned long long)amountToMove withSelectionTransformation:(HFControllerSelectionTransformation)transformation usingAnchor:(BOOL)useAnchor {
    if (! useAnchor) selectionAnchor = NO_SELECTION;
    switch (transformation) {
        case HFControllerDiscardSelection:
            [self _moveDirectionDiscardingSelection:direction byAmount:amountToMove];
            break;
            
        case HFControllerShiftSelection:
            [self _shiftSelectionInDirection:direction byAmount:amountToMove];
            break;
            
        case HFControllerExtendSelection:
            [self _extendSelectionInDirection:direction byAmount:amountToMove];
            break;
            
        default:
            [NSException raise:NSInvalidArgumentException format:@"Invalid transformation %ld", (long)transformation];
            break;
    }
    if (! useAnchor) selectionAnchor = NO_SELECTION;
}

- (void)moveInDirection:(HFControllerMovementDirection)direction withGranularity:(HFControllerMovementGranularity)granularity andModifySelection:(BOOL)extendSelection {
    HFASSERT(granularity == HFControllerMovementByte || granularity == HFControllerMovementColumn || granularity == HFControllerMovementLine || granularity == HFControllerMovementPage || granularity == HFControllerMovementDocument);
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    unsigned long long bytesToMove = 0;
    switch (granularity) {
        case HFControllerMovementByte:
            bytesToMove = 1;
            break;
        case HFControllerMovementColumn:
            /* This is a tricky case because the amount we have to move depends on our position in the column. */
            bytesToMove = [self _distanceToWordBoundaryForDirection:direction];
            break;
        case HFControllerMovementLine:
            bytesToMove = [self bytesPerLine];
            break;
        case HFControllerMovementPage:
            bytesToMove = HFProductULL([self bytesPerLine], HFFPToUL(MIN(floorl([self displayedLineRange].length), 1.)));
            break;
        case HFControllerMovementDocument:
            bytesToMove = [self contentsLength];
            break;
    }
    HFControllerSelectionTransformation transformation = (extendSelection ? HFControllerExtendSelection : HFControllerDiscardSelection);
    [self moveInDirection:direction byByteCount:bytesToMove withSelectionTransformation:transformation usingAnchor:YES];
}

- (void)moveToLineBoundaryInDirection:(HFControllerMovementDirection)direction andModifySelection:(BOOL)modifySelection {
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    BEGIN_TRANSACTION();
    unsigned long long locationToMakeVisible = NO_SELECTION;
    HFRange additionalSelection = {NO_SELECTION, NO_SELECTION};
    unsigned long long minLocation = NO_SELECTION, newMinLocation = NO_SELECTION, maxLocation = NO_SELECTION, newMaxLocation = NO_SELECTION;
    if (direction == HFControllerDirectionLeft) {
        /* If we are at the beginning of a line, this should be a no-op */
        minLocation = [self _minimumSelectionLocation];
        newMinLocation = (minLocation / bytesPerLine) * bytesPerLine;
        locationToMakeVisible = newMinLocation;
        additionalSelection = HFRangeMake(newMinLocation, minLocation - newMinLocation);
    }
    else {
        /* This always advances to the next line */
        maxLocation = [self _maximumSelectionLocation];
        unsigned long long proposedNewMaxLocation = HFRoundUpToNextMultipleSaturate(maxLocation, bytesPerLine);
        newMaxLocation = MIN([self contentsLength], proposedNewMaxLocation);
        HFASSERT(newMaxLocation >= maxLocation);
        locationToMakeVisible = newMaxLocation;
        additionalSelection = HFRangeMake(maxLocation, newMaxLocation - maxLocation);
    }
    
    if (modifySelection) {
        if (additionalSelection.length > 0) {
            [self _addRangeToSelection:additionalSelection];
            [self _addPropertyChangeBits:HFControllerSelectedRanges];
        }
    }
    else {
        [self _setSingleSelectedContentsRange:HFRangeMake(locationToMakeVisible, 0)];
    }
    [self _ensureVisibilityOfLocation:locationToMakeVisible];
    END_TRANSACTION();
}

- (void)deleteSelection {
    if ([self editMode] == HFOverwriteMode || ! [self editable]) {
        NSBeep();
    }
    else {
        [self _commandDeleteRanges:[HFRangeWrapper organizeAndMergeRanges:selectedContentsRanges]];
    }
}

// Called after Replace All is finished. 
- (void)replaceByteArray:(HFByteArray *)newArray {
    REQUIRE_NOT_NULL(newArray);
    EXPECT_CLASS(newArray, HFByteArray);
    HFRange entireRange = HFRangeMake(0, [self contentsLength]);
    if ([self editMode] == HFOverwriteMode && [newArray length] != entireRange.length) {
        NSBeep();
    }
    else {
        [self _commandInsertByteArrays:[NSArray arrayWithObject:newArray] inRanges:[HFRangeWrapper withRanges:&entireRange count:1] withSelectionAction:ePreserveSelection];
    }
}

- (BOOL)insertData:(NSData *)data replacingPreviousBytes:(unsigned long long)previousBytes allowUndoCoalescing:(BOOL)allowUndoCoalescing {
    REQUIRE_NOT_NULL(data);
    BOOL result;
#if ! NDEBUG
    const unsigned long long startLength = [byteArray length];
    unsigned long long expectedNewLength;
    if ([self editMode] == HFOverwriteMode) {
        expectedNewLength = startLength;
    }    
    else {
        expectedNewLength = startLength + [data length] - previousBytes;
        FOREACH(HFRangeWrapper*, wrapper, [self selectedContentsRanges]) expectedNewLength -= [wrapper HFRange].length;
    }
#endif
    HFByteSlice *slice = [[HFSharedMemoryByteSlice alloc] initWithUnsharedData:data];
    HFASSERT([slice length] == [data length]);
    HFByteArray *array = [[preferredByteArrayClass() alloc] init];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    HFASSERT([array length] == [data length]);
    result = [self insertByteArray:array replacingPreviousBytes:previousBytes allowUndoCoalescing:allowUndoCoalescing];
    [slice release];
    [array release];
#if ! NDEBUG
    HFASSERT((result && [byteArray length] == expectedNewLength) || (! result && [byteArray length] == startLength));
#endif
    return result;
}

- (BOOL)_insertionModeCoreInsertByteArray:(HFByteArray *)bytesToInsert replacingPreviousBytes:(unsigned long long)previousBytes allowUndoCoalescing:(BOOL)allowUndoCoalescing outNewSingleSelectedRange:(HFRange *)outSelectedRange {
    HFASSERT([self editMode] == HFInsertMode);
    REQUIRE_NOT_NULL(bytesToInsert);
    
    /* Guard against overflow.  If [bytesToInsert length] + [self contentsLength] - previousBytes overflows, then we can't do it */
    HFASSERT([self contentsLength] >= previousBytes);
    if (! HFSumDoesNotOverflow([bytesToInsert length], [self contentsLength] - previousBytes)) {
        return NO; //don't do anything
    }
    
    
    unsigned long long amountDeleted = 0, amountAdded = [bytesToInsert length];
    HFByteArray *bytes = [self byteArray];
    
    /* Delete all the selection - in reverse order - except the last (really first) one, which we will overwrite. */
    NSArray *allRangesToRemove = [HFRangeWrapper organizeAndMergeRanges:[self selectedContentsRanges]];
    HFRange rangeToReplace = [[allRangesToRemove objectAtIndex:0] HFRange];
    HFASSERT(rangeToReplace.location == [self _minimumSelectionLocation]);
    NSUInteger rangeIndex, rangeCount = [allRangesToRemove count];
    HFASSERT(rangeCount > 0);
    NSMutableArray *rangesToDelete = [NSMutableArray arrayWithCapacity:rangeCount - 1];
    for (rangeIndex = rangeCount - 1; rangeIndex > 0; rangeIndex--) {
        HFRangeWrapper *rangeWrapper = [allRangesToRemove objectAtIndex:rangeIndex];
        HFRange range = [rangeWrapper HFRange];
        if (range.length > 0) {
            amountDeleted = HFSum(amountDeleted, range.length);
            [rangesToDelete insertObject:rangeWrapper atIndex:0];
        }
    }
    
    if ([rangesToDelete count] > 0) {
        HFASSERT(rangesAreInAscendingOrder([rangesToDelete objectEnumerator]));
        /* TODO: This is problematic because it overwrites the selection that gets set by _activateTypingUndoCoalescingForReplacingRange:, so we lose the first selection in a multiple selection scenario. */
        [self _registerCondemnedRangesForUndo:rangesToDelete selectingRangesAfterUndo:YES];
        NSEnumerator *enumer = [rangesToDelete reverseObjectEnumerator];
        HFRangeWrapper *rangeWrapper;
        while ((rangeWrapper = [enumer nextObject])) {
            [bytes deleteBytesInRange:[rangeWrapper HFRange]];
        }
    }
    
    /* Start undo.  If we have previousBytes, remove those first. */
    if (previousBytes > 0) {
        HFASSERT(rangeToReplace.length == 0);
        HFASSERT(rangeToReplace.location >= previousBytes);
        [self _activateTypingUndoCoalescingForReplacingRange:HFRangeMake(rangeToReplace.location - previousBytes, previousBytes) withDataOfLength:0];
        rangeToReplace.location -= previousBytes;
    }
    
    /* End undo coalescing both before and after */
    if (! allowUndoCoalescing) [self _endTypingUndoCoalescingIfActive];
    [self _activateTypingUndoCoalescingForReplacingRange:rangeToReplace withDataOfLength:amountAdded];
    if (! allowUndoCoalescing) [self _endTypingUndoCoalescingIfActive];
    
    rangeToReplace.length = HFSum(rangeToReplace.length, previousBytes);
    
    /* Insert data */
#if ! NDEBUG
    unsigned long long expectedLength = [byteArray length] + [bytesToInsert length] - rangeToReplace.length;
#endif
    [byteArray insertByteArray:bytesToInsert inRange:rangeToReplace];
#if ! NDEBUG
    HFASSERT(expectedLength == [byteArray length]);
#endif
    
    /* return the new selected range */
    *outSelectedRange = HFRangeMake(HFSum(rangeToReplace.location, amountAdded), 0);
    return YES;
}


- (BOOL)_overwriteModeCoreInsertByteArray:(HFByteArray *)bytesToInsert replacingPreviousBytes:(unsigned long long)previousBytes allowUndoCoalescing:(BOOL)allowUndoCoalescing outRangeToRemoveFromSelection:(HFRange *)outRangeToRemove {
    REQUIRE_NOT_NULL(bytesToInsert);
    const unsigned long long byteArrayLength = [byteArray length];
    const unsigned long long bytesToInsertLength = [bytesToInsert length];
    HFRange firstSelectedRange = [[selectedContentsRanges objectAtIndex:0] HFRange];
    HFRange proposedRangeToOverwrite = HFRangeMake(firstSelectedRange.location, bytesToInsertLength);
    HFASSERT(proposedRangeToOverwrite.location >= previousBytes);
    proposedRangeToOverwrite.location -= previousBytes;
    if (! HFRangeIsSubrangeOfRange(proposedRangeToOverwrite, HFRangeMake(0, byteArrayLength))) {
        /* The user tried to overwrite past the end */
        NSBeep();
        return NO;
    }
    
    if (! allowUndoCoalescing) [self _endTypingUndoCoalescingIfActive];
    [self _activateTypingUndoCoalescingForOverwritingRange:proposedRangeToOverwrite];
    if (! allowUndoCoalescing) [self _endTypingUndoCoalescingIfActive];
    
    [byteArray insertByteArray:bytesToInsert inRange:proposedRangeToOverwrite];
    
    *outRangeToRemove = proposedRangeToOverwrite;
    return YES;
}

- (BOOL)insertByteArray:(HFByteArray *)bytesToInsert replacingPreviousBytes:(unsigned long long)previousBytes allowUndoCoalescing:(BOOL)allowUndoCoalescing {
#if ! NDEBUG
    if (previousBytes > 0) {
        NSArray *selectedRanges = [self selectedContentsRanges];
        HFASSERT([selectedRanges count] == 1);
        HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
        HFASSERT(selectedRange.location >= previousBytes); //don't try to delete more trailing bytes than we actually have!
    }
#endif
    REQUIRE_NOT_NULL(bytesToInsert);
    
    
    BEGIN_TRANSACTION();
    unsigned long long beforeLength = [byteArray length];
    BOOL inOverwriteMode = [self editMode] == HFOverwriteMode;
    HFRange modificationRange; //either range to remove from selection if in overwrite mode, or range to select if not
    BOOL success;
    if (inOverwriteMode) {
        success = [self _overwriteModeCoreInsertByteArray:bytesToInsert replacingPreviousBytes:previousBytes allowUndoCoalescing:allowUndoCoalescing outRangeToRemoveFromSelection:&modificationRange];
    }
    else {
        success = [self _insertionModeCoreInsertByteArray:bytesToInsert replacingPreviousBytes:previousBytes allowUndoCoalescing:allowUndoCoalescing outNewSingleSelectedRange:&modificationRange];
    }
    
    if (success) {
        /* Update our selection */
        [self _addPropertyChangeBits:HFControllerContentValue];
        [self _updateDisplayedRange];
        [self _addPropertyChangeBits:HFControllerContentValue];
        if (inOverwriteMode) {
            [self _removeRangeFromSelection:modificationRange withCursorLocationIfAllSelectionRemoved:HFMaxRange(modificationRange)];
            [self maximizeVisibilityOfContentsRange:[[selectedContentsRanges objectAtIndex:0] HFRange]];
        }
        else {
            [self _setSingleSelectedContentsRange:modificationRange];
            [self maximizeVisibilityOfContentsRange:modificationRange];
        }
        if (beforeLength != [byteArray length]) [self _addPropertyChangeBits:HFControllerContentLength];
    }
    END_TRANSACTION();
    return success;
}

- (void)deleteDirection:(HFControllerMovementDirection)direction {
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    if ([self editMode] != HFInsertMode) {
        NSBeep();
        return;
    }
    unsigned long long minSelection = [self _minimumSelectionLocation];
    unsigned long long maxSelection = [self _maximumSelectionLocation];
    if (maxSelection != minSelection) {
        [self deleteSelection];
    }
    else {
        HFRange rangeToDelete = HFRangeMake(minSelection, 1);
        BOOL rangeIsValid;
        if (direction == HFControllerDirectionLeft) {
            rangeIsValid = (rangeToDelete.location > 0);
            rangeToDelete.location--;
        }
        else {
            rangeIsValid = (rangeToDelete.location < [self contentsLength]);
        }
        if (rangeIsValid) {
            BEGIN_TRANSACTION();
            [self _activateTypingUndoCoalescingForReplacingRange:rangeToDelete withDataOfLength:0];
            [byteArray deleteBytesInRange:rangeToDelete];
            [self _setSingleSelectedContentsRange:HFRangeMake(rangeToDelete.location, 0)];
            [self _updateDisplayedRange];
            [self _addPropertyChangeBits:HFControllerSelectedRanges | HFControllerContentValue | HFControllerContentLength];
            END_TRANSACTION();
        }
    }
}

- (HFEditMode)editMode {
    return _hfflags.editMode;
}

- (void)setEditMode:(HFEditMode)val
{
    if (val != _hfflags.editMode) {
        _hfflags.editMode = val;
        // don't allow undo coalescing when switching modes
        [self _endTypingUndoCoalescingIfActive];
        [self _addPropertyChangeBits:HFControllerEditable];        
    }
}

+ (BOOL)prepareForChangeInFile:(NSURL *)targetFile fromWritingByteArray:(HFByteArray *)array {
    REQUIRE_NOT_NULL(targetFile);
    REQUIRE_NOT_NULL(array);
    HFFileReference *fileReference = [[HFFileReference alloc] initWithPath:[targetFile path] error:NULL];
    if (! fileReference) return YES; //good luck writing that sucker
    // note: that check will need to be updated to create a privileged file reference, if we ever support writing to root-owned files
    
    BOOL shouldCancel = NO;
    NSValue *shouldCancelPointer = [NSValue valueWithPointer:&shouldCancel];
    
    NSArray *changedRanges = [array rangesOfFileModifiedIfSavedToFile:fileReference];
    if ([changedRanges count] > 0) { //don't bother if nothing is changing
        NSMutableDictionary *hint = [[NSMutableDictionary alloc] init];
        NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:array, HFChangeInFileByteArrayKey, changedRanges, HFChangeInFileModifiedRangesKey, shouldCancelPointer, HFChangeInFileShouldCancelKey, hint, HFChangeInFileHintKey, nil];
        [[NSNotificationCenter defaultCenter] postNotificationName:HFPrepareForChangeInFileNotification object:fileReference userInfo:userInfo];
        [hint release];
        [userInfo release];
    }
    [fileReference release];
    return ! shouldCancel;
}

- (BOOL)clearUndoManagerDependenciesOnRanges:(NSArray *)ranges inFile:(HFFileReference *)reference hint:(NSMutableDictionary *)hint {
    REQUIRE_NOT_NULL(ranges);
    REQUIRE_NOT_NULL(reference);
    /* Try to clear the dependencies that undoOperations has.  If we can't, we'll have to remove them all. */
    BOOL success = YES;
    /* undoer is either a HFControllerMultiRangeUndo or a HFControllerCoalescedUndo */
    FOREACH(id, undoer, undoOperations) {
        if (! [undoer clearDependenciesOnRanges:ranges inFile:reference hint:hint]) {
            success = NO;
            break;
        }
    }
    if (! success) [self _removeAllUndoOperations];
    return success;
}

#if BENCHMARK_BYTEARRAYS

+ (void)_testByteArray {
    HFByteArray* first = [[[HFFullMemoryByteArray alloc] init] autorelease];
    HFBTreeByteArray* second = [[[HFBTreeByteArray alloc] init] autorelease];    
    first = nil;
    //    second = nil;
    
    //srandom(time(NULL));
    
    unsigned opCount = 4096 * 512;
    unsigned long long expectedLength = 0;
    unsigned i;
    for (i=1; i <= opCount; i++) {
        NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
        NSUInteger op;
        const unsigned long long length = [first length];
        unsigned long long offset;
        unsigned long long number;
        switch ((op = (random()%2))) {
            case 0: { //insert
                offset = random() % (1 + length);
                HFByteSlice* slice = [[HFRandomDataByteSlice alloc] initWithRandomDataLength: 1 + random() % 1000];
                [first insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
                [second insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
                expectedLength += [slice length];
                [slice release];
                break;
            }
            case 1: { //delete
                if (length > 0) {
                    offset = random() % length;
                    number = 1 + random() % (length - offset);
                    [first deleteBytesInRange:HFRangeMake(offset, number)];
                    [second deleteBytesInRange:HFRangeMake(offset, number)];
                    expectedLength -= number;
                }
                break;
            }
        }
        [pool drain];
    }
}

+ (void)_testAttributeArrays {
    HFByteRangeAttributeArray *naiveTree = [[HFNaiveByteRangeAttributeArray alloc] init];
    HFAnnotatedTreeByteRangeAttributeArray *smartTree = [[HFAnnotatedTreeByteRangeAttributeArray alloc] init];
    naiveTree = nil;
    //    smartTree = nil;
    
    NSString * const attributes[3] = {@"Alpha", @"Beta", @"Gamma"};
    
    const NSUInteger supportedIndexEnd = NSNotFound;
    NSUInteger round;
    for (round = 0; round < 4096 * 256; round++) {
        NSString *attribute = attributes[random() % (sizeof attributes / sizeof *attributes)];
        BOOL insert = ([smartTree isEmpty] || [naiveTree isEmpty] || (random() % 2));
        
        unsigned long long end = random();
        unsigned long long start = random();
        if (end < start) {
            unsigned long long temp = end;
            end = start;
            start = temp;
        }
        HFRange range = HFRangeMake(start, end - start);
        
        if (insert) {
            [naiveTree addAttribute:attribute range:range];
            [smartTree addAttribute:attribute range:range];
        }
        else {
            [naiveTree removeAttribute:attribute range:range];
            [smartTree removeAttribute:attribute range:range];
        }
    }
    
    [naiveTree release];
    [smartTree release];
}


+ (void)initialize {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    srandom(0);
    [self _testByteArray];
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    printf("Byte array time: %f\n", end - start);
    
    srandom(0);
    start = CFAbsoluteTimeGetCurrent();
    [self _testAttributeArrays];
    end = CFAbsoluteTimeGetCurrent();
    printf("Attribute array time: %f\n", end - start);
    
    exit(0);
}

#endif

#if HFUNIT_TESTS

+ (void)initialize {
    if (self == [HFController class]) {
        objc_msgSend(objc_getClass("HFUnitTests"), @selector(runAllTests));
    }
}
#endif

@end
