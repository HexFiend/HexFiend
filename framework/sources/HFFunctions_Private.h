#import <Cocoa/Cocoa.h>

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
