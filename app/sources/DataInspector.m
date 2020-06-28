//
//  DataInspector.m
//  HexFiend_2
//
//  Copyright © 2019 ridiculous_fish. All rights reserved.
//

#import "DataInspector.h"

@implementation DataInspector

+ (DataInspector*)dataInspectorSupplementing:(NSArray*)inspectors {
    DataInspector *ret = [[DataInspector alloc] init];
    
    enum Endianness_t preferredEndian; // Prefer the most popular endianness among inspectors
    uint32_t present = 0; // Bit set of all inspector types that are already present.
    
    _Static_assert(eEndianCount <= 2, "This part of the code assumes only two supported endianesses.");
    int endianessVote = 0; // +1 for enum == 0, -1 enum != 0.
    for(DataInspector *di in inspectors) {
        endianessVote += !di->endianness ? 1 : -1;
        present |= 1 << di->inspectorType << di->endianness*eInspectorTypeCount;
    }
    preferredEndian = endianessVote < 0;
    
    uint32_t pref = (~present >> preferredEndian*eInspectorTypeCount) & ((1<<eInspectorTypeCount)-1);
    if(pref) { // There is a missing inspector type for preffered endianness, pick that one.
        ret->endianness = preferredEndian;
        ret->inspectorType = __builtin_ffs(pref)-1;
        return ret;
    }
    
    // Pick an absent inspector type.
    int x = __builtin_ffs(~present)-1;
    enum Endianness_t y = x/eInspectorTypeCount;
    enum InspectorType_t z = x % eInspectorTypeCount;
    
    if(x < 0 || y >= eEndianCount || z >= eInspectorTypeCount) // No absent inspector type
        return ret;
    
    ret->endianness = y;
    ret->inspectorType = z;
    return ret;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [coder encodeInt32:inspectorType forKey:@"InspectorType"];
    [coder encodeInt32:endianness forKey:@"Endianness"];
    [coder encodeInt32:numberBase forKey:@"NumberBase"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super init];
    inspectorType = [coder decodeInt32ForKey:@"InspectorType"];
    endianness = [coder decodeInt32ForKey:@"Endianness"];
    numberBase = [coder decodeInt32ForKey:@"NumberBase"];
    return self;
}

- (void)setType:(enum InspectorType_t)type {
    inspectorType = type;
}

- (enum InspectorType_t)type {
    return inspectorType;
}

- (void)setEndianness:(enum Endianness_t)end {
    endianness = end;
}

- (enum Endianness_t)endianness {
    return endianness;
}

- (void)setNumberBase:(enum NumberBase_t)base {
    numberBase = base;
}

- (enum NumberBase_t)numberBase {
    return numberBase;
}

- (NSUInteger)hash {
    return inspectorType + (endianness << 8UL);
}

- (BOOL)isEqual:(DataInspector *)him {
    if (! [him isKindOfClass:[DataInspector class]]) return NO;
    return inspectorType == him->inspectorType && endianness == him->endianness && numberBase == him->numberBase;
}

static uint64_t reverse(uint64_t val, NSUInteger amount) {
    /* Transfer amount bytes from input to output in reverse order */
    uint64_t input = val, output = 0;
    NSUInteger remaining = amount;
    while (remaining--) {
        unsigned char byte = input & 0xFF;
        output = (output << CHAR_BIT) | byte;
        input >>= CHAR_BIT;
    }
    return output;
}

static void flip(void *val, NSUInteger amount) {
    uint8_t *bytes = (uint8_t *)val;
    NSUInteger i;
    for (i = 0; i < amount / 2; i++) {
        uint8_t tmp = bytes[amount - i - 1];
        bytes[amount - i - 1] = bytes[i];
        bytes[i] = tmp;
    }
}

