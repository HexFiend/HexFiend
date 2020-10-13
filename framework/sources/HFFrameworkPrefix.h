//
// Prefix header for all source files of the 'HexFiend_2' target in the 'HexFiend_2' project
//

#import <TargetConditionals.h>
#ifdef __OBJC__
#if TARGET_OS_IPHONE
    #import <UIKit/UIKit.h>
#else
    #import <Cocoa/Cocoa.h>
#endif
    #import <HexFiend/HFTypes.h>
#endif

#define UNIMPLEMENTED_VOID() [NSException raise:NSGenericException \
                                         format:@"Message %@ sent to instance of class %@, "\
                                                @"which does not implement that method",\
                                                NSStringFromSelector(_cmd), [[self class] description]]

#define UNIMPLEMENTED() UNIMPLEMENTED_VOID(); return 0

/* Macro to "use" a variable to prevent unused variable warnings. */
#define USE(x) ((void)(x))

#define check_malloc(x) ({ size_t _count = (x); void *_result = malloc(_count); if(!_result) { fprintf(stderr, "Out of memory allocating %lu bytes\n", (unsigned long)_count); exit(EXIT_FAILURE); } _result; })
#define check_calloc(x) ({ size_t _count = (x); void *_result = calloc(_count, 1); if(!_result) { fprintf(stderr, "Out of memory allocating %lu bytes\n", (unsigned long)_count); exit(EXIT_FAILURE); } _result; })
#define check_realloc(p, x) ({ size_t _count = (x); void *_result = realloc((p), x); if(!_result) { fprintf(stderr, "Out of memory reallocating %lu bytes\n", (unsigned long)_count); exit(EXIT_FAILURE); } _result; })

#if ! NDEBUG
#define REQUIRE_NOT_NULL(a) do { \
	if ((a)==NULL) {\
		fprintf(stderr, "REQUIRE_NOT_NULL failed: NULL value for parameter " #a " on line %d in file %s\n", __LINE__, __FILE__);\
			abort();\
	}\
} while (0)

#define EXPECT_CLASS(e, c) do { \
	if (! [(e) isKindOfClass:[c class]]) {\
		fprintf(stderr, "EXPECT_CLASS failed: Expression " #e " is %s on line %d in file %s\n", (e) ? "(nil)" : [[e description] UTF8String], __LINE__, __FILE__);\
			abort();\
	}\
} while (0)

#else
#define REQUIRE_NOT_NULL(a) USE(a)
#define EXPECT_CLASS(e, c) USE(e)
#endif

#define NEW_ARRAY(type, name, number) \
    type name ## static_ [256];\
    bzero(name ## static_, sizeof(name ## static_));\
    type * name = ((number) <= 256 ? name ## static_ : check_calloc((number) * sizeof(type)))
    
#define FREE_ARRAY(name) \
    if (name != name ## static_) free(name)

// See "Can I create a C array of retained pointers under ARC?"
// https://developer.apple.com/library/content/releasenotes/ObjectiveC/RN-TransitioningToARC/Introduction/Introduction.html
#define DEFINE_OBJ_ARRAY(type, name) \
    __strong type * name
#define INIT_OBJ_ARRAY(type, number) \
    (__strong type *)check_calloc((number) * sizeof(type))
#define NEW_OBJ_ARRAY(type, name, number) \
    DEFINE_OBJ_ARRAY(type, name) = INIT_OBJ_ARRAY(type, number)
#define FREE_OBJ_ARRAY(name, number) \
    for (size_t __Free_Index = 0; __Free_Index < number; ++__Free_Index) { \
        name[__Free_Index] = nil; \
    } \
    free(name);
