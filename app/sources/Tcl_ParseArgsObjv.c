/*
 * tclIndexObj.c --
 *
 *	This file implements objects of type "index". This object type is used
 *	to lookup a keyword in a table of valid values and cache the index of
 *	the matching entry. Also provides table-based argv/argc processing.
 *
 * Copyright (c) 1990-1994 The Regents of the University of California.
 * Copyright (c) 1997 Sun Microsystems, Inc.
 * Copyright (c) 2006 Sam Bromley.
 *
 * See the file "license.terms" for information on usage and redistribution of
 * this file, and for a DISCLAIMER OF ALL WARRANTIES.
 */

#import "Tcl_ParseArgsObjv.h"
#include <string.h>

/*
 * Prototypes for functions defined later in this file:
 */

static void		PrintUsage(Tcl_Interp *interp,
			    const Tcl_ArgvInfo *argTable);


/*
 *----------------------------------------------------------------------
 *
 * Tcl_ParseArgsObjv --
 *
 *	Process an objv array according to a table of expected command-line
 *	options. See the manual page for more details.
 *
 * Results:
 *	The return value is a standard Tcl return value. If an error occurs
 *	then an error message is left in the interp's result. Under normal
 *	conditions, both *objcPtr and *objv are modified to return the
 *	arguments that couldn't be processed here (they didn't match the
 *	option table, or followed an TCL_ARGV_REST argument).
 *
 * Side effects:
 *	Variables may be modified, or procedures may be called. It all depends
 *	on the arguments and their entries in argTable. See the user
 *	documentation for details.
 *
 *----------------------------------------------------------------------
 */

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
{
    Tcl_Obj **leftovers;	/* Array to write back to remObjv on
				 * successful exit. Will include the name of
				 * the command. */
    int nrem;			/* Size of leftovers.*/
    register const Tcl_ArgvInfo *infoPtr;
				/* Pointer to the current entry in the table
				 * of argument descriptions. */
    const Tcl_ArgvInfo *matchPtr;
				/* Descriptor that matches current argument */
    Tcl_Obj *curArg;		/* Current argument */
    const char *str = NULL;
    register char c;		/* Second character of current arg (used for
				 * quick check for matching; use 2nd char.
				 * because first char. will almost always be
				 * '-'). */
    int srcIndex;		/* Location from which to read next argument
				 * from objv. */
    int dstIndex;		/* Used to keep track of current arguments
				 * being processed, primarily for error
				 * reporting. */
    int objc;			/* # arguments in objv still to process. */
    int length;			/* Number of characters in current argument */

    if (remObjv != NULL) {
	/*
	 * Then we should copy the name of the command (0th argument). The
	 * upper bound on the number of elements is known, and (undocumented,
	 * but historically true) there should be a NULL argument after the
	 * last result. [Bug 3413857]
	 */

	nrem = 1;
	leftovers = ckalloc((1 + *objcPtr) * sizeof(Tcl_Obj *));
	leftovers[0] = objv[0];
    } else {
	nrem = 0;
	leftovers = NULL;
    }

    /*
     * OK, now start processing from the second element (1st argument).
     */

    srcIndex = dstIndex = 1;
    objc = *objcPtr-1;

    while (objc > 0) {
	curArg = objv[srcIndex];
	srcIndex++;
	objc--;
	str = Tcl_GetStringFromObj(curArg, &length);
	if (length > 0) {
	    c = str[1];
	} else {
	    c = 0;
	}

	/*
	 * Loop throught the argument descriptors searching for one with the
	 * matching key string. If found, leave a pointer to it in matchPtr.
	 */

	matchPtr = NULL;
	infoPtr = argTable;
	for (; infoPtr != NULL && infoPtr->type != TCL_ARGV_END ; infoPtr++) {
	    if (infoPtr->keyStr == NULL) {
		continue;
	    }
	    if ((infoPtr->keyStr[1] != c)
		    || (strncmp(infoPtr->keyStr, str, length) != 0)) {
		continue;
	    }
	    if (infoPtr->keyStr[length] == 0) {
		matchPtr = infoPtr;
		goto gotMatch;
	    }
	    if (matchPtr != NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"ambiguous option \"%s\"", str));
		goto error;
	    }
	    matchPtr = infoPtr;
	}
	if (matchPtr == NULL) {
	    /*
	     * Unrecognized argument. Just copy it down, unless the caller
	     * prefers an error to be registered.
	     */

	    if (remObjv == NULL) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"unrecognized argument \"%s\"", str));
		goto error;
	    }

	    dstIndex++;		/* This argument is now handled */
	    leftovers[nrem++] = curArg;
	    continue;
	}

	/*
	 * Take the appropriate action based on the option type
	 */

    gotMatch:
	infoPtr = matchPtr;
	switch (infoPtr->type) {
	case TCL_ARGV_CONSTANT:
	    *((int *) infoPtr->dstPtr) = PTR2INT(infoPtr->srcPtr);
	    break;
	case TCL_ARGV_INT:
	    if (objc == 0) {
		goto missingArg;
	    }
	    if (Tcl_GetIntFromObj(interp, objv[srcIndex],
		    (int *) infoPtr->dstPtr) == TCL_ERROR) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"expected integer argument for \"%s\" but got \"%s\"",
			infoPtr->keyStr, Tcl_GetString(objv[srcIndex])));
		goto error;
	    }
	    srcIndex++;
	    objc--;
	    break;
	case TCL_ARGV_STRING:
	    if (objc == 0) {
		goto missingArg;
	    }
	    *((const char **) infoPtr->dstPtr) =
		    Tcl_GetString(objv[srcIndex]);
	    srcIndex++;
	    objc--;
	    break;
	case TCL_ARGV_REST:
	    /*
	     * Only store the point where we got to if it's not to be written
	     * to NULL, so that TCL_ARGV_AUTO_REST works.
	     */

	    if (infoPtr->dstPtr != NULL) {
		*((int *) infoPtr->dstPtr) = dstIndex;
	    }
	    goto argsDone;
	case TCL_ARGV_FLOAT:
	    if (objc == 0) {
		goto missingArg;
	    }
	    if (Tcl_GetDoubleFromObj(interp, objv[srcIndex],
		    (double *) infoPtr->dstPtr) == TCL_ERROR) {
		Tcl_SetObjResult(interp, Tcl_ObjPrintf(
			"expected floating-point argument for \"%s\" but got \"%s\"",
			infoPtr->keyStr, Tcl_GetString(objv[srcIndex])));
		goto error;
	    }
	    srcIndex++;
	    objc--;
	    break;
	case TCL_ARGV_FUNC: {
	    Tcl_ArgvFuncProc *handlerProc = (Tcl_ArgvFuncProc *)
		    infoPtr->srcPtr;
	    Tcl_Obj *argObj;

	    if (objc == 0) {
		argObj = NULL;
	    } else {
		argObj = objv[srcIndex];
	    }
	    if (handlerProc(infoPtr->clientData, argObj, infoPtr->dstPtr)) {
		srcIndex++;
		objc--;
	    }
	    break;
	}
	case TCL_ARGV_GENFUNC: {
	    Tcl_ArgvGenFuncProc *handlerProc = (Tcl_ArgvGenFuncProc *)
		    infoPtr->srcPtr;

	    objc = handlerProc(infoPtr->clientData, interp, objc,
		    &objv[srcIndex], infoPtr->dstPtr);
	    if (objc < 0) {
		goto error;
	    }
	    break;
	}
	case TCL_ARGV_HELP:
	    PrintUsage(interp, argTable);
	    goto error;
	default:
	    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
		    "bad argument type %d in Tcl_ArgvInfo", infoPtr->type));
	    goto error;
	}
    }

    /*
     * If we broke out of the loop because of an OPT_REST argument, copy the
     * remaining arguments down. Note that there is always at least one
     * argument left over - the command name - so we always have a result if
     * our caller is willing to receive it. [Bug 3413857]
     */

  argsDone:
    if (remObjv == NULL) {
	/*
	 * Nothing to do.
	 */

	return TCL_OK;
    }

    if (objc > 0) {
	memcpy(leftovers+nrem, objv+srcIndex, objc*sizeof(Tcl_Obj *));
	nrem += objc;
    }
    leftovers[nrem] = NULL;
    *objcPtr = nrem++;
    *remObjv = ckrealloc(leftovers, nrem * sizeof(Tcl_Obj *));
    return TCL_OK;

    /*
     * Make sure to handle freeing any temporary space we've allocated on the
     * way to an error.
     */

  missingArg:
    Tcl_SetObjResult(interp, Tcl_ObjPrintf(
	    "\"%s\" option requires an additional argument", str));
  error:
    if (leftovers != NULL) {
	ckfree(leftovers);
    }
    return TCL_ERROR;
}

