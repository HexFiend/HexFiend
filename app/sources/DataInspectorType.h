#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, InspectionError) {
    InspectionErrorNoData,
    InspectionErrorTooMuch,
    InspectionErrorTooLittle,
    InspectionErrorNonPwr2,
    InspectionErrorInternal,
    InspectionErrorMultipleRanges,
    InspectionErrorInvalidUTF8,
};

@protocol DataInspectorType

// The maximum number of bytes this type accepts
@property (readonly) NSUInteger maxBytesAllowed;

// Returns the string representation of bytes, or nil and set error
- (NSString *)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length error:(InspectionError *)error;

// Returns YES if we can replace the given number of bytes with this string value
- (BOOL)acceptStringValue:(NSString *)value replacingByteCount:(NSUInteger)count intoData:(unsigned char *)outData;

@end
