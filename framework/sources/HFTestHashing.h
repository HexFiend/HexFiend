#if ! NDEBUG

@class HFByteArray, NSData, NSURL;

NSData *HFHashFile(NSURL *url);
NSData *HFHashByteArray(HFByteArray *array);

#endif
