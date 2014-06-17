//
//  DataInspectorRepresenter.m
//  HexFiend_2
//
//  Created by peter on 5/22/09.
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "DataInspectorRepresenter.h"

/* NSTableColumn identifiers */
#define kInspectorTypeColumnIdentifier @"inspector_type"
#define kInspectorSubtypeColumnIdentifier @"inspector_subtype"
#define kInspectorValueColumnIdentifier @"inspected_value"
#define kInspectorSubtractButtonColumnIdentifier @"subtract_button"
#define kInspectorAddButtonColumnIdentifier @"add_button"

#define kScrollViewExtraPadding ((CGFloat)2.)

/* Declaration of SnowLeopard only property so we can build on Leopard */
#define NSTableViewSelectionHighlightStyleNone (-1)

/* The largest number of bytes that any inspector type can edit */
#define MAX_EDITABLE_BYTE_COUNT 128
#define INVALID_EDITING_BYTE_COUNT NSUIntegerMax

#define kDataInspectorUserDefaultsKey @"DataInspectorDefaults"

NSString * const DataInspectorDidChangeRowCount = @"DataInspectorDidChangeRowCount";
NSString * const DataInspectorDidDeleteAllRows = @"DataInspectorDidDeleteAllRows";

// Inspector types
// Needs to match menu order in DataInspectorView.xib
enum InspectorType_t {
    eInspectorTypeSignedInteger,
    eInspectorTypeUnsignedInteger,
    eInspectorTypeFloatingPoint,
    eInspectorTypeUTF8Text,
    
    // Total number of inspector types.
    eInspectorTypeCount
};

// Needs to match menu order in DataInspectorView.xib
enum Endianness_t {
    eEndianLittle, // (Endianness_t)0 is the default endianness.
    eEndianBig,

    // Total number of endiannesses.
    eEndianCount,
    
#if __BIG_ENDIAN__
    eNativeEndianness = eEndianBig
#else
    eNativeEndianness = eEndianLittle
#endif
};

/* A class representing a single row of the data inspector */
@interface DataInspector : NSObject {
    enum InspectorType_t inspectorType;
    enum Endianness_t endianness;
}

/* A data inspector that is different from the given inspectors, if possible. */
+ (DataInspector*)dataInspectorSupplementing:(NSArray*)inspectors;

- (enum InspectorType_t)type;
- (void)setType:(enum InspectorType_t)type;

- (enum Endianness_t)endianness;
- (void)setEndianness:(enum Endianness_t)endianness;

- (id)valueForController:(HFController *)controller ranges:(NSArray*)ranges isError:(BOOL *)outIsError;
- (id)valueForData:(NSData *)data isError:(BOOL *)outIsError;
- (id)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length isError:(BOOL *)outIsError;

/* Returns YES if we can replace the given number of bytes with this string value */
- (BOOL)acceptStringValue:(NSString *)value replacingByteCount:(NSUInteger)count intoData:(unsigned char *)outData;

/* Get and set a property list representation, for persisting to user defaults */
- (id)propertyListRepresentation;
- (void)setPropertyListRepresentation:(id)plist;

@end

@implementation DataInspector

