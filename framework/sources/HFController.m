//
//  HFController.m
//  HexFiend_2
//
//  Created by Peter Ammon on 11/3/07.
//  Copyright 2007 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFController.h>
#import <HexFiend/HFRepresenter_Internal.h>
#import <HexFiend/HFByteArray_Internal.h>
#import <HexFiend/HFFullMemoryByteArray.h>
#import <HexFiend/HFBTreeByteArray.h>
#import <HexFiend/HFFullMemoryByteSlice.h>
#import <HexFiend/HFControllerCoalescedUndo.h>
#import <HexFiend/HFSharedMemoryByteSlice.h>
#import <HexFiend/HFRandomDataByteSlice.h>
#import <HexFiend/HFFileReference.h>

#if HFUNIT_TESTS
#import <HexFiend/HFFileByteSlice.h>
#import <HexFiend/HFTestHashing.h>
#import <HexFiend/HFRandomDataByteSlice.h>
#include <sys/stat.h>
#endif

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
@end

static inline Class preferredByteArrayClass(void) {
    return [HFBTreeByteArray class];
}

#if HFUNIT_TESTS
@interface HFByteArray (HFUnitTests)
+ (void)_testSearchAlgorithmsLookingForArray:(HFByteArray *)needle inArray:(HFByteArray *)haystack;
@end
#endif

@implementation HFController

- (void)_sharedInit {
    selectedContentsRanges = [[NSMutableArray alloc] initWithObjects:[HFRangeWrapper withRange:HFRangeMake(0, 0)], nil];
    byteArray = [[preferredByteArrayClass() alloc] init];
    [byteArray addObserver:self forKeyPath:@"changesAreLocked" options:0 context:KVOContextChangesAreLocked];
    selectionAnchor = NO_SELECTION;    
}

- (id)init {
    [super init];
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
    [coder encodeBool:_hfflags.overwriteMode forKey:@"HFOverwriteMode"];
    [coder encodeBool:_hfflags.editable forKey:@"HFEditable"];
    [coder encodeBool:_hfflags.selectable forKey:@"HFSelectable"];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super init];
    [self _sharedInit];
    bytesPerLine = (NSUInteger)[coder decodeInt64ForKey:@"HFBytesPerLine"];
    bytesPerColumn = (NSUInteger)[coder decodeInt64ForKey:@"HFBytesPerColumn"];
    font = [[coder decodeObjectForKey:@"HFFont"] retain];
    lineHeight = (CGFloat)[coder decodeDoubleForKey:@"HFLineHeight"];
    _hfflags.antialias = [coder decodeBoolForKey:@"HFAntialias"];
    _hfflags.overwriteMode = [coder decodeBoolForKey:@"HFOverwriteMode"];
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
    NSDictionary *userInfo = [[NSDictionary alloc] initWithObjects:&number forKeys:&HFControllerChangedPropertiesKey count:1];
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
    HFRange maximumDisplayedRangeSet = HFRangeMake(0, HFRoundUpToNextMultiple(contentsLength, bytesPerLine));
    return maximumDisplayedRangeSet;
}

