#import <Cocoa/Cocoa.h>

@class HFController;

static inline BOOL HFIsRunningOnLeopardOrLater(void) {
    return NSAppKitVersionNumber >= 860.;
}

/* Returns the first index where the strings differ.  If the strings do not differ in any characters but are of different lengths, returns the smaller length; if they are the same length and do not differ, returns NSUIntegerMax */
static inline NSUInteger HFIndexOfFirstByteThatDiffers(const unsigned char *a, NSUInteger len1, const unsigned char *b, NSUInteger len2) {
    NSUInteger endIndex = MIN(len1, len2);
    for (NSUInteger i = 0; i < endIndex; i++) {
        if (a[i] != b[i]) return i;
    }
    if (len1 != len2) return endIndex;
    return NSUIntegerMax;
}

static inline unsigned long long llmin(unsigned long long a, unsigned long long b) {
    return a < b ? a : b;
}

__private_extern__ NSImage *HFImageNamed(NSString *name);

/* Returns an NSData from an NSString containing hexadecimal characters.  Characters that are not hexadecimal digits are silently skipped.  Returns by reference whether the last byte contains only one nybble, in which case it will be returned in the low 4 bits of the last byte. */
__private_extern__ NSData *HFDataFromHexString(NSString *string, BOOL* isMissingLastNybble);

__private_extern__ NSString *HFHexStringFromData(NSData *data);

/* Modifies F_NOCACHE for a given file descriptor */
__private_extern__ void HFSetFDShouldCache(int fd, BOOL shouldCache);
