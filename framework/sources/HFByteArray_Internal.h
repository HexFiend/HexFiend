#import <HexFiend/HFByteArray.h>

@interface HFByteArray (HFInternal)

- (BOOL)_debugIsEqual:(HFByteArray *)val;
- (BOOL)_debugIsEqualToData:(NSData *)val;

- (unsigned long long)_byteSearchBoyerMoore:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker;
- (unsigned long long)_byteSearchRollingHash:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker;
- (unsigned long long)_byteSearchNaive:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker;

- (unsigned long long)_byteSearchSingle:(unsigned char)byte inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(HFProgressTracker *)progressTracker;

@end
