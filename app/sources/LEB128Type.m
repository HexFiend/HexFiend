#import "LEB128Type.h"

@implementation LEB128Type

- (NSUInteger)maxBytesAllowed {
    return 24;
}

- (NSString *)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length error:(InspectionError *)error {
    if (self.isUnsigned) {
        uint64_t result = 0;
        unsigned shift = 0;
        for (size_t i = 0; i < length; i++) {
            result |= ((uint64_t)(bytes[i] & 0x7F) << shift);
            shift += 7;

            if ((bytes[i] & 0x80) == 0) {
                return [NSString stringWithFormat:@"%qu (%ld bytes)", result, i + 1];
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
                return [NSString stringWithFormat:@"%qd (%ld bytes)", result, i + 1];
            }
        }
    }
    *error = InspectionErrorTooLittle;
    return nil;
}

- (BOOL)acceptStringValue:(NSString *)value replacingByteCount:(NSUInteger)count intoData:(unsigned char *)outData {
    return NO;
}

@end
