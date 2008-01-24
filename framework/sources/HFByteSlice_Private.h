#import <HexFiend/HFByteSlice.h>

@interface HFByteSlice (HFByteSlice_Private)

- (void)constructNewByteSlicesAboutRange:(HFRange)range first:(HFByteSlice **)first second:(HFByteSlice **)second;

@end
