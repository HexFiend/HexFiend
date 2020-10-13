//
//  AppUtilities.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <HexFiend/HexFiend.h>

static BOOL parseSuffixMultiplier(const char *multiplier, unsigned long long *multiplierResultValue) {
    NSCParameterAssert(multiplier != NULL);
    NSCParameterAssert(multiplierResultValue != NULL);
    /* Allow spaces at the beginning and end */
    while (multiplier[0] == ' ') multiplier++;
    size_t length = strlen(multiplier);
    while (length > 0 && multiplier[length-1] == ' ') length--;
    /* Allow an optional trailing b or B (e.g. MB or M) */
    if (length > 0 && strchr("bB", multiplier[length-1]) != NULL) length--;
    
    /* If this exhausted our string, return success, e.g. so that the user can type "5 b" and it will return a multiplier of 1 */
    if (length == 0) {
        *multiplierResultValue = 1;
        return YES;
    }
    
    /* Now check each SI suffix */
    const char * const decimalSuffixes[] = {"k", "m", "g", "t", "p", "e", "z", "y"};
    const char * const binarySuffixes[] = {"ki", "mi", "gi", "ti", "pi", "ei", "zi", "yi"};
    NSUInteger i;
    unsigned long long suffixMultiplier = 1;
    BOOL suffixMultiplierDidOverflow = NO;
    for (i=0; i < sizeof decimalSuffixes / sizeof *decimalSuffixes; i++) {
        unsigned long long product = suffixMultiplier * 1000;
        suffixMultiplierDidOverflow = suffixMultiplierDidOverflow || (product/1000 != suffixMultiplier);
        suffixMultiplier = product;
        if (! strncasecmp(multiplier, decimalSuffixes[i], length)) {
            if (suffixMultiplierDidOverflow) suffixMultiplier = ULLONG_MAX;
            *multiplierResultValue = suffixMultiplier;
            return ! suffixMultiplierDidOverflow;
        }
    }
    suffixMultiplier = 1;
    suffixMultiplierDidOverflow = NO;
    for (i=0; i < sizeof binarySuffixes / sizeof *binarySuffixes; i++) {
        unsigned long long product = suffixMultiplier * 1024;
        suffixMultiplierDidOverflow = suffixMultiplierDidOverflow || (product/1024 != suffixMultiplier);
        suffixMultiplier = product;
        if (! strncasecmp(multiplier, binarySuffixes[i], length)) {
            if (suffixMultiplierDidOverflow) suffixMultiplier = ULLONG_MAX;
            *multiplierResultValue = suffixMultiplier;
            return ! suffixMultiplierDidOverflow;
        }
    }
    return NO;
}

BOOL parseNumericStringWithSuffix(NSString *stringValue, unsigned long long *resultValue, BOOL *isNegative) {
    const char *string = [stringValue UTF8String];
    if (string == NULL) goto invalidString;
    /* Parse the string with strtoull */
    unsigned long long amount = -1;
    unsigned long long suffixMultiplier = 1;
    int err = 0;
    BOOL isNeg = NO;
    char *endPtr = NULL;
    for (;;) {
        while (isspace(*string)) string++;
        if (*string == '-') {
            if (isNeg) goto invalidString;
            isNeg = YES;
            string++;
        }
        else {
            break;
        }
    }
    errno = 0;
    amount = strtoull(string, &endPtr, 0);
    err = errno;
    if (err != 0 || endPtr == NULL) goto invalidString;
    if (*endPtr != '\0' && ! parseSuffixMultiplier(endPtr, &suffixMultiplier)) goto invalidString;
    
    if (! HFProductDoesNotOverflow(amount, suffixMultiplier)) goto invalidString;
    amount *= suffixMultiplier;
    
    *resultValue = amount;
    if(isNegative) *isNegative = isNeg;
    return YES;
invalidString:;
    return NO;
}

BOOL isSandboxed(void) {
#if MacAppStore
    return YES;
#else
    return NO;
#endif
}
