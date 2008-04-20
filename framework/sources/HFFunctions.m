#import <HexFiend/HFFunctions.h>
#import <HexFiend/HFController.h>

#ifndef NDEBUG
//#define USE_CHUD 1
#endif

#ifndef USE_CHUD
#define USE_CHUD 0
#endif

#if USE_CHUD
#import <CHUD/CHUD.h>
#endif

NSImage *HFImageNamed(NSString *name) {
    HFASSERT(name != NULL);
    NSImage *image = [NSImage imageNamed:name];
    if (image == NULL) {
        NSString *imagePath = [[NSBundle bundleForClass:[HFController class]] pathForResource:name ofType:@"tiff"];
        if (! imagePath) {
            NSLog(@"Unable to find image named %@.tiff", name);
        }
        else {
            image = [[NSImage alloc] initByReferencingFile:imagePath];
            if (image == nil || ! [image isValid]) {
                NSLog(@"Couldn't load image at path %@", imagePath);
                [image release];
                image = nil;
            }
            else {
                [image retain];
                [image setName:name];
				[image setScalesWhenResized:YES];
            }
        }
    }
    return image;
}

@implementation HFRangeWrapper

- (HFRange)HFRange { return range; }

+ (HFRangeWrapper *)withRange:(HFRange)range {
    HFRangeWrapper *result = [[self alloc] init];
    result->range = range;
    return [result autorelease];
}

+ (NSArray *)withRanges:(const HFRange *)ranges count:(NSUInteger)count {
    HFASSERT(count == 0 || ranges != NULL);
    NSUInteger i;
    NSArray *result;
    NEW_ARRAY(HFRangeWrapper *, wrappers, count);
    for (i=0; i < count; i++) wrappers[i] = [self withRange:ranges[i]];
    result = [NSArray arrayWithObjects:wrappers count:count];
    FREE_ARRAY(wrappers);
    return result;
}

- (BOOL)isEqual:(id)obj {
    HFASSERT(obj != NULL);
    if (! [obj isKindOfClass:[HFRangeWrapper class]]) return NO;
    else return HFRangeEqualsRange(range, [obj HFRange]);
}

- (NSString *)description {
    return HFRangeToString(range);
}


static int hfrange_compare(const void *ap, const void *bp) {
    const HFRange *a = ap;
    const HFRange *b = bp;
    if (a->location < b->location) return -1;
    else if (a->location > b->location) return 1;
    else if (a->length < b->length) return -1;
    else if (a->length > b->length) return 1;
    else return 0;
}

+ (NSArray *)organizeAndMergeRanges:(NSArray *)inputRanges {
    HFASSERT(inputRanges != NULL);
    NSUInteger leading = 0, trailing = 0, length = [inputRanges count];
    if (length == 0) return [NSArray array];
    else if (length == 1) return [NSArray arrayWithArray:inputRanges];
    
    NEW_ARRAY(HFRange, ranges, length);
    [self getRanges:ranges fromArray:inputRanges];
    qsort(ranges, length, sizeof ranges[0], hfrange_compare);
    leading = 0;
    while (leading < length) {
        leading++;
        if (leading < length) {
            HFRange leadRange = ranges[leading], trailRange = ranges[trailing];
            if (HFIntersectsRange(leadRange, trailRange) || HFMaxRange(leadRange) == trailRange.location || HFMaxRange(trailRange) == leadRange.location) {
                ranges[trailing] = HFUnionRange(leadRange, trailRange);
            }
            else {
                trailing++;
                ranges[trailing] = ranges[leading];
            }
        }
    }
    NSArray *result = [HFRangeWrapper withRanges:ranges count:trailing + 1];
    FREE_ARRAY(ranges);
    return result;
}

+ (void)getRanges:(HFRange *)ranges fromArray:(NSArray *)array {
    HFASSERT(ranges != NULL || [array count] > 0);
    FOREACH(HFRangeWrapper*, wrapper, array) *ranges++ = [wrapper HFRange];
}

@end

