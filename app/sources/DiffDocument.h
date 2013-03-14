/* A document used for file diffing */

#import "BaseDataDocument.h"

@class DiffOverlayView, DiffTextViewContainer;

@interface DiffDocument : BaseDataDocument {
    HFByteArray *leftBytes, *rightBytes;
    HFByteArrayEditScript *editScript;
    NSString *leftFileName;
    NSString *rightFileName;
    IBOutlet HFTextView *leftTextView;
    IBOutlet HFTextView *rightTextView;
    IBOutlet NSTableView *diffTable;
    IBOutlet DiffTextViewContainer *textViewContainer;
    DiffOverlayView *overlayView;
    NSUInteger focusedInstructionIndex;
    NSString *title;
    BOOL synchronizingControllers;
    
    HFDocumentOperationView *diffComputationView;
    
    // abstract scroll space support
    IBOutlet NSScroller *scroller;
    unsigned long long totalAbstractLength;
    long double currentScrollPosition;
    
    // momentum scroll hackery
    BOOL handledLastScrollEvent;
    CFAbsoluteTime timeOfLastScrollEvent;
    
    HFRange range_;
}

+ (NSArray *)getFrontTwoDocumentsForDiffing;
+ (void)compareDocument:(BaseDataDocument *)document againstDocument:(BaseDataDocument *)otherDocument usingRange:(HFRange)range;
+ (void)compareFrontTwoDocuments;
+ (void)compareFrontTwoDocumentsUsingRange:(HFRange)range;

- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right;
- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right range:(HFRange)range;
- (BOOL)handleEvent:(NSEvent *)event;

- (void)setLeftFileName:(NSString *)leftName;
- (NSString *)leftFileName;

- (void)setRightFileName:(NSString *)rightName;
- (NSString *)rightFileName;

- (IBAction)scrollerDidChangeValue:(NSScroller *)scroller;

@end
