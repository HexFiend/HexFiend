#import <HexFiend/HFByteArray.h>

@interface HFByteArray (HFInternal)

- (void)_raiseIfLockedForSelector:(SEL)sel;

- (BOOL)_debugIsEqual:(HFByteArray *)val;
- (BOOL)_debugIsEqualToData:(NSData *)val;

- (unsigned long long)_byteSearchForwardsBoyerMoore:(HFByteArray *)findBytes inRange:(const HFRange)range withBytesConsumedProgress:(unsigned long long *)bytesConsumed;
- (unsigned long long)_byteSearchForwardsSingle:(unsigned char)byte inRange:(const HFRange)range withBytesConsumedProgress:(unsigned long long *)bytesConsumed;

@end