- (unsigned long long)totalLineCount {
    return HFRoundUpToNextMultiple([self contentsLength], bytesPerLine) / bytesPerLine;
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
    
    NEW_ARRAY(unsigned long long, partitions, [cleanedRanges count] + 2);
    NSUInteger partitionCount, partitionIndex = 0;
    
    partitions[partitionIndex++] = selectionAnchorRange.location;
    FOREACH(HFRangeWrapper*, wrapper, cleanedRanges) {
        HFRange range = [wrapper HFRange];
        if (! HFIntersectsRange(range, selectionAnchorRange)) continue;
        
        partitions[partitionIndex++] = MAX(selectionAnchorRange.location, range.location);
        partitions[partitionIndex++] = MIN(HFMaxRange(selectionAnchorRange), HFMaxRange(range));
    }
    partitions[partitionIndex++] = HFMaxRange(selectionAnchorRange);
    
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
            NSLog(@"Bad max bytes: %lu (%lu)", maxBytesForViewSize, bytesPerLine);
        }
        if ((HFMaxRange(maxRangeSet) - proposedNewDisplayRange.location) % bytesPerLine != 0) {
            NSLog(@"Bad max range minus: %llu (%lu)", HFMaxRange(maxRangeSet) - proposedNewDisplayRange.location, bytesPerLine);
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
    unsigned long long endLine = HFRoundUpToNextMultiple(HFMaxRange(range), bytesPerLine) / bytesPerLine;
    HFASSERT(endLine > startLine);
    long double linesInRange = HFULToFP(endLine - startLine);
    long double linesToDisplay = MIN(displayRange.length, linesInRange);
    HFASSERT(linesToDisplay <= linesInRange);
    long double linesToMoveDownToMakeLastLineVisible = HFULToFP(endLine) - (displayRange.location + displayRange.length);
    long double linesToMoveUpToMakeFirstLineVisible = displayRange.location - HFULToFP(startLine);
    HFASSERT(linesToMoveUpToMakeFirstLineVisible <= 0 || linesToMoveDownToMakeLastLineVisible <= 0);
    if (linesToMoveDownToMakeLastLineVisible > 0) {
        newDisplayRange.location += linesToMoveDownToMakeLastLineVisible;
    }
    else if (linesToMoveUpToMakeFirstLineVisible > 0 && linesToDisplay >= 1) {
	// the >= 1 check prevents some wacky behavior when we have less than one line's worth of space, that caused bouncing between the top and bottom of the line
        newDisplayRange.location -= linesToMoveUpToMakeFirstLineVisible;
    }
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

- (void)setUndoManager:(NSUndoManager *)manager {
    [self _removeUndoManagerNotifications];
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
    return _hfflags.editable && ! [byteArray changesAreLocked];
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
    if (remainingProperties) {
        NSLog(@"Unknown properties: %lx", remainingProperties);
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

- (void)continueSelectionWithEvent:(NSEvent *)event forByteIndex:(unsigned long long)characterIndex {
    USE(event);
    HFASSERT(_hfflags.selectionInProgress);
    HFASSERT(characterIndex <= [self contentsLength]);
    if (_hfflags.commandExtendSelection) {
#if 0
        /* Clear any zero-length ranges */
        NSUInteger rangeIndex = [selectedContentsRanges count];
        while (rangeIndex-- > 0) {
            if ([[selectedContentsRanges objectAtIndex:rangeIndex] HFRange].length == 0) [selectedContentsRanges removeObjectAtIndex:rangeIndex];
        }
#endif
        selectionAnchorRange.location = MIN(characterIndex, selectionAnchor);
        selectionAnchorRange.length = MAX(characterIndex, selectionAnchor) - selectionAnchorRange.location;
        [self _addPropertyChangeBits:HFControllerSelectedRanges];
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
    long double scrollY = - kScrollMultiplier * [scrollEvent deltaY];
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

#if ! NDEBUG
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
#endif

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
    
    if (result) [[manager prepareWithInvocationTarget:self] _commandInsertByteArrays:correspondingByteArrays inRanges:rangesToRestore withSelectionAction:(selectAfterUndo ? eSelectResult : eSelectAfterResult)];
    
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
    [[[self undoManager] prepareWithInvocationTarget:self] _commandInsertByteArrays:byteArraysToInsertOnUndo inRanges:rangesToInsertOnUndo withSelectionAction:(selectionAction == ePreserveSelection ? ePreserveSelection : eSelectAfterResult)];
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
    
    END_TRANSACTION();
}

- (void)_activateTypingUndoCoalescingForOverwritingRange:(HFRange)rangeToReplace {
    HFASSERT(HFRangeIsSubrangeOfRange(rangeToReplace, HFRangeMake(0, [self contentsLength])));
    HFASSERT(rangeToReplace.length > 0);
    HFByteArray *bytes = [self byteArray];
    
    //undoCoalescer may be nil here
    BOOL replaceUndoCoalescer = ! [undoCoalescer canCoalesceOverwriteAtLocation:rangeToReplace.location];
    
    if (replaceUndoCoalescer) {
        [undoCoalescer release];
        HFByteArray *replacedData = [bytes subarrayWithRange:rangeToReplace];
        undoCoalescer = [[HFControllerCoalescedUndo alloc] initWithOverwrittenData:replacedData atAnchorLocation:rangeToReplace.location];
        [[self undoManager] registerUndoWithTarget:self selector:@selector(_performTypingUndo:) object:undoCoalescer];
    }
    else {
        [undoCoalescer overwriteDataInRange:rangeToReplace withByteArray:bytes];
    }
    
}

- (void)_activateTypingUndoCoalescingForReplacingRange:(HFRange)rangeToReplace withDataOfLength:(unsigned long long)dataLength {
    HFASSERT(HFRangeIsSubrangeOfRange(rangeToReplace, HFRangeMake(0, [self contentsLength])));
    HFASSERT(dataLength > 0 || rangeToReplace.length > 0);
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
        [undoCoalescer release];
        HFByteArray *replacedData = (rangeToReplace.length == 0 ? nil : [bytes subarrayWithRange:rangeToReplace]);
        undoCoalescer = [[HFControllerCoalescedUndo alloc] initWithReplacedData:replacedData atAnchorLocation:rangeToReplace.location];
        if (dataLength > 0) [undoCoalescer appendDataOfLength:dataLength];
        [[self undoManager] registerUndoWithTarget:self selector:@selector(_performTypingUndo:) object:undoCoalescer];
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
    HFASSERT(granularity == HFControllerMovementByte || granularity == HFControllerMovementLine || granularity == HFControllerMovementPage || granularity == HFControllerMovementDocument);
    HFASSERT(direction == HFControllerDirectionLeft || direction == HFControllerDirectionRight);
    unsigned long long bytesToMove = 0;
    switch (granularity) {
	case HFControllerMovementByte:
	    bytesToMove = 1;
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
	unsigned long long proposedNewMaxLocation = HFRoundUpToNextMultiple(maxLocation, bytesPerLine);
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
    if ([self inOverwriteMode]) {
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
    if ([self inOverwriteMode] && [newArray length] != entireRange.length) {
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
    unsigned long long expectedNewLength;
    if ([self inOverwriteMode]) {
        expectedNewLength = [byteArray length];
    }    
    else {
        expectedNewLength = [byteArray length] + [data length] - previousBytes;
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
    HFASSERT([byteArray length] == expectedNewLength);
#endif
    return result;
}

- (BOOL)_insertionModeCoreInsertByteArray:(HFByteArray *)bytesToInsert replacingPreviousBytes:(unsigned long long)previousBytes allowUndoCoalescing:(BOOL)allowUndoCoalescing outNewSingleSelectedRange:(HFRange *)outSelectedRange {
    HFASSERT(! [self inOverwriteMode]);
    REQUIRE_NOT_NULL(bytesToInsert);
    
    unsigned long long amountDeleted = 0, amountAdded = [bytesToInsert length];
    HFByteArray *bytes = [self byteArray];

    /* Delete all the selection - in reverse order - except the last one, which we will overwrite.  TODO - make this undoable. */
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
    BOOL inOverwriteMode = [self inOverwriteMode];
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
    if ([self inOverwriteMode]) {
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

- (BOOL)inOverwriteMode {
    return _hfflags.overwriteMode;
}

- (void)setInOverwriteMode:(BOOL)val {
    _hfflags.overwriteMode = val;
    // don't allow undo coalescing across switching between overwrite mode
    [self _endTypingUndoCoalescingIfActive];
}

- (BOOL)requiresOverwriteMode {
    return NO;
}

+ (BOOL)prepareForChangeInFile:(NSURL *)targetFile fromWritingByteArray:(HFByteArray *)array {
    REQUIRE_NOT_NULL(targetFile);
    REQUIRE_NOT_NULL(array);
    HFFileReference *fileReference = [[HFFileReference alloc] initWithPath:[targetFile path] error:NULL];
    if (! fileReference) return YES; //good luck writing that sucker
    
    BOOL shouldCancel = NO;
    NSValue *shouldCancelPointer = [NSValue valueWithPointer:&shouldCancel];
    
    NSArray *changedRanges = [array rangesOfFileModifiedIfSavedToFile:fileReference];
    if ([changedRanges count] > 0) { //don't bother if nothing is changing
	NSDictionary *userInfo = [[NSDictionary alloc] initWithObjectsAndKeys:array, HFChangeInFileByteArrayKey, changedRanges, HFChangeInFileModifiedRangesKey, shouldCancelPointer, HFChangeInFileShouldCancelKey, nil];
	[[NSNotificationCenter defaultCenter] postNotificationName:HFPrepareForChangeInFileNotification object:fileReference userInfo:userInfo];
	[userInfo release];
    }
    [fileReference release];
    return ! shouldCancel;
}

#if BENCHMARK_BYTEARRAYS

+ (void)_testByteArray {
    //HFByteArray* first = [[[HFFullMemoryByteArray alloc] init] autorelease];
    HFByteArray *first = nil;
    HFBTreeByteArray* second = [[[HFBTreeByteArray alloc] init] autorelease];    
    
    //srandom(time(NULL));
    
    unsigned opCount = 9000000;
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

+ (void)initialize {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    srandom(0);
    [self _testByteArray];
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    printf("Time: %f\n", end - start);
}

#endif

#if HFUNIT_TESTS
#define HFTEST(a) do { if (! (a)) { printf("Test failed on line %u of file %s: %s\n", __LINE__, __FILE__, #a); exit(0); } } while (0)

static NSData *randomDataOfLength(NSUInteger length) {
    if (! length) return [NSData data];
    
    unsigned char* buff = check_malloc(length);
    
    unsigned* word = (unsigned*)buff;
    NSUInteger wordCount = length / sizeof *word;
    NSUInteger i;
    unsigned randBits = 0;
    unsigned numUsedRandBits = 31;
    for (i=0; i < wordCount; i++) {
        if (numUsedRandBits >= 31) {
            randBits = (unsigned)random();
            numUsedRandBits = 0;
        }
        unsigned randVal = (unsigned)random() << 1;
        randVal |= (randBits & 1);
        randBits >>= 1;
        numUsedRandBits++;
        word[i] = randVal;
    }
    
    NSUInteger byteIndex = wordCount * sizeof *word;
    while (byteIndex < length) {
        buff[byteIndex++] = random() & 0xFF;
    }
    
    return [NSData dataWithBytesNoCopy:buff length:length freeWhenDone:YES];
}

+ (void)_testFastMemchr {
    unsigned char searchChar = 0xAE;
    unsigned char fillerChar = 0x23;
    const NSUInteger baseOffsets[] = {0, 16, 32, 57, 93, 128, 255, 1017, 2297, 3000, 3152};
    const NSUInteger buffLen = 4099;
    unsigned char *buff = malloc(buffLen);
    HFTEST(buff != NULL);
    [randomDataOfLength(buffLen) getBytes:buff];
    /* Replace instances of searchChar with fillerChar */
    for (NSUInteger i=0; i < buffLen; i++) {
        if (buff[i] == searchChar) buff[i] = fillerChar;
    }
    
    for (NSUInteger i=0; i < sizeof baseOffsets / sizeof *baseOffsets; i++) {
        NSUInteger baseOffset = baseOffsets[i];
        unsigned char stored[16];
        memcpy(stored, buff + baseOffset, sizeof stored);
        for (unsigned int mask = 0; mask <= USHRT_MAX; mask++) {
            /* For each bit set in mask, set the corresponding byte to searchChar */
            unsigned short tempMask = mask;
            while (tempMask != 0) {
                int lsb = __builtin_ffs(tempMask) - 1;
                buff[baseOffset + lsb] = searchChar;
                tempMask &= (tempMask - 1);
            }
            HFTEST(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
            memcpy(buff + baseOffset, stored, sizeof stored);
        }
    }
    
    NSUInteger remaining = buffLen;
    while (remaining--) {
        buff[remaining] = searchChar;
        HFTEST(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
    }
    remaining = buffLen;
    while (remaining--) {
        buff[remaining] = fillerChar;
        HFTEST(memchr(buff, searchChar, buffLen) == HFFastMemchr(buff, searchChar, buffLen));
    }
}

+ (void)_testRangeFunctions {
    HFRange range = HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL);
    HFTEST(range.location == UINT_MAX + 573ULL && range.length == UINT_MAX * 2ULL);
    HFTEST(range.location == UINT_MAX + 573ULL && range.length == UINT_MAX * 2ULL);
    HFTEST(HFRangeIsSubrangeOfRange(range, range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length, 0), range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), HFRangeMake(range.location, 0)));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location, 0), HFRangeMake(range.location + 1, 0)));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + 6, 0), range));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length, 0), range));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(range.location + range.length + 1, 0), range));
    HFTEST(! HFRangeIsSubrangeOfRange(range, HFRangeMake(34, 0)));
    HFTEST(HFRangeIsSubrangeOfRange(range, HFRangeMake(range.location - 32, range.length + 54)));
    HFTEST(HFRangeIsSubrangeOfRange(range, HFRangeMake(0, ULLONG_MAX)));
    HFTEST(! HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 23), HFRangeMake(ULLONG_MAX - 3, 23)));
    HFTEST(HFRangeIsSubrangeOfRange(HFRangeMake(ULLONG_MAX - 2, 22), HFRangeMake(ULLONG_MAX - 3, 23)));
    
    HFTEST(HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL)));
    HFTEST(! HFRangeEqualsRange(range, HFRangeMake(UINT_MAX + 573ULL, UINT_MAX * 2ULL + 1)));
    
    HFTEST(HFIntersectsRange(range, HFRangeMake(UINT_MAX + 3ULL, UINT_MAX * 2ULL + 1)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(3, 0)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 0), HFRangeMake(3, 0)));
    HFTEST(HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(3, 3)));
    HFTEST(! HFIntersectsRange(HFRangeMake(3, 3), HFRangeMake(6, 0)));
    
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(range, range), range));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(0, 25), HFRangeMake(10, 11)), HFRangeMake(10, 11)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(15, 10)), HFRangeMake(15, 6)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(150, 10)), HFRangeMake(0, 0)));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(0, 25), HFRangeMake(10, 11)), HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(0, 25))));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(15, 10)), HFIntersectionRange(HFRangeMake(15, 10), HFRangeMake(10, 11))));
    HFTEST(HFRangeEqualsRange(HFIntersectionRange(HFRangeMake(10, 11), HFRangeMake(150, 10)), HFIntersectionRange(HFRangeMake(150, 10), HFRangeMake(10, 11))));
    
    HFTEST(HFRangeEqualsRange(HFUnionRange(HFRangeMake(1, 3), HFRangeMake(2, 3)), HFRangeMake(1, 4)));
    HFTEST(HFRangeEqualsRange(HFUnionRange(HFRangeMake(1, 3), HFRangeMake(4, 4)), HFRangeMake(1, 7)));
    
    HFTEST(HFSumDoesNotOverflow(ULLONG_MAX, 0));
    HFTEST(! HFSumDoesNotOverflow(ULLONG_MAX, 1));
    HFTEST(HFSumDoesNotOverflow(ULLONG_MAX / 2, ULLONG_MAX / 2));
    HFTEST(HFSumDoesNotOverflow(0, 0));
    HFTEST(ll2l((unsigned long long)UINT_MAX) == UINT_MAX);
    
    HFTEST(HFRoundUpToNextMultiple(0, 2) == 2);
    HFTEST(HFRoundUpToNextMultiple(2, 2) == 4);
    HFTEST(HFRoundUpToNextMultiple(200, 200) == 400);
    HFTEST(HFRoundUpToNextMultiple(1304, 600) == 1800);
    
    const HFRange dirtyRanges1[] = { {4, 6}, {6, 2}, {7, 3} };
    const HFRange cleanedRanges1[] = { {4, 6} };
    
    const HFRange dirtyRanges2[] = { {4, 6}, {6, 2}, {50, 5}, {7, 3}, {50, 1}};
    const HFRange cleanedRanges2[] = { {4, 6}, {50, 5} };
    
    const HFRange dirtyRanges3[] = { {40, 50}, {10, 20} };
    const HFRange cleanedRanges3[] = { {10, 20}, {40, 50} };
    
    const HFRange dirtyRanges4[] = { {11, 3}, {5, 6}, {23, 54} };
    const HFRange cleanedRanges4[] = { {5, 9}, {23, 54} };
    
    
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges1 count:sizeof dirtyRanges1 / sizeof *dirtyRanges1]] isEqual:[HFRangeWrapper withRanges:cleanedRanges1 count:sizeof cleanedRanges1 / sizeof *cleanedRanges1]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges2 count:sizeof dirtyRanges2 / sizeof *dirtyRanges2]] isEqual:[HFRangeWrapper withRanges:cleanedRanges2 count:sizeof cleanedRanges2 / sizeof *cleanedRanges2]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges3 count:sizeof dirtyRanges3 / sizeof *dirtyRanges3]] isEqual:[HFRangeWrapper withRanges:cleanedRanges3 count:sizeof cleanedRanges3 / sizeof *cleanedRanges3]]);
    HFASSERT([[HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges4 count:sizeof dirtyRanges4 / sizeof *dirtyRanges4]] isEqual:[HFRangeWrapper withRanges:cleanedRanges4 count:sizeof cleanedRanges4 / sizeof *cleanedRanges4]]);
    //NSLog(@"%@", [HFRangeWrapper organizeAndMergeRanges:[HFRangeWrapper withRanges:dirtyRanges4 count:sizeof dirtyRanges4 / sizeof *dirtyRanges4]]);
}

