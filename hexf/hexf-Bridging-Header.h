//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "version.h"

#define HF_XSTRINGIFY(x) #x
#define HF_STRINGIFY(x) HF_XSTRINGIFY(x)

#import <Foundation/Foundation.h>

static inline NSString* HFVersion(void) {
    return [NSString stringWithUTF8String:HF_STRINGIFY(HEXFIEND_VERSION)];
}
