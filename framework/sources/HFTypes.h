/* Hide this compatibility junk from Doxygen */
#ifndef DOXYGEN_ONLY

#ifndef NSINTEGER_DEFINED
#if __LP64__ || NS_BUILD_32_LIKE_64
typedef long NSInteger;
typedef unsigned long NSUInteger;
#else
typedef int NSInteger;
typedef unsigned int NSUInteger;
#endif
#define NSIntegerMax    LONG_MAX
#define NSIntegerMin    LONG_MIN
#define NSUIntegerMax   ULONG_MAX
#define NSINTEGER_DEFINED 1
#endif

#ifndef CGFLOAT_DEFINED
#if defined(__LP64__) && __LP64__
typedef double CGFloat;
#define CGFLOAT_MIN DBL_MIN
#define CGFLOAT_MAX DBL_MAX
#define CGFLOAT_IS_DOUBLE 1
#else	/* !defined(__LP64__) || !__LP64__ */
typedef float CGFloat;
#define CGFLOAT_MIN FLT_MIN
#define CGFLOAT_MAX FLT_MAX
#define CGFLOAT_IS_DOUBLE 0
#endif	/* !defined(__LP64__) || !__LP64__ */
#define CGFLOAT_DEFINED 1
#endif

#endif

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