#define FETCH(type) type s = *(const type *)bytes;
#define FLIP(amount) if (endianness != eNativeEndianness) { flip(&s, amount); }
#define FORMAT(decSpecifier, hexSpecifier) return [NSString stringWithFormat:numberBase == eNumberBaseDecimal ? decSpecifier : hexSpecifier, s];
static NSString *signedIntegerDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness, enum NumberBase_t numberBase) {
    switch (length) {
        case 1:
        {
            FETCH(int8_t)
            FORMAT(@"%" PRId8, @"0x%" PRIX8);
        }
        case 2:
        {
            FETCH(int16_t)
            FLIP(2)
            FORMAT(@"%" PRId16, @"0x%" PRIX16)
        }
        case 4:
        {
            FETCH(int32_t)
            FLIP(4)
            FORMAT(@"%" PRId32, @"0x%" PRIX32)
        }
        case 8:
        {
            FETCH(int64_t)
            FLIP(8)
            FORMAT(@"%" PRId64, @"0x%" PRIX64)
        }
        case 16:
        {
            FETCH(__int128_t)
            FLIP(16)
            BOOL neg;
            if (s < 0) {
                s=-s;
                neg = YES;
            } else {
                neg = NO;
            }
            char buf[50], *b = buf;
            while(s) {
                *(b++) = (char)(s%10)+'0';
                s /= 10;
            }
            *b = 0;
            flip(buf, b-buf);
            return [NSString stringWithFormat:@"%s%s", (neg?"-":""), buf];
        }
        default: return nil;
    }
}

static NSString *unsignedIntegerDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness, enum NumberBase_t numberBase) {
    switch (length) {
        case 1:
        {
            FETCH(uint8_t)
            FORMAT(@"%" PRIu8, @"0x%" PRIX8);
        }
        case 2:
        {
            FETCH(uint16_t)
            FLIP(2)
            FORMAT(@"%" PRIu16, @"0x%" PRIX16)
        }
        case 4:
        {
            FETCH(uint32_t)
            FLIP(4)
            FORMAT(@"%" PRIu32, @"0x%" PRIX32)
        }
        case 8:
        {
            FETCH(uint64_t)
            FLIP(8)
            FORMAT(@"%" PRIu64, @"0x%" PRIX64)
        }
        case 16:
        {
            FETCH(__uint128_t)
            FLIP(16)
            char buf[50], *b = buf;
            while(s) {
                *(b++) = (char)(s%10)+'0';
                s /= 10;
            }
            *b = 0;
            flip(buf, b-buf);
            return [NSString stringWithFormat:@"%s", buf];
        }
        default: return nil;
    }
}
#undef FETCH
#undef FLIP
#undef FORMAT

static long double ieeeToLD(const void *bytes, unsigned exp, unsigned man) {
    __uint128_t b = 0;
    memcpy(&b, bytes, (1 + exp + man + 7)/8);
    
    __uint128_t m = b << (1+exp) >> (128 - man);
    int64_t e = (uint64_t)(b << 1 >> (128 - exp));
    unsigned s = b >> 127;
    
    if(e) {
        if(e ^ ((1ULL<<exp)-1)) {
            // normal
            int64_t e2 = e + 1 - (1ULL<<(exp-1));
            long double t = ldexpl(m, (int)(e2-man)) + ldexpl(1, (int)e2);
            return s ? -t : t;
        } else {
            if(m) {
                // nan
                return __builtin_nanl(""); // No attempt to translate codes.
            } {
                // infinity
                return s ? __builtin_infl() : -__builtin_infl();
            }
        }
    } else {
        if(m) {
            // subnormal
            int64_t e2 = 2 - (1ULL<<(exp-1));
            long double t = ldexpl(m, (int)(e2-man));
            return s ? -t : t;
        } else {
            // zero
            return s ? -0.0L : 0.0L;
        }
    }
}