BOOL HFStringEncodingIsSupersetOfASCII(NSStringEncoding encoding) {
    switch (encoding) {
	case kCFStringEncodingMacRoman: return YES;
	case kCFStringEncodingWindowsLatin1: return YES;
	case kCFStringEncodingISOLatin1: return YES;
	case kCFStringEncodingNextStepLatin: return YES;
	case kCFStringEncodingASCII: return YES;
	case kCFStringEncodingUnicode: return NO;
	case kCFStringEncodingUTF8: return YES;
	case kCFStringEncodingNonLossyASCII: return NO;
//	case kCFStringEncodingUTF16: return NO;
	case kCFStringEncodingUTF16BE: return NO;
	case kCFStringEncodingUTF16LE: return NO;
	case kCFStringEncodingUTF32: return NO;
	case kCFStringEncodingUTF32BE: return NO;
	case kCFStringEncodingUTF32LE: return NO;
	case kCFStringEncodingMacJapanese: return NO;
	case kCFStringEncodingMacChineseTrad: return YES;
	case kCFStringEncodingMacKorean: return YES;
	case kCFStringEncodingMacArabic: return NO;
	case kCFStringEncodingMacHebrew: return NO;
	case kCFStringEncodingMacGreek: return YES;
	case kCFStringEncodingMacCyrillic: return YES;
	case kCFStringEncodingMacDevanagari: return YES;
	case kCFStringEncodingMacGurmukhi: return YES;
	case kCFStringEncodingMacGujarati: return YES;
	case kCFStringEncodingMacOriya: return YES;
	case kCFStringEncodingMacBengali: return YES;
	case kCFStringEncodingMacTamil: return YES;
	case kCFStringEncodingMacTelugu: return YES;
	case kCFStringEncodingMacKannada: return YES;
	case kCFStringEncodingMacMalayalam: return YES;
	case kCFStringEncodingMacSinhalese: return YES;
	case kCFStringEncodingMacBurmese: return YES;
	case kCFStringEncodingMacKhmer: return YES;
	case kCFStringEncodingMacThai: return YES;
	case kCFStringEncodingMacLaotian: return YES;
	case kCFStringEncodingMacGeorgian: return YES;
	case kCFStringEncodingMacArmenian: return YES;
	case kCFStringEncodingMacChineseSimp: return YES;
	case kCFStringEncodingMacTibetan: return YES;
	case kCFStringEncodingMacMongolian: return YES;
	case kCFStringEncodingMacEthiopic: return YES;
	case kCFStringEncodingMacCentralEurRoman: return YES;
	case kCFStringEncodingMacVietnamese: return YES;
	case kCFStringEncodingMacExtArabic: return YES;
	case kCFStringEncodingMacSymbol: return NO;
	case kCFStringEncodingMacDingbats: return NO;
	case kCFStringEncodingMacTurkish: return YES;
	case kCFStringEncodingMacCroatian: return YES;
	case kCFStringEncodingMacIcelandic: return YES;
	case kCFStringEncodingMacRomanian: return YES;
	case kCFStringEncodingMacCeltic: return YES;
	case kCFStringEncodingMacGaelic: return YES;
	case kCFStringEncodingMacFarsi: return YES;
	case kCFStringEncodingMacUkrainian: return NO;
	case kCFStringEncodingMacInuit: return YES;
	case kCFStringEncodingMacVT100: return YES;
	case kCFStringEncodingMacHFS: return YES;
	case kCFStringEncodingISOLatin2: return YES;
	case kCFStringEncodingISOLatin3: return YES;
	case kCFStringEncodingISOLatin4: return YES;
	case kCFStringEncodingISOLatinCyrillic: return YES;
	case kCFStringEncodingISOLatinArabic: return NO;
	case kCFStringEncodingISOLatinGreek: return YES;
	case kCFStringEncodingISOLatinHebrew: return YES;
	case kCFStringEncodingISOLatin5: return YES;
	case kCFStringEncodingISOLatin6: return YES;
	case kCFStringEncodingISOLatinThai: return YES;
	case kCFStringEncodingISOLatin7: return YES;
	case kCFStringEncodingISOLatin8: return YES;
	case kCFStringEncodingISOLatin9: return YES;
	case kCFStringEncodingISOLatin10: return YES;
	case kCFStringEncodingDOSLatinUS: return YES;
	case kCFStringEncodingDOSGreek: return YES;
	case kCFStringEncodingDOSBalticRim: return YES;
	case kCFStringEncodingDOSLatin1: return YES;
	case kCFStringEncodingDOSGreek1: return YES;
	case kCFStringEncodingDOSLatin2: return YES;
	case kCFStringEncodingDOSCyrillic: return YES;
	case kCFStringEncodingDOSTurkish: return YES;
	case kCFStringEncodingDOSPortuguese: return YES;
	case kCFStringEncodingDOSIcelandic: return YES;
	case kCFStringEncodingDOSHebrew: return YES;
	case kCFStringEncodingDOSCanadianFrench: return YES;
	case kCFStringEncodingDOSArabic: return YES;
	case kCFStringEncodingDOSNordic: return YES;
	case kCFStringEncodingDOSRussian: return YES;
	case kCFStringEncodingDOSGreek2: return YES;
	case kCFStringEncodingDOSThai: return YES;
	case kCFStringEncodingDOSJapanese: return YES;
	case kCFStringEncodingDOSChineseSimplif: return YES;
	case kCFStringEncodingDOSKorean: return YES;
	case kCFStringEncodingDOSChineseTrad: return YES;
	case kCFStringEncodingWindowsLatin2: return YES;
	case kCFStringEncodingWindowsCyrillic: return YES;
	case kCFStringEncodingWindowsGreek: return YES;
	case kCFStringEncodingWindowsLatin5: return YES;
	case kCFStringEncodingWindowsHebrew: return YES;
	case kCFStringEncodingWindowsArabic: return YES;
	case kCFStringEncodingWindowsBalticRim: return YES;
	case kCFStringEncodingWindowsVietnamese: return YES;
	case kCFStringEncodingWindowsKoreanJohab: return YES;
	case kCFStringEncodingANSEL: return NO;
	case kCFStringEncodingJIS_X0201_76: return NO;
	case kCFStringEncodingJIS_X0208_83: return NO;
	case kCFStringEncodingJIS_X0208_90: return NO;
	case kCFStringEncodingJIS_X0212_90: return NO;
	case kCFStringEncodingJIS_C6226_78: return NO;
	case 0x0628/*kCFStringEncodingShiftJIS_X0213*/: return NO;
	case kCFStringEncodingShiftJIS_X0213_MenKuTen: return NO;
	case kCFStringEncodingGB_2312_80: return NO;
	case kCFStringEncodingGBK_95: return NO;
	case kCFStringEncodingGB_18030_2000: return NO;
	case kCFStringEncodingKSC_5601_87: return NO;
	case kCFStringEncodingKSC_5601_92_Johab: return NO;
	case kCFStringEncodingCNS_11643_92_P1: return NO;
	case kCFStringEncodingCNS_11643_92_P2: return NO;
	case kCFStringEncodingCNS_11643_92_P3: return NO;
	case kCFStringEncodingISO_2022_JP: return NO;
	case kCFStringEncodingISO_2022_JP_2: return NO;
	case kCFStringEncodingISO_2022_JP_1: return NO;
	case kCFStringEncodingISO_2022_JP_3: return NO;
	case kCFStringEncodingISO_2022_CN: return NO;
	case kCFStringEncodingISO_2022_CN_EXT: return NO;
	case kCFStringEncodingISO_2022_KR: return NO;
	case kCFStringEncodingEUC_JP: return YES;
	case kCFStringEncodingEUC_CN: return YES;
	case kCFStringEncodingEUC_TW: return YES;
	case kCFStringEncodingEUC_KR: return YES;
	case kCFStringEncodingShiftJIS: return NO;
	case kCFStringEncodingKOI8_R: return YES;
	case kCFStringEncodingBig5: return YES;
	case kCFStringEncodingMacRomanLatin1: return YES;
	case kCFStringEncodingHZ_GB_2312: return NO;
	case kCFStringEncodingBig5_HKSCS_1999: return YES;
	case kCFStringEncodingVISCII: return YES;
	case kCFStringEncodingKOI8_U: return YES;
	case kCFStringEncodingBig5_E: return YES;
	case kCFStringEncodingNextStepJapanese: return YES;
	case kCFStringEncodingEBCDIC_US: return NO;
	case kCFStringEncodingEBCDIC_CP037: return NO;
        default:
            NSLog(@"Unknown string encoding %lu in %s", encoding, __FUNCTION__);
            return NO;
    }
}

