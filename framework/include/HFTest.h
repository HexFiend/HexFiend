//
//  HFTest.h
//  HexFiend_2
//
//  Created by Ryan Goulden on 10/2/14.
//  Copyright (c) 2014 ridiculous_fish. All rights reserved.
//

#ifdef HFUNIT_TESTS

#import <Foundation/Foundation.h>

typedef void (^HFRegisterTestFailure_b)(const char *file, NSUInteger line, NSString *expr, NSString *msg);

@interface NSObject (HFUnitTests)
+ (void)runHFUnitTests:(HFRegisterTestFailure_b)registerFailure;
@end

#define HFTEST(a, ...) if(!(a)) registerFailure(__FILE__, __LINE__, @#a, [NSString stringWithFormat: @"" __VA_ARGS__])

#if 0
#define dbg_printf(...) fprintf(stderr, __VA_ARGS__)
#else
#define dbg_printf(...) (void)0
#endif

#endif
