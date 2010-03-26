/* A document used for file diffing */

#import "BaseDataDocument.h"


@interface DiffDocument : BaseDataDocument {
    HFByteArray *leftBytes, *rightBytes;
    HFByteArrayEditScript *editScript;
    IBOutlet HFTextView *leftTextView;
    IBOutlet HFTextView *rightTextView;
    NSUInteger focusedInstructionIndex;
}

- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right;

- (BOOL)handleEvent:(NSEvent *)event;

@end