static NSUInteger random_upto(unsigned long long val) {
    if (val == 0) return 0;
    else return ll2l(random() % val);
}

#define DEBUG if (should_debug)  
+ (void)_testTextInsertion {
    const BOOL should_debug = NO;
    DEBUG puts("Beginning data insertion test");
    NSMutableData *expectedData = [NSMutableData data];
    HFController *controller = [[[self alloc] init] autorelease];
    [controller setByteArray:[[[HFFullMemoryByteArray alloc] init] autorelease]];
    NSUndoManager *undoer = [[[NSUndoManager alloc] init] autorelease];
    [undoer setGroupsByEvent:NO];
    [controller setUndoManager:undoer];
    NSMutableArray *expectations = [NSMutableArray arrayWithObject:[NSData data]];
    NSUInteger i, opCount = 5000;
    unsigned long long coalescerActionPoint = ULLONG_MAX;
    for (i=1; i <= opCount; i++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        const NSUInteger length = ll2l([controller contentsLength]);
        
        NSRange replacementRange = {0, 0};
        NSUInteger replacementDataLength = 0;
        while (replacementRange.length == 0 && replacementDataLength == 0) {
            replacementRange.location = random_upto(length);
            replacementRange.length = random_upto(length - replacementRange.location);
            replacementDataLength = random_upto(20);
        }
        NSData *replacementData = randomDataOfLength(replacementDataLength);
        [expectedData replaceBytesInRange:replacementRange withBytes:[replacementData bytes] length:[replacementData length]];
        
        HFRange selectedRange = HFRangeMake(replacementRange.location, replacementRange.length);
        
        BOOL shouldCoalesceDelete = (replacementDataLength == 0 && HFMaxRange(selectedRange) == coalescerActionPoint);
        BOOL shouldCoalesceInsert = (replacementRange.length == 0 && selectedRange.location == coalescerActionPoint);
        
        [controller setSelectedContentsRanges:[HFRangeWrapper withRanges:&selectedRange count:1]];
        HFTEST([[controller selectedContentsRanges] isEqual:[HFRangeWrapper withRanges:&selectedRange count:1]]);
        
        BOOL expectedCoalesced = (shouldCoalesceInsert || shouldCoalesceDelete);
        HFControllerCoalescedUndo *previousUndoCoalescer = controller->undoCoalescer;
        /* If our changes should be coalesced, then we do not add an undo group, because it would just create an empty group that would interfere with our undo/redo tests below */
        if (! expectedCoalesced) [undoer beginUndoGrouping];
        
        [controller insertData:replacementData replacingPreviousBytes:0 allowUndoCoalescing:YES];
        BOOL wasCoalesced = (controller->undoCoalescer == previousUndoCoalescer);
        HFTEST(expectedCoalesced == wasCoalesced);
        
        HFTEST([[controller byteArray] _debugIsEqualToData:expectedData]);
        if (wasCoalesced) [expectations removeLastObject];
        [expectations addObject:[[expectedData copy] autorelease]];
        
        if (! expectedCoalesced) [undoer endUndoGrouping];
        
        [pool drain];
        
        coalescerActionPoint = HFSum(replacementRange.location, replacementDataLength);
    }
    
    NSUInteger expectationIndex = [expectations count] - 1;
    
    HFTEST([[controller byteArray] _debugIsEqualToData:[expectations objectAtIndex:expectationIndex]]);
    
    for (i=1; i <= opCount; i++) {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        NSInteger expectationIndexChange;
        if (expectationIndex == [expectations count] - 1) {
            expectationIndexChange = -1;
        }
        else if (expectationIndex == 0) {
            expectationIndexChange = 1;
        }
        else {
            expectationIndexChange = ((random() & 1) ? -1 : 1);
        }
        expectationIndex += expectationIndexChange;
        if (expectationIndexChange > 0) {
            DEBUG printf("About to redo %lu %lu\n", (unsigned long)i, (unsigned long)expectationIndex);
            HFTEST([undoer canRedo]);
            [undoer redo];
        }
        else {
            DEBUG printf("About to undo %lu %ld=u\n", (unsigned long)i, (unsigned long)expectationIndex);
            HFTEST([undoer canUndo]);
            [undoer undo]; 
        }
        
        DEBUG printf("Index %lu %lu\n", (unsigned long)i, (unsigned long)expectationIndex);
        HFTEST([[controller byteArray] _debugIsEqualToData:[expectations objectAtIndex:expectationIndex]]);
        
        [pool drain];
    }
    
    DEBUG puts("Done!");
}

