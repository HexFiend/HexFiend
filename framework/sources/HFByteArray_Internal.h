#import <HexFiend/HFByteArray.h>

@interface HFByteArray (HFInternal)

- (BOOL)_debugIsEqual:(HFByteArray *)val;
- (BOOL)_debugIsEqualToData:(NSData *)val;

@end
