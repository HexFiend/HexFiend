#import "DataInspectorType.h"

NS_ASSUME_NONNULL_BEGIN

union LEB128Value {
    uint64_t u;
    int64_t i;
};

@interface LEB128Result : NSObject

@property union LEB128Value value;
@property size_t numBytes;

@end

@interface LEB128Type : NSObject<DataInspectorType>

@property BOOL isUnsigned;

+ (LEB128Result *_Nullable)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length isUnsigned:(BOOL)isUnsigned error:(InspectionError *)error;

@end

NS_ASSUME_NONNULL_END