+ (void)_testByteArray {
    const BOOL should_debug = NO;
    DEBUG puts("Beginning TAVL Tree test:");
    HFByteArray* first = [[[HFFullMemoryByteArray alloc] init] autorelease];
    HFBTreeByteArray* second = [[[HFBTreeByteArray alloc] init] autorelease];    
    
    //srandom(time(NULL));
    
    unsigned opCount = 50000;
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
		NSData *data = randomDataOfLength(1 + random()%1000);
		offset = random() % (1 + length);
		HFByteSlice* slice = [[HFFullMemoryByteSlice alloc] initWithData:data];
		DEBUG printf("%u)\tInserting %llu bytes at %llu...", i, [slice length], offset);
		[first insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
		[second insertByteSlice:slice inRange:HFRangeMake(offset, 0)];
		expectedLength += [data length];
		[slice release];
		break;
	    }
	    case 1: { //delete
		if (length > 0) {
		    offset = random() % length;
		    number = 1 + random() % (length - offset);
		    DEBUG printf("%u)\tDeleting at %llu for %llu...", i, offset, number);
		    [first deleteBytesInRange:HFRangeMake(offset, number)];
		    [second deleteBytesInRange:HFRangeMake(offset, number)];
		    expectedLength -= number;
		}
		else DEBUG printf("%u)\tLength of zero, no delete...", i);
		break;
	    }
	}
	[pool drain];
	fflush(NULL);
	if ([first _debugIsEqual:second]) {
	    DEBUG printf("OK! Length: %llu\t%s\n", [second length], [[second description] UTF8String]);
	}
	else {
	    DEBUG printf("Error! expected length: %llu mem length: %llu tavl length:%llu desc: %s\n", expectedLength, [first length], [second length], [[second description] UTF8String]);
	    exit(EXIT_FAILURE);
	}
    }
    DEBUG puts("Done!");
    DEBUG printf("%s\n", [[second description] UTF8String]);
}

