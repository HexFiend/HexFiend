#import <HexFiend/HFTextRepresenter.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFTextRepresenter (HFInternal)

- (NSArray *)displayedSelectedContentsRanges; //returns an array of NSValues representing the selected ranges (as NSRanges) clipped to the displayed range.

- (nullable NSDictionary *)displayedBookmarkLocations; //returns an dictionary mapping bookmark names to bookmark locations. Bookmark locations may be negative.

- (void)beginSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;
- (void)continueSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;
- (void)endSelectionWithEvent:(NSEvent *)event forCharacterIndex:(NSUInteger)characterIndex;

// Copy/Paste methods
- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb;
- (void)copySelectedBytesToPasteboard:(NSPasteboard *)pb encoding:(NSStringEncoding)enc;
- (void)cutSelectedBytesToPasteboard:(NSPasteboard *)pb;
- (BOOL)canPasteFromPasteboard:(NSPasteboard *)pb;
- (BOOL)canCut;
- (BOOL)pasteBytesFromPasteboard:(NSPasteboard *)pb;

// Must be implemented by subclasses
- (void)insertText:(NSString *)text;

// Must be implemented by subclasses.  Return NSData representing the string value.
- (NSData *)dataFromPasteboardString:(NSString *)string;

// Value between [0, 1]
- (double)selectionPulseAmount;

- (void)scrollWheel:(NSEvent *)event;

- (void)selectAll:(id)sender;

@end

NS_ASSUME_NONNULL_END
