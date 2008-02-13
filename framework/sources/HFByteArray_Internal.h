#import <HexFiend/HFByteArray.h>

@interface HFByteArray (HFInternal)

- (void)_incrementGenerationOrRaiseIfLockedForSelector:(SEL)sel;

- (BOOL)_debugIsEqual:(HFByteArray *)val;
- (BOOL)_debugIsEqualToData:(NSData *)val;

- (unsigned long long)_byteSearchForwardsBoyerMoore:(HFByteArray *)findBytes inRange:(const HFRange)range trackingProgress:(HFProgressTracker *)progressTracker;
- (unsigned long long)_byteSearchForwardsSingle:(unsigned char)byte inRange:(const HFRange)range trackingProgress:(HFProgressTracker *)progressTracker;

@end