+ (void)_testRandomOperationFileWriting {
    const BOOL should_debug = NO;
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    NSData *data = randomDataOfLength(1 << 16);
    NSURL *fileURL = [NSURL fileURLWithPath:@"/tmp/HexFiendTestFile.data"];
    NSURL *asideFileURL = [NSURL fileURLWithPath:@"/tmp/HexFiendTestFile_External.data"];
    if (! [data writeToURL:fileURL atomically:NO]) {
        [NSException raise:NSGenericException format:@"Unable to write test data to %@", fileURL];
    }
    HFFileReference *ref = [[[HFFileReference alloc] initWithPath:[fileURL path] error:NULL] autorelease];
    HFTEST([ref length] == [data length]);
    
    HFByteSlice *slice = [[[HFFileByteSlice alloc] initWithFile:ref] autorelease];
    
    HFByteArray *array = [[[preferredByteArrayClass() alloc] init] autorelease];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    HFTEST([HFHashByteArray(array) isEqual:HFHashFile(fileURL)]);
    
    NSUInteger i, op, opCount = 20;
    unsigned long long expectedLength = [data length];
    for (i=0; i < opCount; i++) {
        HFTEST([array length] == expectedLength);
        HFRange replacementRange;
        replacementRange.location = random_upto(expectedLength);
        replacementRange.length = random_upto(expectedLength - replacementRange.location);
        switch (op = (random() % 8)) {
            case 0: {
                /* insert */
                HFByteSlice *slice = [[[HFSharedMemoryByteSlice alloc] initWithUnsharedData:randomDataOfLength(random_upto(1000))] autorelease];
                [array insertByteSlice:slice inRange:replacementRange];
                expectedLength = expectedLength + [slice length] - replacementRange.length;
                DEBUG printf("%lu inserting %llu in {%llu, %llu}\n", (unsigned long)i, [slice length], replacementRange.location, replacementRange.length);
                break;
            }
            case 1: {
                /* delete */
                [array deleteBytesInRange:replacementRange];
                expectedLength -= replacementRange.length;
                DEBUG printf("%lu deleting in {%llu, %llu}\n", (unsigned long)i, replacementRange.location, replacementRange.length);
                break;
            }
            default: {
                /* transfer/delete */
                HFRange sourceRange;
                sourceRange.location = random_upto(expectedLength);
                sourceRange.length = random_upto(expectedLength - sourceRange.location);
                HFByteArray *subarray = [array subarrayWithRange:sourceRange];
                [array insertByteArray:subarray inRange:replacementRange];
                expectedLength = expectedLength + sourceRange.length - replacementRange.length;
                DEBUG printf("%lu moving {%llu, %llu} to {%llu, %llu}\n", (unsigned long)i, sourceRange.location, sourceRange.length, replacementRange.location, replacementRange.length);
                break;
            }
        }
    }
    
    //[array insertByteSlice:[[[HFSharedMemoryByteSlice alloc] initWithUnsharedData:[NSData dataWithBytes:"Z" length:1]] autorelease] inRange:HFRangeMake(0, 0)];
    
    NSData *arrayHash = HFHashByteArray(array);
    
    HFTEST([array writeToFile:asideFileURL trackingProgress:NULL error:NULL]);
    HFTEST([arrayHash isEqual:HFHashFile(asideFileURL)]);
    
    HFTEST([array writeToFile:fileURL trackingProgress:NULL error:NULL]);
    HFTEST([arrayHash isEqual:HFHashFile(fileURL)]);
    
    [[NSFileManager defaultManager] removeFileAtPath:[fileURL path] handler:nil];
    [pool drain];
}