/* Converts a hexadecimal digit into a corresponding 4 bit unsigned int; returns -1 on failure.  The ... is a gcc extension. */
static NSInteger char2hex(unichar c) {
    switch (c) {
        case '0' ... '9': return c - '0';
        case 'a' ... 'f': return c - 'a' + 10;
        case 'A' ... 'F': return c - 'A' + 10;
        default: return -1;
    }
}

static unsigned char hex2char(NSUInteger c) {
    HFASSERT(c < 16);
    return "0123456789ABCDEF"[c];
}

NSData *HFDataFromHexString(NSString *string, BOOL* isMissingLastNybble) {
    REQUIRE_NOT_NULL(string);
    NSUInteger stringIndex=0, resultIndex=0, max=[string length];
    NSMutableData* result = [NSMutableData dataWithLength:(max + 1)/2];
    unsigned char* bytes = [result mutableBytes];
    
    NSUInteger numNybbles = 0;
    unsigned char byteValue = 0;
    
    for (stringIndex = 0; stringIndex < max; stringIndex++) {
        NSInteger val = char2hex([string characterAtIndex:stringIndex]);
        if (val < 0) continue;
        numNybbles++;
        byteValue = byteValue * 16 + (unsigned char)val;
        if (! (numNybbles % 2)) {
            bytes[resultIndex++] = byteValue;
            byteValue = 0;
        }
    }
    
    if (isMissingLastNybble) *isMissingLastNybble = (numNybbles % 2);
    
    //final nibble
    if (numNybbles % 2) {
        bytes[resultIndex++] = byteValue;
        byteValue = 0;
    }
    
    [result setLength:resultIndex];
    return result;    
}

