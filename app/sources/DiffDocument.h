/* A document used for file diffing */

#import "BaseDataDocument.h"

@class DiffOverlayView;

@interface DiffDocument : BaseDataDocument {
    HFByteArray *leftBytes, *rightBytes;
    HFByteArrayEditScript *editScript;
    IBOutlet HFTextView *leftTextView;
    IBOutlet HFTextView *rightTextView;
    DiffOverlayView *overlayView;
    NSUInteger focusedInstructionIndex;
}

- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right;

- (BOOL)handleEvent:(NSEvent *)event;

@end