+ (DataInspector*)dataInspectorSupplementing:(NSArray*)inspectors {
    DataInspector *ret = [[[DataInspector alloc] init] autorelease];

    enum Endianness_t preferredEndian; // Prefer the most popular endianness among inspectors
    uint32_t present = 0; // Bit set of all inspector types that are already present.
    
    _Static_assert(eEndianCount <= 2, "This part of the code assumes only two supported endianesses.");
    int endianessVote = 0; // +1 for enum == 0, -1 enum != 0.
    FOREACH(DataInspector *, di, inspectors) {
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
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super init];
    inspectorType = [coder decodeInt32ForKey:@"InspectorType"];
    endianness = [coder decodeInt32ForKey:@"Endianness"];
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

- (NSUInteger)hash {
    return inspectorType + (endianness << 8UL);
}

- (BOOL)isEqual:(DataInspector *)him {
    if (! [him isKindOfClass:[DataInspector class]]) return NO;
    return inspectorType == him->inspectorType && endianness == him->endianness;
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
#define FORMAT(specifier) return [NSString stringWithFormat:specifier, s];
static id signedIntegerDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness) {
    switch (length) {
        case 1:
        {
            FETCH(int8_t)
            FORMAT(@"%d")
        }
        case 2:
        {
            FETCH(int16_t)
            FLIP(2)
            FORMAT(@"%hi")
        }
        case 4:
        {
            FETCH(int32_t)
            FLIP(4)
            FORMAT(@"%d")
        }
        case 8:
        {
            FETCH(int64_t)
            FLIP(8)
            FORMAT(@"%qi")
        }
        case 16:
        {
            FETCH(__int128_t)
            FLIP(16)
            BOOL neg = s < 0 ? (s=-s), YES : NO;
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

static id unsignedIntegerDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness) {
    switch (length) {
        case 1:
        {
            FETCH(uint8_t)
            FORMAT(@"%u")
        }
        case 2:
        {
            FETCH(uint16_t)
            FLIP(2)
            FORMAT(@"%hu")
        }
        case 4:
        {
            FETCH(uint32_t)
            FLIP(4)
            FORMAT(@"%u")
        }
        case 8:
        {
            FETCH(uint64_t)
            FLIP(8)
            FORMAT(@"%qu")
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

static id floatingPointDescription(const unsigned char *bytes, NSUInteger length, enum Endianness_t endianness) {
    switch (length) {
        case sizeof(float):
        {
            union {
                uint32_t i;
                float f;
            } temp;
            _Static_assert(sizeof temp.f == sizeof temp.i, "sizeof(float) is not 4!");
            temp.i = *(const uint32_t *)bytes;
            if (endianness != eNativeEndianness) temp.i = (uint32_t)reverse(temp.i, sizeof(float));
            return [NSString stringWithFormat:@"%.15g", temp.f];
        }
        case sizeof(double):
        {
            union {
                uint64_t i;
                double f;
            } temp;
            _Static_assert(sizeof temp.f == sizeof temp.i, "sizeof(double) is not 8!");
            temp.i = *(const uint64_t *)bytes;
            if (endianness != eNativeEndianness) temp.i = reverse(temp.i, sizeof(double));
            return [NSString stringWithFormat:@"%.15g", temp.f];
        }
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

static NSString * const InspectionErrorNoData =  @"(select some data)";
static NSString * const InspectionErrorTooMuch = @"(select less data)";
static NSString * const InspectionErrorTooLittle = @"(select more data)";
static NSString * const InspectionErrorNonPwr2 = @"(select a power of 2 bytes)";
static NSString * const InspectionErrorInternal = @"(internal error)";

static NSAttributedString *inspectionError(NSString *s) {
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    [paragraphStyle setMinimumLineHeight:(CGFloat)16.];
    NSAttributedString *result = [[NSAttributedString alloc] initWithString:s attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor disabledControlTextColor], NSForegroundColorAttributeName, [NSFont controlContentFontOfSize:11], NSFontAttributeName, paragraphStyle, NSParagraphStyleAttributeName, nil]];
    [paragraphStyle release];
    return [result autorelease];
}

- (id)valueForController:(HFController *)controller ranges:(NSArray *)ranges isError:(BOOL *)outIsError {
    /* Just do a rough cut on length before going to valueForData. */
    
    if ([ranges count] != 1) {
        if(outIsError) *outIsError = YES;
        return inspectionError(@"(select a contiguous range)");
    }
    HFRange range = [[ranges objectAtIndex:0] HFRange];
    
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
        default:
            if(outIsError) *outIsError = YES;
            return inspectionError(InspectionErrorInternal);
    }
    
    return [self valueForData:[controller dataForRange:range] isError:outIsError];
}

- (id)valueForData:(NSData *)data isError:(BOOL *)outIsError {
    return [self valueForBytes:[data bytes] length:[data length] isError:outIsError];
}

- (id)valueForBytes:(const unsigned char *)bytes length:(NSUInteger)length isError:(BOOL *)outIsError {
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
                        return signedIntegerDescription(bytes, length, endianness);
                    else
                        return unsignedIntegerDescription(bytes, length, endianness);
                default:
                    return length > 8 ? inspectionError(InspectionErrorTooMuch) : inspectionError(InspectionErrorNonPwr2);
            }
        
        case eInspectorTypeFloatingPoint:
            switch (length) {
                case 0:
                    return inspectionError(InspectionErrorNoData);
                case 1: case 2: case 3:
                    return inspectionError(InspectionErrorTooLittle);
                case 4: case 8: case 10: case 16:
                    if(outIsError) *outIsError = NO;
                    return floatingPointDescription(bytes, length, endianness);
                default:
                    return length > 16 ? inspectionError(InspectionErrorTooMuch) : inspectionError(InspectionErrorNonPwr2);
            }
                
        case eInspectorTypeUTF8Text: {
            if(length == 0) return inspectionError(InspectionErrorNoData);
            if(length > MAX_EDITABLE_BYTE_COUNT) return inspectionError(InspectionErrorTooMuch);
            NSString *ret = [[[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding] autorelease];
            if(ret == nil) return inspectionError(@"(bytes are not valid UTF-8)");
            if(outIsError) *outIsError = NO;
            return ret;
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
            float __attribute__((mode(XF))) x;
            __uint128_t t; // Maybe clang will support mode(TF) one day.
        } val;

        char *endPtr = NULL;
        errno = 0;
        
        switch(count) {
            case 4: val.f = strtof(buffer, &endPtr); break;
            case 8: val.d = strtod(buffer, &endPtr); break;
            case 10: val.x = strtold(buffer, &endPtr); break;
            case 16: {
                val.x = strtold(buffer, &endPtr);
                val.t = (val.t >> 64 << 112) | (val.t << 48 << 17 >> 16);
                break;
            }
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
    else {
        /* Unknown inspector type */
        return NO;
    }
}

- (id)propertyListRepresentation {
    return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:inspectorType], @"InspectorType", [NSNumber numberWithInt:endianness], @"Endianness", nil];
}

- (void)setPropertyListRepresentation:(id)plist {
    inspectorType = [[plist objectForKey:@"InspectorType"] intValue];
    endianness = [[plist objectForKey:@"Endianness"] intValue];
}

@end

@implementation DataInspectorScrollView

- (void)drawDividerWithClip:(NSRect)clipRect {
    [[NSColor lightGrayColor] set];
    NSRect bounds = [self bounds];
    NSRect lineRect = bounds;
    lineRect.size.height = 1;
    NSRectFill(NSIntersectionRect(lineRect, clipRect));
}

- (void)drawRect:(NSRect)rect {
    [[NSColor colorWithCalibratedWhite:(CGFloat).91 alpha:1] set];
    NSRectFill(rect);
    [self drawDividerWithClip:rect];
}

@end

@implementation DataInspectorRepresenter

- (id)init {
    self = [super init];
    inspectors = [[NSMutableArray alloc] init];
    [self loadDefaultInspectors];
    return self;
}

- (void)dealloc {
    [inspectors release];
    [super dealloc];
}

- (void)encodeWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    [super encodeWithCoder:coder];
    [coder encodeObject:inspectors forKey:@"HFInspectors"];
}

- (id)initWithCoder:(NSCoder *)coder {
    HFASSERT([coder allowsKeyedCoding]);
    self = [super initWithCoder:coder];
    inspectors = [[coder decodeObjectForKey:@"HFInspectors"] retain];
    return self;
}

- (void)loadDefaultInspectors {
    NSArray *defaultInspectorDictionaries = [[NSUserDefaults standardUserDefaults] objectForKey:kDataInspectorUserDefaultsKey];
    if (! defaultInspectorDictionaries) {
        DataInspector *ins = [[DataInspector alloc] init];
        [inspectors addObject:ins];
        [ins release];
    }
    else {
        NSEnumerator *enumer = [defaultInspectorDictionaries objectEnumerator];
        NSDictionary *inspectorDictionary;
        while ((inspectorDictionary = [enumer nextObject])) {
            DataInspector *ins = [[DataInspector alloc] init];
            [ins setPropertyListRepresentation:inspectorDictionary];
            [inspectors addObject:ins];
            [ins release];            
        }
    }
}

- (void)saveDefaultInspectors {
    NSMutableArray *inspectorDictionaries = [[NSMutableArray alloc] init];
    DataInspector *inspector;
    NSEnumerator *enumer = [inspectors objectEnumerator];
    while ((inspector = [enumer nextObject])) {
        [inspectorDictionaries addObject:[inspector propertyListRepresentation]];
    }
    [[NSUserDefaults standardUserDefaults] setObject:inspectorDictionaries forKey:kDataInspectorUserDefaultsKey];
    [inspectorDictionaries release];
}

- (NSView *)createView {
    BOOL loaded = NO;
    NSMutableArray *topLevelObjects = [NSMutableArray array];
    if ([[NSBundle mainBundle] respondsToSelector:@selector(loadNibNamed:owner:topLevelObjects:)]) {
        /* for Mac OS X 10.9 or higher */
        // unlike -loadNibNamed:owner: which is deprecated in 10.8, this method does
        // not retain top level objects automatically, so objects must be set retain
        loaded = [[NSBundle mainBundle] loadNibNamed:@"DataInspectorView" owner:self topLevelObjects:&topLevelObjects];
        if (! loaded || ! outletView) {
            [NSException raise:NSInternalInconsistencyException format:@"Unable to load nib named DataInspectorView"];
        }
        [topLevelObjects retain];
    } else {
        /* for Mac OS X 10.8 or lower */
        loaded = [NSBundle loadNibNamed:@"DataInspectorView" owner:self];
        if (! loaded || ! outletView) {
            [NSException raise:NSInternalInconsistencyException format:@"Unable to load nib named DataInspectorView"];
        }
    }
    NSView *resultView = outletView; //want to inherit its retain here
    outletView = nil;
    if ([table respondsToSelector:@selector(setSelectionHighlightStyle:)]) {
        [table setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleNone];
    }
    [table setBackgroundColor:[NSColor colorWithCalibratedWhite:(CGFloat).91 alpha:1]];
    [table setRefusesFirstResponder:YES];
    [table setTarget:self];
    [table setDoubleAction:@selector(doubleClickedTable:)];    
    return resultView;
}

- (void)initializeView {
    [self resizeTableViewAfterChangingRowCount];
}

+ (NSPoint)defaultLayoutPosition {
    return NSMakePoint(0, (CGFloat)-.5);
}

- (NSUInteger)rowCount {
    return [inspectors count];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    USE(tableView);
    return [self rowCount];
}

/* returns the number of bytes that are selected, or NSUIntegerMax if there is more than one selection, or the selection is larger than MAX_EDITABLE_BYTE_COUNT */
- (NSInteger)selectedByteCountForEditing {
    NSArray *selectedRanges = [[self controller] selectedContentsRanges];
    if ([selectedRanges count] != 1) return INVALID_EDITING_BYTE_COUNT;
    HFRange selectedRange = [[selectedRanges objectAtIndex:0] HFRange];
    if (selectedRange.length > MAX_EDITABLE_BYTE_COUNT) return INVALID_EDITING_BYTE_COUNT;
    return ll2l(selectedRange.length);
}

- (id)valueFromInspector:(DataInspector *)inspector isError:(BOOL *)outIsError{
    HFController *controller = [self controller];
    return [inspector valueForController:controller ranges:[controller selectedContentsRanges] isError:outIsError];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    USE(tableView);
    DataInspector *inspector = [inspectors objectAtIndex:row];
    NSString *ident = [tableColumn identifier];
    if ([ident isEqualToString:kInspectorTypeColumnIdentifier]) {
        return [NSNumber numberWithInt:[inspector type]];
    }
    else if ([ident isEqualToString:kInspectorSubtypeColumnIdentifier]) {
        return [NSNumber numberWithInt:[inspector endianness]];
    }
    else if ([ident isEqualToString:kInspectorValueColumnIdentifier]) {
        return [self valueFromInspector:inspector isError:NULL];
    }
    else if ([ident isEqualToString:kInspectorAddButtonColumnIdentifier] || [ident isEqualToString:kInspectorSubtractButtonColumnIdentifier]) {
        return [NSNumber numberWithInt:1]; //just a button
    }
    else {
        NSLog(@"Unknown column identifier %@", ident);
        return nil;
    }
}

- (void)tableView:(NSTableView *)tableView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSString *ident = [tableColumn identifier];
    /* This gets called after clicking on the + or - button.  If you delete the last row, then this gets called with a row >= the number of inspectors, so bail out for +/- buttons before pulling out our inspector */
    if ([ident isEqualToString:kInspectorSubtractButtonColumnIdentifier]) return;
    
    DataInspector *inspector = [inspectors objectAtIndex:row];
    if ([ident isEqualToString:kInspectorTypeColumnIdentifier]) {
        [inspector setType:[object intValue]];
        [tableView reloadData];
    }
    else if ([ident isEqualToString:kInspectorSubtypeColumnIdentifier]) {
        [inspector setEndianness:[object intValue]];
        [tableView reloadData];
    }
    else if ([ident isEqualToString:kInspectorValueColumnIdentifier]) {
        NSUInteger byteCount = [self selectedByteCountForEditing];
        if (byteCount != INVALID_EDITING_BYTE_COUNT) {
            unsigned char bytes[MAX_EDITABLE_BYTE_COUNT];
            HFASSERT(byteCount <= sizeof(bytes));
            if ([inspector acceptStringValue:object replacingByteCount:byteCount intoData:bytes]) {
                HFController *controller = [self controller];
                NSArray *selectedRanges = [controller selectedContentsRanges];
                NSData *data = [[NSData alloc] initWithBytesNoCopy:bytes length:byteCount freeWhenDone:NO];
                [controller insertData:data replacingPreviousBytes:0 allowUndoCoalescing:NO];
                [data release];
                [controller setSelectedContentsRanges:selectedRanges]; //Hack to preserve the selection across the data insertion
            }
        }
    }
    else if ([ident isEqualToString:kInspectorAddButtonColumnIdentifier] || [ident isEqualToString:kInspectorSubtractButtonColumnIdentifier]) {
        /* Nothing to do */
    }
    else {
        NSLog(@"Unknown column identifier %@", ident);
    }
    
}

- (void)resizeTableViewAfterChangingRowCount {
    [table noteNumberOfRowsChanged];
    NSUInteger rowCount = [table numberOfRows];
    if (rowCount > 0) {
        NSScrollView *scrollView = [table enclosingScrollView];
        NSSize newTableViewBoundsSize = [table frame].size;
        newTableViewBoundsSize.height = NSMaxY([table rectOfRow:rowCount - 1]) - NSMinY([table bounds]);
        /* Is converting to the scroll view's coordinate system right?  It doesn't matter much because nothing is scaled except possibly the window */
        CGFloat newScrollViewHeight = [[scrollView class] frameSizeForContentSize:[table convertSize:newTableViewBoundsSize toView:scrollView]
                                                            hasHorizontalScroller:[scrollView hasHorizontalScroller]
                                                              hasVerticalScroller:[scrollView hasVerticalScroller]
                                                                       borderType:[scrollView borderType]].height + kScrollViewExtraPadding;
        [[NSNotificationCenter defaultCenter] postNotificationName:DataInspectorDidChangeRowCount object:self userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithDouble:newScrollViewHeight] forKey:@"height"]];
    }
}

