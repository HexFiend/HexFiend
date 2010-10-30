#if HFUNIT_TESTS

@class HFByteArray, NSData, NSURL;

NSData *HFHashFile(NSURL *url);
NSData *HFHashByteArray(HFByteArray *array);

#endif