+ (void)_testBadPermissionsFileWriting {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    NSString *pathObj = @"/tmp/HexFiendErroneousData_Permissions.data";
    const char *path = [pathObj fileSystemRepresentation];
    NSURL *url = [NSURL fileURLWithPath:pathObj isDirectory:NO];
    NSData *data = randomDataOfLength(4 * 1024);
    [data writeToURL:url atomically:NO];
    chmod(path, 0400); //set permissions to read only, and only for owner
    
    // Try doubling the file.  Writing this should fail because it is read only.
    HFFileReference *ref = [[[HFFileReference alloc] initWithPath:pathObj error:NULL] autorelease];
    HFByteSlice *slice = [[[HFFileByteSlice alloc] initWithFile:ref] autorelease];
    HFByteArray *array = [[[HFBTreeByteArray alloc] init] autorelease];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    
    NSError *error = nil;
    BOOL writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    HFTEST(writeResult == NO);
    HFTEST(error != nil);
    HFTEST([[error domain] isEqual:NSCocoaErrorDomain]);
    HFTEST([error code] == NSFileReadNoPermissionError);
    
    chmod(path, 0644);
    error = nil;
    writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    HFTEST(writeResult == YES);
    HFTEST(error == nil);
    
    unlink(path);
    
    [pathObj self]; //make sure this sticks around under GC for its filesystemRepresentation
    [pool drain];
}