- (void)addRow:(id)sender {
    USE(sender);
    DataInspector *x = [DataInspector dataInspectorSupplementing:inspectors];
    [inspectors insertObject:x atIndex:[table clickedRow]+1];
    [self saveDefaultInspectors];
    [self resizeTableViewAfterChangingRowCount];
}

- (void)removeRow:(id)sender {
    USE(sender);
    if ([self rowCount] == 1) {
	[[NSNotificationCenter defaultCenter] postNotificationName:DataInspectorDidDeleteAllRows object:self userInfo:nil];
    }
    else {
	NSInteger clickedRow = [table clickedRow];
	[inspectors removeObjectAtIndex:clickedRow];
        [self saveDefaultInspectors];
	[self resizeTableViewAfterChangingRowCount];
    }
}

- (IBAction)doubleClickedTable:(id)sender {
    USE(sender);
    NSInteger column = [table clickedColumn], row = [table clickedRow];
    if (column >= 0 && row >= 0 && [[[[table tableColumns] objectAtIndex:column] identifier] isEqual:kInspectorValueColumnIdentifier]) {
	BOOL isError;
	[self valueFromInspector:[inspectors objectAtIndex:row] isError:&isError];
	if (! isError) {
	    [table editColumn:column row:row withEvent:[NSApp currentEvent] select:YES];
	}
	else {
	    NSBeep();
	}
    }
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    USE(control);
    NSInteger row = [table editedRow];
    if (row < 0) return YES; /* paranoia */
    
    NSUInteger byteCount = [self selectedByteCountForEditing];
    if (byteCount == INVALID_EDITING_BYTE_COUNT) return NO;
    
    DataInspector *inspector = [inspectors objectAtIndex:row];
    return [inspector acceptStringValue:[fieldEditor string] replacingByteCount:byteCount intoData:NULL];
}