NSString *HFHexStringFromData(NSData *data) {
    REQUIRE_NOT_NULL(data);
    NSUInteger dataLength = [data length];
    NSUInteger stringLength = HFProductInt(dataLength, 2);
    const unsigned char *bytes = [data bytes];
    unsigned char *charBuffer = check_malloc(stringLength);
    NSUInteger charIndex = 0, byteIndex;
    for (byteIndex = 0; byteIndex < dataLength; byteIndex++) {
        unsigned char byte = bytes[byteIndex];
        charBuffer[charIndex++] = hex2char(byte >> 4);
        charBuffer[charIndex++] = hex2char(byte & 0xF);
    }
    return [[[NSString alloc] initWithBytesNoCopy:charBuffer length:stringLength encoding:NSASCIIStringEncoding freeWhenDone:YES] autorelease];
}

void HFSetFDShouldCache(int fd, BOOL shouldCache) {
    int result = fcntl(fd, F_NOCACHE, !shouldCache);
    if (result == -1) {
        int err = errno;
        NSLog(@"fcntl(%d, F_NOCACHE, %d) returned error %d: %s", fd, !shouldCache, err, strerror(err));
    }
}


#if USE_CHUD
void HFStartTiming(const char *name) {
    static BOOL inited;
    if (! inited) {
        inited = YES;
        chudInitialize();
        chudSetErrorLogFile(stderr);
        chudAcquireRemoteAccess();
    }
    chudStartRemotePerfMonitor(name);
    
}

void HFStopTiming(void) {
    chudStopRemotePerfMonitor();
}
#else
void HFStartTiming(const char *name) { USE(name); }
void HFStopTiming(void) { }
#endif