static NSString *floatingPointDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness) {
    switch (length) {
        case sizeof(uint16_t):
        {
            union {
                uint16_t i;
                __fp16 f;
            } temp;
            _Static_assert(sizeof temp.f == sizeof temp.i, "sizeof(uint16_t) is not 2!");
            temp.i = *(const uint16_t *)bytes;
            if (endianness != eNativeEndianness) temp.i = (uint16_t)reverse(temp.i, sizeof(uint16_t));
            return [NSString stringWithFormat:@"%.15g", (double)temp.f];
        }
        case sizeof(uint32_t):
        {
            union {
                uint32_t i;
                float f;
            } temp;
            _Static_assert(sizeof temp.f == sizeof temp.i, "sizeof(float) is not 4!");
            temp.i = *(const uint32_t *)bytes;
            if (endianness != eNativeEndianness) temp.i = (uint32_t)reverse(temp.i, sizeof(float));
            return [NSString stringWithFormat:@"%.*g", FLT_DECIMAL_DIG, temp.f];
        }
        case sizeof(uint64_t):
        {
            union {
                uint64_t i;
                double f;
            } temp;
            _Static_assert(sizeof temp.f == sizeof temp.i, "sizeof(double) is not 8!");
            temp.i = *(const uint64_t *)bytes;
            if (endianness != eNativeEndianness) temp.i = reverse(temp.i, sizeof(double));
            return [NSString stringWithFormat:@"%.*g", DBL_DECIMAL_DIG, temp.f];
        }
#ifndef __arm64__ // TODO
        case 10:
        {
            typedef float __attribute__((mode(XF))) float80;
            union {
                uint8_t i[10];
                float80 f;
            } temp;
            if (endianness == eNativeEndianness) {
                memcpy(temp.i, bytes, 10);
            } else {
                for(unsigned i = 0; i < 10; i++) {
                    temp.i[9 - i] = bytes[i];
                }
            }
            return [NSString stringWithFormat:@"%.15Lg", (long double)temp.f];
        }
#endif
        case 16:
        {
            //typedef float __attribute__((mode(TF))) float128; // Here's to hoping clang support comes one day.
            uint64_t temp[2];
            temp[0] = ((uint64_t*)bytes)[0];
            temp[1] = ((uint64_t*)bytes)[1];
            if (endianness != eNativeEndianness) {
                uint64_t t = temp[0];
                temp[0] = reverse(temp[1], 8);
                temp[1] = reverse(t, 8);
            }
            return [NSString stringWithFormat:@"%.15Lg", ieeeToLD(temp, 15, 112)];
        }
        default: return nil;
    }
}

static NSAttributedString *formatInspectionString(NSString *s, BOOL isError) {
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setMinimumLineHeight:(CGFloat)16.];
    
    NSColor *foregroundColor = isError ? [NSColor disabledControlTextColor] : [NSColor textColor];
    
    return [[NSAttributedString alloc] initWithString:s attributes:@{
                                                                     NSForegroundColorAttributeName: foregroundColor,
                                                                     NSFontAttributeName: [NSFont controlContentFontOfSize:11],
                                                                     NSParagraphStyleAttributeName: paragraphStyle
                                                                     }];
}

typedef NS_ENUM(NSInteger, InspectionError) {
    InspectionErrorNoData,
    InspectionErrorTooMuch,
    InspectionErrorTooLittle,
    InspectionErrorNonPwr2,
    InspectionErrorInternal,
    InspectionErrorMultipleRanges,
    InspectionErrorInvalidUTF8,
};

static NSAttributedString *inspectionError(InspectionError err) {
    NSString *s = nil;
    switch (err) {
        case InspectionErrorNoData:
            s = NSLocalizedString(@"(select some data)", "");
            break;
        case InspectionErrorTooMuch:
            s = NSLocalizedString(@"(select less data)", "");
            break;
        case InspectionErrorTooLittle:
            s = NSLocalizedString(@"(select more data)", "");
            break;
        case InspectionErrorNonPwr2:
            s = NSLocalizedString(@"(select a power of 2 bytes)", "");
            break;
        case InspectionErrorInternal:
            s = NSLocalizedString(@"(internal error)", "");
            break;
        case InspectionErrorMultipleRanges:
            s = NSLocalizedString(@"(select a contiguous range)", "");
            break;
        case InspectionErrorInvalidUTF8:
            s = NSLocalizedString(@"(bytes are not valid UTF-8)", "");
            break;
        default:
            s = [NSString stringWithFormat:NSLocalizedString(@"(error %ld)", ""), (long)err];
            break;
    }
    return formatInspectionString(s, YES);
}

