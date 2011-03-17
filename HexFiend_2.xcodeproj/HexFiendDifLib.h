#import <HexFiend/HFByteArrayEditScript.h>

@interface HFByteArrayEditScript (HFDiffLib)

- (id)initDiffLibWithDifferenceFromSource:(HFByteArray *)src toDestination:(HFByteArray *)dst trackingProgress:(HFProgressTracker *)progressTracker;

@end
