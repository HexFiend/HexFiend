#import "HFByteArray.h"

NS_ASSUME_NONNULL_BEGIN

@interface HFByteArray (HFInternal)

- (BOOL)_debugIsEqual:(HFByteArray *)val;
- (BOOL)_debugIsEqualToData:(NSData *)val;

- (unsigned long long)_byteSearchBoyerMoore:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(nullable HFProgressTracker *)progressTracker;
- (unsigned long long)_byteSearchRollingHash:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(nullable HFProgressTracker *)progressTracker;
- (unsigned long long)_byteSearchNaive:(HFByteArray *)findBytes inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(nullable HFProgressTracker *)progressTracker caseInsensitive:(BOOL)caseInsensitive;

- (unsigned long long)_byteSearchSingle:(unsigned char)byte inRange:(const HFRange)range forwards:(BOOL)forwards trackingProgress:(nullable HFProgressTracker *)progressTracker;

@end

NS_ASSUME_NONNULL_END