/*
 *----------------------------------------------------------------------
 *
 * PrintUsage --
 *
 *	Generate a help string describing command-line options.
 *
 * Results:
 *	The interp's result will be modified to hold a help string describing
 *	all the options in argTable.
 *
 * Side effects:
 *	None.
 *
 *----------------------------------------------------------------------
 */

static void
PrintUsage(
    Tcl_Interp *interp,		/* Place information in this interp's result
				 * area. */
    const Tcl_ArgvInfo *argTable)
				/* Array of command-specific argument
				 * descriptions. */
{
    register const Tcl_ArgvInfo *infoPtr;
    int width, numSpaces;
#define NUM_SPACES 20
    static const char spaces[] = "                    ";
    char tmp[TCL_DOUBLE_SPACE];
    Tcl_Obj *msg;

    /*
     * First, compute the width of the widest option key, so that we can make
     * everything line up.
     */

    width = 4;
    for (infoPtr = argTable; infoPtr->type != TCL_ARGV_END; infoPtr++) {
	int length;

	if (infoPtr->keyStr == NULL) {
	    continue;
	}
	length = strlen(infoPtr->keyStr);
	if (length > width) {
	    width = length;
	}
    }

    /*
     * Now add the option information, with pretty-printing.
     */

    msg = Tcl_NewStringObj("Command-specific options:", -1);
    for (infoPtr = argTable; infoPtr->type != TCL_ARGV_END; infoPtr++) {
	if ((infoPtr->type == TCL_ARGV_HELP) && (infoPtr->keyStr == NULL)) {
	    Tcl_AppendPrintfToObj(msg, "\n%s", infoPtr->helpStr);
	    continue;
	}
	Tcl_AppendPrintfToObj(msg, "\n %s:", infoPtr->keyStr);
	numSpaces = width + 1 - strlen(infoPtr->keyStr);
	while (numSpaces > 0) {
	    if (numSpaces >= NUM_SPACES) {
		Tcl_AppendToObj(msg, spaces, NUM_SPACES);
	    } else {
		Tcl_AppendToObj(msg, spaces, numSpaces);
	    }
	    numSpaces -= NUM_SPACES;
	}
	Tcl_AppendToObj(msg, infoPtr->helpStr, -1);
	switch (infoPtr->type) {
	case TCL_ARGV_INT:
	    Tcl_AppendPrintfToObj(msg, "\n\t\tDefault value: %d",
		    *((int *) infoPtr->dstPtr));
	    break;
	case TCL_ARGV_FLOAT:
	    Tcl_AppendPrintfToObj(msg, "\n\t\tDefault value: %g",
		    *((double *) infoPtr->dstPtr));
	    sprintf(tmp, "%g", *((double *) infoPtr->dstPtr));
	    break;
	case TCL_ARGV_STRING: {
	    char *string = *((char **) infoPtr->dstPtr);

	    if (string != NULL) {
		Tcl_AppendPrintfToObj(msg, "\n\t\tDefault value: \"%s\"",
			string);
	    }
	    break;
	}
	default:
	    break;
	}
    }
    Tcl_SetObjResult(interp, msg);
}

/*
 * Local Variables:
 * mode: c
 * c-basic-offset: 4
 * fill-column: 78
 * End:
 */