/* Prevent all row selection */

- (BOOL)tableView:(NSTableView *)tableView shouldSelectRow:(NSInteger)row {
    USE(tableView);
    USE(row);
    return NO;
}

- (BOOL)tableView:(NSTableView *)tableView shouldTrackCell:(NSCell *)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    USE(tableView);
    USE(row);
    USE(cell);
    USE(tableColumn);
    return YES;
}


- (void)refreshTableValues {
    [table reloadData];
}

- (void)controllerDidChange:(HFControllerPropertyBits)bits {
    if (bits & (HFControllerSelectedRanges | HFControllerContentValue)) {
        [self refreshTableValues];
    }
    [super controllerDidChange:bits];
}

@end

@implementation DataInspectorPlusMinusButtonCell

- (id)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    [self setBezelStyle:NSRoundRectBezelStyle];
    return self;
}

- (void)drawDataInspectorTitleWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    const BOOL isPlus = [[self title] isEqual:@"+"];
    const unsigned char grayColor = 0x73;
    const unsigned char alpha = 0xFF;
#if __BIG_ENDIAN__
    const unsigned short X = (grayColor << 8) | alpha ;
#else
    const unsigned short X = (alpha << 8) | grayColor;
#endif
    const NSUInteger bytesPerPixel = sizeof X;
    const unsigned short plusData[] = {
	0,0,0,X,X,0,0,0,
	0,0,0,X,X,0,0,0,
	0,0,0,X,X,0,0,0,
	X,X,X,X,X,X,X,X,
	X,X,X,X,X,X,X,X,
	0,0,0,X,X,0,0,0,
	0,0,0,X,X,0,0,0,
	0,0,0,X,X,0,0,0
    };
    
    const unsigned short minusData[] = {
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	X,X,X,X,X,X,X,X,
	X,X,X,X,X,X,X,X,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0,
	0,0,0,0,0,0,0,0
    };
    
    const unsigned char * const bitmapData = (const unsigned char *)(isPlus ? plusData : minusData);
    
    NSInteger width = 8, height = 8;
    assert(width * height * bytesPerPixel == sizeof plusData);
    assert(width * height * bytesPerPixel == sizeof minusData);
    NSRect bitmapRect = NSMakeRect(NSMidX(cellFrame) - width/2, NSMidY(cellFrame) - height/2, width, height);
    bitmapRect = [controlView centerScanRect:bitmapRect];

    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceGenericGray);
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, bitmapData, width * height * bytesPerPixel, NULL);
    CGImageRef image = CGImageCreate(width, height, CHAR_BIT, bytesPerPixel * CHAR_BIT, bytesPerPixel * width, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast, provider, NULL, YES, kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(space);
    [[NSGraphicsContext currentContext] setCompositingOperation:NSCompositeSourceOver];
    CGContextDrawImage([[NSGraphicsContext currentContext] graphicsPort], *(CGRect *)&bitmapRect, image);
    CGImageRelease(image);
}

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView {
    /* Defeat title drawing by doing nothing */
    USE(title);
    USE(frame);
    USE(controlView);
    return NSZeroRect;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    [super drawWithFrame:cellFrame inView:controlView];
    [self drawDataInspectorTitleWithFrame:cellFrame inView:controlView];

}

@end

@implementation DataInspectorTableView

- (void)highlightSelectionInClipRect:(NSRect)clipRect {
    USE(clipRect);
}

@end
