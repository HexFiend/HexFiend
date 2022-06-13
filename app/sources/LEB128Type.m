#import "LEB128Type.h"

@implementation LEB128Result

@end

@implementation LEB128Type

- (NSUInteger)maxBytesAllowed {
    return 8;
}

+ (LEB128Result *)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length isUnsigned:(BOOL)isUnsigned error:(InspectionError *)error {
    if (isUnsigned) {
        uint64_t result = 0;
        unsigned shift = 0;
        for (size_t i = 0; i < length; i++) {
            result |= ((uint64_t)(bytes[i] & 0x7F) << shift);
            shift += 7;

            if ((bytes[i] & 0x80) == 0) {
                LEB128Result *res = [[LEB128Result alloc] init];
                union LEB128Value value;
                value.u = result;
                res.value = value;
                res.numBytes = i + 1;
                return res;
            }
        }
    } else {
        int64_t result = 0;
        unsigned shift = 0;
        for (size_t i = 0; i < length; i++) {
            result |= ((int64_t)(bytes[i] & 0x7F) << shift);
            shift += 7;

            if ((bytes[i] & 0x80) == 0) {
                if (shift < 64 && (bytes[i] & 0x40)) {
                    result |= -((uint64_t)1 << shift);
                }
                LEB128Result *res = [[LEB128Result alloc] init];
                union LEB128Value value;
                value.i = result;
                res.value = value;
                res.numBytes = i + 1;
                return res;
            }
        }
    }
    *error = InspectionErrorTooLittle;
    return nil;
}

- (NSString *)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length error:(InspectionError *)error {
    LEB128Result *result = [self.class valueForBytes:bytes length:length isUnsigned:self.isUnsigned error:error];
    if (result) {
        if (self.isUnsigned) {
            return [NSString stringWithFormat:@"%qu (%ld bytes)", result.value.u, result.numBytes];
        } else {
            return [NSString stringWithFormat:@"%qd (%ld bytes)", result.value.i, result.numBytes];
        }
    }
    *error = InspectionErrorTooLittle;
    return nil;
}

- (BOOL)acceptStringValue:(NSString *)value replacingByteCount:(NSUInteger)count intoData:(unsigned char *)outData {
    return NO;
}

@end