static NSAttributedString *inspectionSuccess(NSString *s) {
    return formatInspectionString(s, NO);
}

- (NSAttributedString *)valueForController:(HFController *)controller ranges:(NSArray *)ranges isError:(BOOL *)outIsError {
    /* Just do a rough cut on length before going to valueForData. */
    
    if ([ranges count] != 1) {
        if(outIsError) *outIsError = YES;
        return inspectionError(InspectionErrorMultipleRanges);
    }
    HFRange range = [ranges[0] HFRange];
    
    if(range.length == 0) {
        if(outIsError) *outIsError = YES;
        return inspectionError(InspectionErrorNoData);
    }
    
    if(range.length > MAX_EDITABLE_BYTE_COUNT) {
        if(outIsError) *outIsError = YES;
        return inspectionError(InspectionErrorTooMuch);
    }
    
    switch ([self type]) {
        case eInspectorTypeUnsignedInteger:
        case eInspectorTypeSignedInteger:
        case eInspectorTypeFloatingPoint:
            if(range.length > 16) {
                if(outIsError) *outIsError = YES;
                return inspectionError(InspectionErrorTooMuch);
            }
            break;
        case eInspectorTypeUTF8Text:
            // MAX_EDITABLE_BYTE_COUNT already checked above
            break;
        case eInspectorTypeSLEB128:
        case eInspectorTypeULEB128:
        case eInspectorTypeBinary:
            if(range.length > 24) {
                if(outIsError) *outIsError = YES;
                return inspectionError(InspectionErrorTooMuch);
            }
            break;
        default:
            if(outIsError) *outIsError = YES;
            return inspectionError(InspectionErrorInternal);
    }
    
    NSAttributedString *result = [self valueForData:[controller dataForRange:range] isError:outIsError];
    return result;
}

- (NSAttributedString *)valueForData:(NSData *)data isError:(BOOL *)outIsError {
    return [self valueForBytes:[data bytes] length:[data length] isError:outIsError];
}

