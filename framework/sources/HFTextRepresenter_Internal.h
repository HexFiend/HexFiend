#import <HexFiend/HFTextRepresenter.h>
#import <HexFiend/HFStringEncoding.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFTextRepresenter (HFInternal)

- (NSArray *)displayedSelectedContentsRanges; //returns an array of NSValues representing the selected ranges (as NSRanges) clipped to the displayed range.
- (NSArray<NSDictionary*> *)displayedColorRanges;

- (nullable NSDictionary *)displayedBookmarkLocations; //returns an dictionary mapping bookmark names to bookmark locations. Bookmark locations may be negative.

#if !TARGET_OS_IPHONE
- (void)beginSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;
- (void)continueSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;
- (void)endSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;

// Copy/Paste methods
- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb;
- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb encoding:(HFStringEncoding *)enc;
- (void)cutSelectedBytesToPasteboard:(NSPasteboard *)pb;
- (BOOL)canPasteFromPasteboard:(NSPasteboard *)pb;
- (BOOL)canCut;
- (BOOL)pasteBytesFromPasteboard:(NSPasteboard *)pb;
#endif

// Must be implemented by subclasses
- (void)insertText:(NSString *)text;

// Must be implemented by subclasses.  Return NSData representing the string value.
- (NSData *)dataFromPasteboardString:(NSString *)string;

// Value between [0, 1]
- (double)selectionPulseAmount;

#if !TARGET_OS_IPHONE
- (void)scrollWheel:(NSEvent *)event;
#endif

- (void)selectAll:(id)sender;

- (HFRange)entireDisplayedRange;

+ (CGFloat)verticalOffsetForLineRange:(HFFPRange)range;

@end

NS_ASSUME_NONNULL_END
