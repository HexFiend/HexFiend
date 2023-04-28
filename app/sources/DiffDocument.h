/* A document used for file diffing */

#import "BaseDataDocument.h"

@class DiffOverlayView, DiffTextViewContainer;

@interface DiffDocument : BaseDataDocument {
    HFByteArray *leftBytes, *rightBytes;
    HFByteArrayEditScript *editScript;
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
    
    HFColumnRepresenter *leftColumnRepresenter;
    HFLineCountingRepresenter *leftLineCountingRepresenter;
    HFBinaryTextRepresenter *leftBinaryRepresenter;
    HFHexTextRepresenter *leftHexRepresenter;
    HFRepresenter *leftAsciiRepresenter;
    HFRepresenter *leftScrollRepresenter;
    HFRepresenter *leftTextDividerRepresenter;
    DataInspectorRepresenter *leftDataInspectorRepresenter;
    HFStatusBarRepresenter *leftStatusBarRepresenter;
    HFBinaryTemplateRepresenter *leftBinaryTemplateRepresenter;
    
    NSMutableDictionary<NSString*, HFRepresenter*> *allRepresenters;
}

+ (NSArray *)getFrontTwoDocumentsForDiffing;
+ (void)compareDocument:(BaseDataDocument *)document againstDocument:(BaseDataDocument *)otherDocument usingRange:(HFRange)range;
+ (void)compareFrontTwoDocuments;
+ (void)compareFrontTwoDocumentsUsingRange:(HFRange)range;
+ (void)compareByteArray:(HFByteArray *)leftBytes againstByteArray:(HFByteArray *)rightBytes usingRange:(HFRange)range leftFileName:(NSString *)leftFileName rightFileName:(NSString *)rightFileName;

- (instancetype)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right;
- (instancetype)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right range:(HFRange)range;
- (BOOL)handleEvent:(NSEvent *)event;

@property (nonatomic, copy) NSString *leftFileName;
@property (nonatomic, copy) NSString *rightFileName;

- (IBAction)scrollerDidChangeValue:(NSScroller *)scroller;

@end