+ (void)_testBadLengthFileWriting {
    NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
    NSString *pathObj = @"/tmp/HexFiendErroneousData_Length.data";
    const char *path = [pathObj fileSystemRepresentation];
    NSURL *url = [NSURL fileURLWithPath:pathObj isDirectory:NO];
    NSData *data = randomDataOfLength(4 * 1024);
    [data writeToURL:url atomically:NO];
    
    HFByteSlice *slice = [[[HFRandomDataByteSlice alloc] initWithRandomDataLength:(1ULL << 42 /* 4 terabytes*/)] autorelease];
    HFByteArray *array = [[[HFBTreeByteArray alloc] init] autorelease];
    [array insertByteSlice:slice inRange:HFRangeMake(0, 0)];
    
    NSError *error = nil;
    BOOL writeResult = [array writeToFile:url trackingProgress:NULL error:&error];
    HFTEST(writeResult == NO);
    HFTEST(error != nil);
    HFTEST([[error domain] isEqual:NSCocoaErrorDomain]);
    HFTEST([error code] == NSFileWriteOutOfSpaceError);
    
    unlink(path);
    
    [pathObj self]; //make sure this sticks around under GC for its filesystemRepresentation
    [pool drain];
}


+ (void)_testPermutationFileWriting {
    const BOOL should_debug = NO;
    
    NSUInteger iteration = 10;
    
    while (iteration--) {
	NSAutoreleasePool* pool=[[NSAutoreleasePool alloc] init];
	
#define BLOCK_SIZE (16 * 1024)
#define BLOCK_COUNT 64
	
	/* Construct an enumeration */
	NSUInteger permutation[BLOCK_COUNT];
	NSUInteger p;
	for (p=0; p < BLOCK_COUNT; p++) permutation[p] = p;
	while (p > 1) {
	    p--;
	    unsigned k = random() % (p + 1);
	    NSUInteger tmp = permutation[k];
	    permutation[k] = permutation[p];
	    permutation[p] = tmp;
	}
	
	NSData *data = randomDataOfLength(BLOCK_COUNT * BLOCK_SIZE);
	NSURL *fileURL = [NSURL fileURLWithPath:@"/tmp/HexFiendTestFile.data"];
	NSURL *asideFileURL = [NSURL fileURLWithPath:@"/tmp/HexFiendTestFile_External.data"];
	if (! [data writeToURL:fileURL atomically:NO]) {
	    [NSException raise:NSGenericException format:@"Unable to write test data to %@", fileURL];
	}
	HFFileReference *ref = [[[HFFileReference alloc] initWithPath:[fileURL path] error:NULL] autorelease];
	HFTEST([ref length] == [data length]);
	
	HFByteSlice *slice = [[[HFFileByteSlice alloc] initWithFile:ref] autorelease];
	
	HFByteArray *array = [[[preferredByteArrayClass() alloc] init] autorelease];

	for (p=0; p < BLOCK_COUNT; p++) {
	    NSUInteger index = permutation[p];
	    HFByteSlice *subslice = [slice subsliceWithRange:HFRangeMake(index * BLOCK_SIZE, BLOCK_SIZE)];
	    [array insertByteSlice:subslice inRange:HFRangeMake([array length], 0)];
	}
	NSData *arrayHash = HFHashByteArray(array);
	
	HFTEST([array writeToFile:asideFileURL trackingProgress:NULL error:NULL]);
	HFTEST([arrayHash isEqual:HFHashFile(asideFileURL)]);
	
	HFTEST([array writeToFile:fileURL trackingProgress:NULL error:NULL]);
	NSDate *startDate = [NSDate date];
	HFTEST([arrayHash isEqual:HFHashFile(fileURL)]);	
	NSTimeInterval diff = [startDate timeIntervalSinceNow];
	
	[[NSFileManager defaultManager] removeFileAtPath:[fileURL path] handler:nil];
	
	[pool drain];
    }
}

