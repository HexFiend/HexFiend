/* A document used for file diffing */

#import "BaseDataDocument.h"


@interface DiffDocument : BaseDataDocument {
    HFByteArray *leftBytes, *rightBytes;
    IBOutlet HFTextView *leftTextView;
    IBOutlet HFTextView *rightTextView;
}

- (id)initWithLeftByteArray:(HFByteArray *)left rightByteArray:(HFByteArray *)right;

@end
