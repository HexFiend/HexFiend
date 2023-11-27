//
//  HFEncodingManager.m
//  HexFiend_Framework
//
//  Created by Kevin Wojniak on 12/30/18.
//  Copyright © 2018 ridiculous_fish. All rights reserved.
//

#import "HFEncodingManager.h"
#import <HexFiend/HFCustomEncoding.h>

@interface HFEncodingManager ()

@property (readwrite) NSArray<HFNSStringEncoding *> *systemEncodings;
@property (readwrite) NSDictionary<NSNumber *, HFNSStringEncoding *> *systemEncodingsByType;

@end

@implementation HFEncodingManager
{
    NSMutableArray<HFCustomEncoding *> *_customEncodings;
}

+ (instancetype)shared {
    static HFEncodingManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[HFEncodingManager alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    [self loadEncodings];
    return self;
}

static void addEncoding(NSString *name, CFStringEncoding value, NSMutableArray<HFNSStringEncoding*> *encodings, NSMutableSet<NSNumber *> *usedEncodings, NSMutableDictionary<NSNumber *, HFNSStringEncoding *> *systemEncodingsByType) {
    NSStringEncoding cocoaEncoding = CFStringConvertEncodingToNSStringEncoding(value);
    if (cocoaEncoding == kCFStringEncodingInvalidId) {
        /* Unsupported! */
        return;
    }
    if ([usedEncodings containsObject:@(cocoaEncoding)]) {
        return;
    }
    
    /* Strip off the common prefix */
    NSString *identifier;
    NSString *prefix = @"kCFStringEncoding";
    if ([name hasPrefix:prefix]) {
        identifier = [name substringFromIndex:prefix.length];
    } else {
        identifier = name;
    }
    
    /* Get the encoding name */
    NSString *encodingName = (__bridge NSString *)CFStringGetNameOfEncoding(value);
    if (!encodingName) {
        encodingName = @"";
    }
    
    NSString *theName = encodingName.length > 0 ? encodingName : identifier;
    HFNSStringEncoding *encoding = [[HFNSStringEncoding alloc] initWithEncoding:cocoaEncoding name:theName identifier:identifier];
    [encodings addObject:encoding];
    [usedEncodings addObject:@(cocoaEncoding)];
    systemEncodingsByType[@(cocoaEncoding)] = encoding;
}

/* Python script to generate string encoding stuff:
 
 #!/usr/bin/python
 import sys, re
 exp = re.compile(r"""kCFStringEncoding[^\s]+""");
 for line in sys.stdin:
 match = exp.search(line)
 if match != None:
 print "ENCODING(" + match.group(0) + ");"
 
 
 ./script.py < /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/CoreFoundation.framework/Versions/A/Headers/CFStringEncodingExt.h
 */

- (void)loadEncodings {
    NSMutableArray<HFNSStringEncoding *> *encodings = [NSMutableArray array];
    NSMutableSet<NSNumber *> *usedEncodings = [NSMutableSet set];
    NSMutableDictionary<NSNumber *, HFNSStringEncoding *> *systemEncodingsByType = [NSMutableDictionary dictionary];
#define ENCODING(a) do { addEncoding( @ #a, (a), encodings, usedEncodings, systemEncodingsByType); } while (0)
    // [NSString availableStringEncodings] doesn't list all CF encodings
    ENCODING(kCFStringEncodingMacRoman);
    ENCODING(kCFStringEncodingWindowsLatin1);
    ENCODING(kCFStringEncodingISOLatin1);
    ENCODING(kCFStringEncodingNextStepLatin);
    ENCODING(kCFStringEncodingASCII);
    ENCODING(kCFStringEncodingUnicode);
    ENCODING(kCFStringEncodingUTF8);
    ENCODING(kCFStringEncodingNonLossyASCII);
    ENCODING(kCFStringEncodingUTF16);
    ENCODING(kCFStringEncodingUTF16BE);
    ENCODING(kCFStringEncodingUTF16LE);
    ENCODING(kCFStringEncodingUTF32);
    ENCODING(kCFStringEncodingUTF32BE);
    ENCODING(kCFStringEncodingUTF32LE);
    ENCODING(kCFStringEncodingMacRoman);
    ENCODING(kCFStringEncodingMacJapanese);
    ENCODING(kCFStringEncodingMacChineseTrad);
    ENCODING(kCFStringEncodingMacKorean);
    ENCODING(kCFStringEncodingMacArabic);
    ENCODING(kCFStringEncodingMacHebrew);
    ENCODING(kCFStringEncodingMacGreek);
    ENCODING(kCFStringEncodingMacCyrillic);
    ENCODING(kCFStringEncodingMacDevanagari);
    ENCODING(kCFStringEncodingMacGurmukhi);
    ENCODING(kCFStringEncodingMacGujarati);
    ENCODING(kCFStringEncodingMacOriya);
    ENCODING(kCFStringEncodingMacBengali);
    ENCODING(kCFStringEncodingMacTamil);
    ENCODING(kCFStringEncodingMacTelugu);
    ENCODING(kCFStringEncodingMacKannada);
    ENCODING(kCFStringEncodingMacMalayalam);
    ENCODING(kCFStringEncodingMacSinhalese);
    ENCODING(kCFStringEncodingMacBurmese);
    ENCODING(kCFStringEncodingMacKhmer);
    ENCODING(kCFStringEncodingMacThai);
    ENCODING(kCFStringEncodingMacLaotian);
    ENCODING(kCFStringEncodingMacGeorgian);
    ENCODING(kCFStringEncodingMacArmenian);
    ENCODING(kCFStringEncodingMacChineseSimp);
    ENCODING(kCFStringEncodingMacTibetan);
    ENCODING(kCFStringEncodingMacMongolian);
    ENCODING(kCFStringEncodingMacEthiopic);
    ENCODING(kCFStringEncodingMacCentralEurRoman);
    ENCODING(kCFStringEncodingMacVietnamese);
    ENCODING(kCFStringEncodingMacExtArabic);
    ENCODING(kCFStringEncodingMacSymbol);
    ENCODING(kCFStringEncodingMacDingbats);
    ENCODING(kCFStringEncodingMacTurkish);
    ENCODING(kCFStringEncodingMacCroatian);
    ENCODING(kCFStringEncodingMacIcelandic);
    ENCODING(kCFStringEncodingMacRomanian);
    ENCODING(kCFStringEncodingMacCeltic);
    ENCODING(kCFStringEncodingMacGaelic);
    ENCODING(kCFStringEncodingMacFarsi);
    ENCODING(kCFStringEncodingMacUkrainian);
    ENCODING(kCFStringEncodingMacInuit);
    ENCODING(kCFStringEncodingMacVT100);
    ENCODING(kCFStringEncodingMacHFS);
    ENCODING(kCFStringEncodingISOLatin1);
    ENCODING(kCFStringEncodingISOLatin2);
    ENCODING(kCFStringEncodingISOLatin3);
    ENCODING(kCFStringEncodingISOLatin4);
    ENCODING(kCFStringEncodingISOLatinCyrillic);
    ENCODING(kCFStringEncodingISOLatinArabic);
    ENCODING(kCFStringEncodingISOLatinGreek);
    ENCODING(kCFStringEncodingISOLatinHebrew);
    ENCODING(kCFStringEncodingISOLatin5);
    ENCODING(kCFStringEncodingISOLatin6);
    ENCODING(kCFStringEncodingISOLatinThai);
    ENCODING(kCFStringEncodingISOLatin7);
    ENCODING(kCFStringEncodingISOLatin8);
    ENCODING(kCFStringEncodingISOLatin9);
    ENCODING(kCFStringEncodingISOLatin10);
    ENCODING(kCFStringEncodingDOSLatinUS);
    ENCODING(kCFStringEncodingDOSGreek);
    ENCODING(kCFStringEncodingDOSBalticRim);
    ENCODING(kCFStringEncodingDOSLatin1);
    ENCODING(kCFStringEncodingDOSGreek1);
    ENCODING(kCFStringEncodingDOSLatin2);
    ENCODING(kCFStringEncodingDOSCyrillic);
    ENCODING(kCFStringEncodingDOSTurkish);
    ENCODING(kCFStringEncodingDOSPortuguese);
    ENCODING(kCFStringEncodingDOSIcelandic);
    ENCODING(kCFStringEncodingDOSHebrew);
    ENCODING(kCFStringEncodingDOSCanadianFrench);
    ENCODING(kCFStringEncodingDOSArabic);
    ENCODING(kCFStringEncodingDOSNordic);
    ENCODING(kCFStringEncodingDOSRussian);
    ENCODING(kCFStringEncodingDOSGreek2);
    ENCODING(kCFStringEncodingDOSThai);
    ENCODING(kCFStringEncodingDOSJapanese);
    ENCODING(kCFStringEncodingDOSChineseSimplif);
    ENCODING(kCFStringEncodingDOSKorean);
    ENCODING(kCFStringEncodingDOSChineseTrad);
    ENCODING(kCFStringEncodingWindowsLatin1);
    ENCODING(kCFStringEncodingWindowsLatin2);
    ENCODING(kCFStringEncodingWindowsCyrillic);
    ENCODING(kCFStringEncodingWindowsGreek);
    ENCODING(kCFStringEncodingWindowsLatin5);
    ENCODING(kCFStringEncodingWindowsHebrew);
    ENCODING(kCFStringEncodingWindowsArabic);
    ENCODING(kCFStringEncodingWindowsBalticRim);
    ENCODING(kCFStringEncodingWindowsVietnamese);
    ENCODING(kCFStringEncodingWindowsKoreanJohab);
    ENCODING(kCFStringEncodingASCII);
    ENCODING(kCFStringEncodingANSEL);
    ENCODING(kCFStringEncodingJIS_X0201_76);
    ENCODING(kCFStringEncodingJIS_X0208_83);
    ENCODING(kCFStringEncodingJIS_X0208_90);
    ENCODING(kCFStringEncodingJIS_X0212_90);
    ENCODING(kCFStringEncodingJIS_C6226_78);
    ENCODING(kCFStringEncodingShiftJIS_X0213);
    ENCODING(kCFStringEncodingShiftJIS_X0213_MenKuTen);
    ENCODING(kCFStringEncodingGB_2312_80);
    ENCODING(kCFStringEncodingGBK_95);
    ENCODING(kCFStringEncodingGB_18030_2000);
    ENCODING(kCFStringEncodingKSC_5601_87);
    ENCODING(kCFStringEncodingKSC_5601_92_Johab);
    ENCODING(kCFStringEncodingCNS_11643_92_P1);
    ENCODING(kCFStringEncodingCNS_11643_92_P2);
    ENCODING(kCFStringEncodingCNS_11643_92_P3);
    ENCODING(kCFStringEncodingISO_2022_JP);
    ENCODING(kCFStringEncodingISO_2022_JP_2);
    ENCODING(kCFStringEncodingISO_2022_JP_1);
    ENCODING(kCFStringEncodingISO_2022_JP_3);
    ENCODING(kCFStringEncodingISO_2022_CN);
    ENCODING(kCFStringEncodingISO_2022_CN_EXT);
    ENCODING(kCFStringEncodingISO_2022_KR);
    ENCODING(kCFStringEncodingEUC_JP);
    ENCODING(kCFStringEncodingEUC_CN);
    ENCODING(kCFStringEncodingEUC_TW);
    ENCODING(kCFStringEncodingEUC_KR);
    ENCODING(kCFStringEncodingShiftJIS);
    ENCODING(kCFStringEncodingKOI8_R);
    ENCODING(kCFStringEncodingBig5);
    ENCODING(kCFStringEncodingMacRomanLatin1);
    ENCODING(kCFStringEncodingHZ_GB_2312);
    ENCODING(kCFStringEncodingBig5_HKSCS_1999);
    ENCODING(kCFStringEncodingVISCII);
    ENCODING(kCFStringEncodingKOI8_U);
    ENCODING(kCFStringEncodingBig5_E);
    ENCODING(kCFStringEncodingNextStepLatin);
    ENCODING(kCFStringEncodingNextStepJapanese);
    ENCODING(kCFStringEncodingEBCDIC_US);
    ENCODING(kCFStringEncodingEBCDIC_CP037);
    ENCODING(kCFStringEncodingUTF7);
    ENCODING(kCFStringEncodingUTF7_IMAP);
    ENCODING(kCFStringEncodingShiftJIS_X0213_00);
#undef ENCODING
    self.systemEncodings = encodings;
    self.systemEncodingsByType = systemEncodingsByType;
}

- (HFNSStringEncoding *)systemEncoding:(NSStringEncoding)systenEncoding {
    return self.systemEncodingsByType[@(systenEncoding)];
}

- (NSArray<HFCustomEncoding *> *)loadCustomEncodingsFromDirectory:(NSString *)directory {
    NSMutableArray<HFCustomEncoding *> *newEncodings = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *filename in [fm enumeratorAtPath:directory]) {
        if ([filename.pathExtension isEqualToString:@"json"]) {
            NSString *path = [directory stringByAppendingPathComponent:filename];
            HFCustomEncoding *encoding = [[HFCustomEncoding alloc] initWithPath:path];
            if (!encoding) {
                NSLog(@"Error with file %@", path);
                continue;
            }
            [newEncodings addObject:encoding];
        }
    }
    if (!_customEncodings) {
        _customEncodings = [NSMutableArray array];
    }
    [_customEncodings addObjectsFromArray:newEncodings];
    return newEncodings;
}

- (HFStringEncoding *)encodingByIdentifier:(NSString *)identifier {
    NSString *identifierLower = identifier.lowercaseString;
    for (HFNSStringEncoding *encoding in self.systemEncodings) {
        if ([encoding.identifier.lowercaseString isEqualToString:identifierLower]) {
            return encoding;
        }
    }
    for (HFCustomEncoding *encoding in self.customEncodings) {
        if ([encoding.identifier.lowercaseString isEqualToString:identifierLower]) {
            return encoding;
        }
    }
    return nil;
}

- (HFNSStringEncoding *)ascii {
    return [self systemEncoding:NSASCIIStringEncoding];
}

@end