+ (void)_testByteSearching {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSUInteger round;
    for (round = 0; round < 24; round++) {
        HFByteArray *byteArray = [[[preferredByteArrayClass() alloc] init] autorelease];
        HFByteSlice *rootSlice = [[[HFRepeatingDataByteSlice alloc] initWithRepeatingDataLength: 1 << 20] autorelease];
        [byteArray insertByteSlice:rootSlice inRange:HFRangeMake(0, 0)];
        
        NSData *needleData = randomDataOfLength(32 + random_upto(63));
        HFByteSlice *needleSlice = [[[HFSharedMemoryByteSlice alloc] initWithUnsharedData:needleData] autorelease];
        HFByteArray *needle = [[[preferredByteArrayClass() alloc] init] autorelease];
        [needle insertByteSlice:needleSlice inRange:HFRangeMake(0, 0)];
        
        [HFByteArray _testSearchAlgorithmsLookingForArray:needle inArray:byteArray];
        
        [byteArray insertByteSlice:needleSlice inRange:HFRangeMake(random_upto(1 << 15), 0)];
        [HFByteArray _testSearchAlgorithmsLookingForArray:needle inArray:byteArray];
        
        [byteArray insertByteSlice:needleSlice inRange:HFRangeMake([byteArray length] - random_upto(1 << 15), 0)];
        [HFByteArray _testSearchAlgorithmsLookingForArray:needle inArray:byteArray];
        
        [pool drain];
        pool = [[NSAutoreleasePool alloc] init];
    }
    [pool drain];
}

static void exception_thrown(const char *methodName, NSException *exception) {
    printf("Test %s threw exception %s\n", methodName, [[exception description] UTF8String]);
    puts("I'm bailing out.  Better luck next time.");
    exit(0);
}

+ (void)_runAllTests {
    CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
    BOOL enableTest = YES;
    if (enableTest) @try { [self _testFastMemchr]; }
    @catch (NSException *localException) { exception_thrown("_testFastMemchr", localException); }
    if (enableTest) @try { [self _testRangeFunctions]; }
    @catch (NSException *localException) { exception_thrown("_testRangeFunctions", localException); }
    if (enableTest) @try { [self _testByteArray]; }
    @catch (NSException *localException) { exception_thrown("_testByteArray", localException); }
    if (enableTest) @try { [self _testTextInsertion]; }
    @catch (NSException *localException) { exception_thrown("_testTextInsertion", localException); }
    if (enableTest) @try { [NSClassFromString(@"HFObjectGraph") self]; }
    @catch (NSException *localException) { exception_thrown("HFObjectGraph", localException); }    
    if (enableTest) @try { [self _testRandomOperationFileWriting]; }
    @catch (NSException *localException) { exception_thrown("_testRandomOperationFileWriting", localException); }
    if (enableTest) @try { [self _testPermutationFileWriting]; }
    @catch (NSException *localException) { exception_thrown("_testPermutationFileWriting", localException); }
    if (enableTest) @try { [self _testBadPermissionsFileWriting]; }
    @catch (NSException *localException) { exception_thrown("_testBadPermissionsFileWriting", localException); }
    if (enableTest) @try { [self _testBadLengthFileWriting]; }
    @catch (NSException *localException) { exception_thrown("_testBadLengthFileWriting", localException); }
    if (enableTest) @try { [self _testByteSearching]; }
    @catch (NSException *localException) { exception_thrown("_testByteSearching", localException); }
    CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
    printf("Unit tests completed in %.02f seconds\n", end - start);
    
}

+ (void)initialize {
    if (self == [HFController class]) {
        [self _runAllTests];
    }
}
#endif

@end
