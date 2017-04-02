//
//  ChooseStringEncodingWindowController.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#if !__has_feature(objc_arc)
#error ARC required
#endif

#import "ChooseStringEncodingWindowController.h"
#import "BaseDataDocument.h"
#import "AppDelegate.h"

@implementation ChooseStringEncodingWindowController

- (NSString *)windowNibName {
    return @"ChooseStringEncodingDialog";
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

static void addEncoding(NSString *name, CFStringEncoding value, NSMutableArray *localKeys, NSMutableArray *localValues, NSMutableSet *usedKeys) {
    NSStringEncoding cocoaEncoding = CFStringConvertEncodingToNSStringEncoding(value);
    if (cocoaEncoding == kCFStringEncodingInvalidId) {
        /* Unsupported! */
        return;
    }
    if (! [usedKeys containsObject:name]) {
        [usedKeys addObject:name];
        NSString *strippedName, *localizedName, *title;
        
        /* Strip off the common prefix */
        if ([name hasPrefix:@"kCFStringEncoding"]) {
            strippedName = [name substringFromIndex:strlen("kCFStringEncoding")];
        } else {
            strippedName = name;
        }
        
        /* Get the localized encoding name */
        localizedName = [NSString localizedNameOfStringEncoding:cocoaEncoding];
        
        /* Compute the title.  \u2014 is an em-dash. */
        if ([localizedName length] > 0) {
            title = [NSString stringWithFormat:@"%@ \u2014 %@", strippedName, localizedName];
        } else {
            title = strippedName;
        }
        
        [localKeys addObject:title];
        NSNumber *numberValue = [NSNumber numberWithInteger:cocoaEncoding];
        [localValues addObject:numberValue];
    }
}

- (void)populateStringEncodings {
    NSMutableArray *localKeys = [NSMutableArray array];
    NSMutableArray *localValues = [NSMutableArray array];
    NSMutableSet *usedKeys = [NSMutableSet set];
#define ENCODING(a) do { addEncoding( @ #a, (a), localKeys, localValues, usedKeys); } while (0)
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
    
    keysToEncodings = [[NSDictionary alloc] initWithObjects:localValues forKeys:localKeys];
    encodings = localKeys;
}

- (void)awakeFromNib {
    [self populateStringEncodings];
    [tableView reloadData];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)__unused tableView
{
    return encodings.count;
}

- (id)tableView:(NSTableView *)__unused tableView objectValueForTableColumn:(NSTableColumn *)__unused tableColumn row:(NSInteger)row
{
    return encodings[row];
}

- (void)tableViewSelectionDidChange:(NSNotification *)__unused notification
{
    NSInteger row = tableView.selectedRow;
    if (row == -1) {
        return;
    }
    NSNumber *selectedEncoding = keysToEncodings[encodings[row]];
    /* Tell the front document (if any) and the app delegate */
    NSStringEncoding encodingValue = [selectedEncoding integerValue];
    id document = [[NSDocumentController sharedDocumentController] currentDocument];
    if ([document respondsToSelector:@selector(setStringEncoding:)]) {
        [document setStringEncoding:encodingValue];
    }
    [(AppDelegate*)[NSApp delegate] setStringEncoding:encodingValue];
}

@end
