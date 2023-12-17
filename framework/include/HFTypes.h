#include <Foundation/Foundation.h>

/*! @brief HFRange is the 64 bit analog of NSRange, containing a 64 bit location and length. */
typedef struct {
    unsigned long long location;
    unsigned long long length;
} HFRange;

/*! @brief HFFPRange is a struct used for representing floating point ranges, similar to NSRange.  It contains two long doubles.

  This is useful for (for example) showing the range of visible lines.  A double-precision value has 53 significant bits in the mantissa - so we would start to have precision problems at the high end of the range we can represent.  Long double has a 64 bit mantissa on Intel, which means that we would start to run into trouble at the very very end of our range - barely acceptable. */
typedef struct {
    long double location;
    long double length;
} HFFPRange;

#if TARGET_OS_IPHONE
#define HFColor UIColor
#define HFView UIView
#define HFFont UIFont
#else
#define HFColor NSColor
#define HFView NSView
#define HFFont NSFont
#endif

typedef NS_ENUM(NSInteger, HFControllerSelectAction) {
    eSelectResult,
    eSelectAfterResult,
    ePreserveSelection,
    NUM_SELECTION_ACTIONS
};
