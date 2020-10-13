#import <Foundation/Foundation.h>

#if ! NDEBUG
#define HFASSERT(a) assert(a)
#else
#define HFASSERT(a) if (0 && ! (a)) abort()
#endif

#define HFASSERT_MAIN_THREAD() HFASSERT(NSThread.currentThread.isMainThread)