- (NSAttributedString *)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length isError:(BOOL *)outIsError {
    if(outIsError) *outIsError = YES;
    
    switch ([self type]) {
        case eInspectorTypeUnsignedInteger:
        case eInspectorTypeSignedInteger:
            /* Only allow powers of 2 up to 8 */
            switch (length) {
                case 0: return inspectionError(InspectionErrorNoData);
                case 1: case 2: case 4: case 8:
                    if(outIsError) *outIsError = NO;
                    if(inspectorType == eInspectorTypeSignedInteger)
                        return inspectionSuccess(signedIntegerDescription(bytes, length, endianness, numberBase));
                    else
                        return inspectionSuccess(unsignedIntegerDescription(bytes, length, endianness, numberBase));
                default:
                    return length > 8 ? inspectionError(InspectionErrorTooMuch) : inspectionError(InspectionErrorNonPwr2);
            }
            
        case eInspectorTypeFloatingPoint:
            switch (length) {
                case 0:
                    return inspectionError(InspectionErrorNoData);
                case 1: case 3:
                    return inspectionError(InspectionErrorTooLittle);
                case 2: case 4: case 8: case 10: case 16:
                    if(outIsError) *outIsError = NO;
                    return inspectionSuccess(floatingPointDescription(bytes, length, endianness));
                default:
                    return length > 16 ? inspectionError(InspectionErrorTooMuch) : inspectionError(InspectionErrorNonPwr2);
            }
            
        case eInspectorTypeUTF8Text: {
            if(length == 0) return inspectionError(InspectionErrorNoData);
            if(length > MAX_EDITABLE_BYTE_COUNT) return inspectionError(InspectionErrorTooMuch);
            NSString *ret = [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
            if(ret == nil) return inspectionError(InspectionErrorInvalidUTF8);
            if(outIsError) *outIsError = NO;
            return inspectionSuccess(ret);
        }
        case eInspectorTypeBinary: {
            if(outIsError) *outIsError = NO;
            NSString* ret = @"";
            
            for (NSUInteger i = 0; i < length; ++i) {
                char input = bytes[i];
                
                char binary[] = "00000000";
                
                if ( input & 0x80 )
                    binary[0] = '1';
                
                if ( input & 0x40 )
                    binary[1] = '1';
                
                if ( input & 0x20 )
                    binary[2] = '1';
                
                if ( input & 0x10 )
                    binary[3] = '1';
                
                if ( input & 0x08 )
                    binary[4] = '1';
                
                if ( input & 0x04 )
                    binary[5] = '1';
                
                if ( input & 0x02 )
                    binary[6] = '1';
                
                if ( input & 0x01 )
                    binary[7] = '1';
                
                ret = [ret stringByAppendingFormat:@"%s", binary];
            }
            
            return  inspectionSuccess(ret);
        }
            
        case eInspectorTypeSLEB128: {
            int64_t result = 0;
            unsigned shift = 0;
            for (size_t i = 0; i < length; i++) {
                result |= ((int64_t)(bytes[i] & 0x7F) << shift);
                shift += 7;
                
                if ((bytes[i] & 0x80) == 0) {
                    if (shift < 64 && (bytes[i] & 0x40)) {
                        result |= -((uint64_t)1 << shift);
                    }
                    return inspectionSuccess([NSString stringWithFormat:@"%qd (%ld bytes)", result, i + 1]);
                }
            }
            
            return inspectionError(InspectionErrorTooLittle);
        }
            
        case eInspectorTypeULEB128: {
            uint64_t result = 0;
            unsigned shift = 0;
            for (size_t i = 0; i < length; i++) {
                result |= ((uint64_t)(bytes[i] & 0x7F) << shift);
                shift += 7;
                
                if ((bytes[i] & 0x80) == 0) {
                    return inspectionSuccess([NSString stringWithFormat:@"%qu (%ld bytes)", result, i + 1]);
                }
            }
            
            return inspectionError(InspectionErrorTooLittle);
        }
            
        default:
            return inspectionError(InspectionErrorInternal);
    }
}

static BOOL valueCanFitInByteCount(unsigned long long unsignedValue, NSUInteger count) {
    long long signedValue = (long long)unsignedValue;
    switch (count) {
        case 1:
            return unsignedValue <= UINT8_MAX || (signedValue <= INT8_MAX && signedValue >= INT8_MIN);
        case 2:
            return unsignedValue <= UINT16_MAX || (signedValue <= INT16_MAX && signedValue >= INT16_MIN);
        case 4:
            return unsignedValue <= UINT32_MAX || (signedValue <= INT32_MAX && signedValue >= INT32_MIN);
        case 8:
            return unsignedValue <= UINT64_MAX || (signedValue <= INT64_MAX && signedValue >= INT64_MIN);
        default:
            return NO;
    }
}

static BOOL stringRangeIsNullBytes(NSString *string, NSRange range) {
    static const int bufferChars = 256;
    static const unichar zeroBuf[bufferChars] = {0}; //unicode null bytes
    unichar buffer[bufferChars];
    
    NSRange r = NSMakeRange(range.location, bufferChars);
    
    if(range.length > bufferChars) { // No underflow please.
        NSUInteger lastBlock = range.location + range.length - bufferChars;
        for(; r.location < lastBlock; r.location += bufferChars) {
            [string getCharacters:buffer range:r];
            if(memcmp(buffer, zeroBuf, bufferChars)) return NO;
        }
    }
    
    // Handle the uneven bytes at the end.
    r.length = range.location + range.length - r.location;
    [string getCharacters:buffer range:r];
    if(memcmp(buffer, zeroBuf, r.length)) return NO;
    
    return YES;
}

- (BOOL)acceptStringValue:(NSString *)value replacingByteCount:(NSUInteger)count intoData:(unsigned char *)outData {
    if (inspectorType == eInspectorTypeUnsignedInteger || inspectorType == eInspectorTypeSignedInteger) {
        if (numberBase == eNumberBaseHexadecimal) {
            NSScanner *scanner = [NSScanner scannerWithString:value];
            unsigned long long unsignedHexValue = 0;
            if (![scanner scanHexLongLong:&unsignedHexValue]) {
                NSLog(@"Invalid hex value %@", value);
                return NO;
            }
            value = [NSString stringWithFormat:@"%llu", unsignedHexValue];
        }
        
        char buffer[256];
        BOOL success = [value getCString:buffer maxLength:sizeof buffer encoding:NSASCIIStringEncoding];
        if (! success) return NO;
        
        if (! (count == 1 || count == 2 || count == 4 || count == 8)) return NO;
        
        errno = 0;
        char *endPtr = NULL;
        /* note that strtoull handles negative values */
        unsigned long long unsignedValue = strtoull(buffer, &endPtr, 0);
        int resultError = errno;
        
        /* Make sure we consumed some of the string */
        if (endPtr == buffer) return NO;
        
        /* Check for conversion errors (overflow, etc.) */
        if (resultError != 0) return NO;
        
        /* Now check to make sure we fit */
        if (! valueCanFitInByteCount(unsignedValue, count)) return NO;
        
        if (outData == NULL) return YES; // No need to continue if we're not outputting
        
        /* Get all 8 bytes in big-endian form */
        unsigned long long consumableValue = unsignedValue;
        unsigned char bytes[8];
        unsigned i = 8;
        while (i--) {
            bytes[i] = consumableValue & 0xFF;
            consumableValue >>= 8;
        }
        
        /* Now copy the last (least significant) 'count' bytes to outData in the requested endianness */
        for (i=0; i < count; i++) {
            unsigned char byte = bytes[(8 - count + i)];
            if (endianness == eEndianBig) {
                outData[i] = byte;
            }
            else {
                outData[count - i - 1] = byte;
            }
        }
        
        /* Victory */
        return YES;
    }
    else if (inspectorType == eInspectorTypeFloatingPoint) {
        char buffer[256];
        BOOL success = [value getCString:buffer maxLength:sizeof buffer encoding:NSASCIIStringEncoding];
        if (! success) return NO;
        
        union {
            float  f;
            double d;
#ifndef __arm64__ // TODO
            float __attribute__((mode(XF))) x;
#endif
            __uint128_t t; // Maybe clang will support mode(TF) one day.
        } val;
        
        char *endPtr = NULL;
        errno = 0;
        
        switch(count) {
            case 4: val.f = strtof(buffer, &endPtr); break;
            case 8: val.d = strtod(buffer, &endPtr); break;
#ifndef __arm64__ // TODO
            case 10: val.x = strtold(buffer, &endPtr); break;
            case 16: {
                val.x = strtold(buffer, &endPtr);
                val.t = (val.t >> 64 << 112) | (val.t << 48 << 17 >> 16);
                break;
            }
#endif
            default: return NO;
        }
        
        if (errno != 0) return NO; // Check for conversion errors (overflow, etc.)
        if (endPtr == buffer) return NO; // Make sure we consumed some of the string
        
        if (outData == NULL) return YES; // No need to continue if we're not outputting
        
        unsigned char bytes[sizeof(val)];
        memcpy(bytes, &val, count);
        
        /* Now copy the first 'count' bytes to outData in the requested endianness.  This is different from the integer case - there we always work big-endian because we support more different byteCounts, but here we work in the native endianness because there's no simple way to convert a float or double to big endian form */
        for (NSUInteger i = 0; i < count; i++) {
            if (endianness == eNativeEndianness) {
                outData[i] = bytes[i];
            } else {
                outData[count - i - 1] = bytes[i];
            }
        }
        
        /* Return triumphantly! */
        return YES;
    }
    else if (inspectorType == eInspectorTypeUTF8Text) {
        /*
         * If count is longer than the UTF-8 encoded value, succeed and zero fill
         * the rest of outbuf. It's obvious behavior and probably more useful than
         * only allowing an exact length UTF-8 replacement.
         *
         * By the same token, allow ending zero bytes to be dropped, so re-editing
         * the same text doesn't fail due to the null bytes we added at the end.
         */
        
        unsigned char buffer_[256];
        unsigned char *buffer = buffer_;
        NSUInteger used;
        BOOL ret;
        NSRange fullRange = NSMakeRange(0, [value length]);
        NSRange leftover;
        
        // Speculate that 256 chars is enough.
        ret = [value getBytes:buffer maxLength:count < sizeof(buffer_) ? count : sizeof(buffer_) usedLength:&used
                     encoding:NSUTF8StringEncoding options:0 range:fullRange remainingRange:&leftover];
        
        if(!ret) return NO;
        if(leftover.length == 0 || stringRangeIsNullBytes(value, leftover)) {
            // Buffer was large enough, yay!
            if(outData) {
                memcpy(outData, buffer, used);
                memset(outData+used, 0, count-used);
            }
            return YES;
        }
        
        // Buffer wasn't large enough.
        // Don't bother trying to reuse previous conversion, it's small beans anyways.
        
        if(!outData) return count <= [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        
        buffer = malloc(count);
        ret = [value getBytes:buffer maxLength:count usedLength:&used encoding:NSUTF8StringEncoding
                      options:0 range:fullRange remainingRange:&leftover];
        ret = ret && (leftover.length == 0 || stringRangeIsNullBytes(value, leftover)) && used <= count;
        if(ret) {
            memcpy(outData, buffer, used);
            memset(outData+used, 0, count-used);
        }
        free(buffer);
        return ret;
    }
    else if (inspectorType == eInspectorTypeBinary) {
        if (value.length != (count * 8)) {
            return NO;
        }
        for (NSUInteger i = 0; i < value.length; i++) {
            const unichar ch = [value characterAtIndex:i];
            if (ch != '0' && ch != '1') {
                return NO;
            }
        }
        if (outData) {
            for (NSUInteger byteIndex = 0; byteIndex < count; byteIndex++) {
                NSString *bitsStr = [value substringWithRange:NSMakeRange(byteIndex * 8, 8)];
                outData[byteIndex] = bitStringToValue(bitsStr);
            }
        }
        return YES;
    }
    else {
        /* Unknown inspector type */
        return NO;
    }
}

static uint8_t bitStringToValue(NSString *value) {
    HFASSERT(value.length == 8);
    uint8_t byte = 0;
    NSRange range = NSMakeRange(0, 1);
    for (NSUInteger stringIndex = 0; stringIndex < value.length; stringIndex++, range.location++) {
        const uint8_t bitValue = (uint8_t)[value substringWithRange:range].intValue;
        byte |= bitValue << ((value.length - 1) - stringIndex);
    }
    return byte;
}

- (id)propertyListRepresentation {
    return @{
             @"InspectorType": @(inspectorType),
             @"Endianness": @(endianness),
             @"NumberBase": @(numberBase),
             };
}

- (void)setPropertyListRepresentation:(id)plist {
    inspectorType = [plist[@"InspectorType"] intValue];
    endianness = [plist[@"Endianness"] intValue];
    numberBase = [plist[@"NumberBase"] intValue];
}

@end
