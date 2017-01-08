//
//  AppUtilities.h
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

@class NSString;

/* Parses an NSString into a quantity and a sign. The string may contain a suffix (e.g. KB). Returns YES if successful, NO if not. */
BOOL parseNumericStringWithSuffix(NSString *string, unsigned long long *resultValue, BOOL *isNegative);

/* Indicates if this app is currently sandboxed */
BOOL isSandboxed(void);
