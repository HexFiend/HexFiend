/* A document used for file diffing */

#import "BaseDataDocument.h"

@class DiffOverlayView;

@interface DiffDocument : BaseDataDocument {
    HFByteArray *leftBytes, *rightBytes;
    HFByteArrayEditScript *editScript;
    NSString *leftFileName;
    NSString *rightFileName;
    IBOutlet HFTextView *leftTextView;
    IBOutlet HFTextView *rightTextView;
    IBOutlet NSTableView *diffTable;
    DiffOverlayView *overlayView;
    NSUInteger focusedInstructionIndex;
    NSString *title;
}

- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right;
- (BOOL)handleEvent:(NSEvent *)event;

- (void)setLeftFileName:(NSString *)leftName;
- (NSString *)leftFileName;

- (void)setRightFileName:(NSString *)rightName;
- (NSString *)rightFileName;


@end
