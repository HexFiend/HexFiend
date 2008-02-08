#import <HexFiend/HFByteArray.h>

@interface HFByteArray (HFInternal)

- (BOOL)_debugIsEqual:(HFByteArray *)val;
- (BOOL)_debugIsEqualToData:(NSData *)val;

- (unsigned long long)_byteSearchForwardsBoyerMoore:(HFByteArray *)findBytes inRange:(const HFRange)range;
- (unsigned long long)_byteSearchForwardsSingle:(unsigned char)byte inRange:(const HFRange)range;

@end
