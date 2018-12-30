/*
 * tcl.h --
 *
 *	This header file describes the externally-visible facilities of the
 *	Tcl interpreter.
 *
 * Copyright (c) 1987-1994 The Regents of the University of California.
 * Copyright (c) 1993-1996 Lucent Technologies.
 * Copyright (c) 1994-1998 Sun Microsystems, Inc.
 * Copyright (c) 1998-2000 by Scriptics Corporation.
 * Copyright (c) 2002 by Kevin B. Kenny.  All rights reserved.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#pragma once

#include <tcl.h>

/*
 * For C++ compilers, use extern "C"
 */

#ifdef __cplusplus
extern "C" {
#endif

/*
 * Macros used to cast between pointers and integers (e.g. when storing an int
 * in ClientData), on 64-bit architectures they avoid gcc warning about "cast
 * to/from pointer from/to integer of different size".
 */

#if !defined(INT2PTR) && !defined(PTR2INT)
#   if defined(HAVE_INTPTR_T) || defined(intptr_t)
#	define INT2PTR(p) ((void *)(intptr_t)(p))
#	define PTR2INT(p) ((int)(intptr_t)(p))
#   else
#	define INT2PTR(p) ((void *)(p))
#	define PTR2INT(p) ((int)(p))
#   endif
#endif
#if !defined(UINT2PTR) && !defined(PTR2UINT)
#   if defined(HAVE_UINTPTR_T) || defined(uintptr_t)
#	define UINT2PTR(p) ((void *)(uintptr_t)(p))
#	define PTR2UINT(p) ((unsigned int)(uintptr_t)(p))
#   else
#	define UINT2PTR(p) ((void *)(p))
#	define PTR2UINT(p) ((unsigned int)(p))
#   endif
#endif

/*
 *----------------------------------------------------------------------------
 * Definitions needed for Tcl_ParseArgvObj routines.
 * Based on tkArgv.c.
 * Modifications from the original are copyright (c) Sam Bromley 2006
 */

typedef struct {
    int type;			/* Indicates the option type; see below. */
    const char *keyStr;		/* The key string that flags the option in the
				 * argv array. */
    void *srcPtr;		/* Value to be used in setting dst; usage
				 * depends on type.*/
    void *dstPtr;		/* Address of value to be modified; usage
				 * depends on type.*/
    const char *helpStr;	/* Documentation message describing this
				 * option. */
    ClientData clientData;	/* Word to pass to function callbacks. */
} Tcl_ArgvInfo;

/*
 * Legal values for the type field of a Tcl_ArgInfo: see the user
 * documentation for details.
 */

#define TCL_ARGV_CONSTANT	15
#define TCL_ARGV_INT		16
#define TCL_ARGV_STRING		17
#define TCL_ARGV_REST		18
#define TCL_ARGV_FLOAT		19
#define TCL_ARGV_FUNC		20
#define TCL_ARGV_GENFUNC	21
#define TCL_ARGV_HELP		22
#define TCL_ARGV_END		23

/*
 * Types of callback functions for the TCL_ARGV_FUNC and TCL_ARGV_GENFUNC
 * argument types:
 */

typedef int (Tcl_ArgvFuncProc)(ClientData clientData, Tcl_Obj *objPtr,
	void *dstPtr);
typedef int (Tcl_ArgvGenFuncProc)(ClientData clientData, Tcl_Interp *interp,
	int objc, Tcl_Obj *const *objv, void *dstPtr);

/*
 * Shorthand for commonly used argTable entries.
 */

#define TCL_ARGV_AUTO_HELP \
    {TCL_ARGV_HELP,	"-help",	NULL,	NULL, \
	    "Print summary of command-line options and abort", NULL}
#define TCL_ARGV_AUTO_REST \
    {TCL_ARGV_REST,	"--",		NULL,	NULL, \
	    "Marks the end of the options", NULL}
#define TCL_ARGV_TABLE_END \
    {TCL_ARGV_END, NULL, NULL, NULL, NULL, NULL}

int
Tcl_ParseArgsObjv(
    Tcl_Interp *interp,		/* Place to store error message. */
    const Tcl_ArgvInfo *argTable,
				/* Array of option descriptions. */
    int *objcPtr,		/* Number of arguments in objv. Modified to
				 * hold # args left in objv at end. */
    Tcl_Obj *const *objv,	/* Array of arguments to be parsed. */
    Tcl_Obj ***remObjv)		/* Pointer to array of arguments that were not
				 * processed here. Should be NULL if no return
				 * of arguments is desired. */
;

/*
 * end block for C++
 */

#ifdef __cplusplus
}
#endif
