//
//  ProcessList.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "ProcessList.h"
#import "ProcessMemoryDocument.h"
#include <sys/sysctl.h>

@implementation ProcessList

static NSString *nameForProcessWithPID(pid_t pidNum)
{
    NSString *returnString = nil;
    int mib[4], maxarg = 0, numArgs = 0;
    size_t size = 0;
    char *args = NULL, *namePtr = NULL, *stringPtr = NULL;
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_ARGMAX;
    
    size = sizeof(maxarg);
    if ( sysctl(mib, 2, &maxarg, &size, NULL, 0) == -1 ) {
	return nil;
    }
    
    args = (char *)malloc( maxarg );
    if ( args == NULL ) {
	return nil;
    }
    
    mib[0] = CTL_KERN;
    mib[1] = KERN_PROCARGS2;
    mib[2] = pidNum;
    
    size = (size_t)maxarg;
    if ( sysctl(mib, 3, args, &size, NULL, 0) == -1 ) {
	free( args );
	return nil;
    }
    
    memcpy( &numArgs, args, sizeof(numArgs) );
    stringPtr = args + sizeof(numArgs);
    
    if ( (namePtr = strrchr(stringPtr, '/')) != NULL ) {
	returnString = [[NSString alloc] initWithUTF8String:namePtr + 1];
    } else {
	returnString = [[NSString alloc] initWithUTF8String:stringPtr];
    }
    
    free( args );
    return [returnString autorelease];
}

static int GetBSDProcessList(struct kinfo_proc **procList, size_t *procCount)
// Returns a list of all BSD processes on the system.  This routine
// allocates the list and puts it in *procList and a count of the
// number of entries in *procCount.  You are responsible for freeing
// this list (use "free" from System framework).
// On success, the function returns 0.
// On error, the function returns a BSD errno value.
{
    int                 err;
    struct kinfo_proc * result;
    bool                done;
    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;
    
    assert( procList != NULL);
    assert(*procList == NULL);
    assert(procCount != NULL);
    
    *procCount = 0;
    
    // We start by calling sysctl with result == NULL and length == 0.
    // That will succeed, and set length to the appropriate length.
    // We then allocate a buffer of that size and call sysctl again
    // with that buffer.  If that succeeds, we're done.  If that fails
    // with ENOMEM, we have to throw away our buffer and loop.  Note
    // that the loop causes use to call sysctl with NULL again; this
    // is necessary because the ENOMEM failure case sets length to
    // the amount of data returned, not the amount of data that
    // could have been returned.
    
    result = NULL;
    done = false;
    do {
        assert(result == NULL);
        
        // Call sysctl with a NULL buffer.
        
        length = 0;
        err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                     NULL, &length,
                     NULL, 0);
        if (err == -1) {
            err = errno;
        }
        
        // Allocate an appropriately sized buffer based on the results
        // from the previous call.
        
        if (err == 0) {
            result = malloc(length);
            if (result == NULL) {
                err = ENOMEM;
            }
        }
        
        // Call sysctl again with the new buffer.  If we get an ENOMEM
        // error, toss away our buffer and start again.
        
        if (err == 0) {
            err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
                         result, &length,
                         NULL, 0);
            if (err == -1) {
                err = errno;
            }
            if (err == 0) {
                done = true;
            } else if (err == ENOMEM) {
                assert(result != NULL);
                free(result);
                result = NULL;
                err = 0;
            }
        }
    } while (err == 0 && ! done);
    
    // Clean up and establish post conditions.
    
    if (err != 0 && result != NULL) {
        free(result);
        result = NULL;
    }
    *procList = result;
    if (err == 0) {
        *procCount = length / sizeof(struct kinfo_proc);
    }
    
    assert( (err == 0) == (*procList != NULL) );
    
    return err;
}

- (void)openProcessByPID:(pid_t)pid {
    ProcessMemoryDocument *doc = [[ProcessMemoryDocument alloc] init];
    [doc openProcessWithPID:pid];
    [[NSDocumentController sharedDocumentController] addDocument:doc];
    [doc makeWindowControllers];
    [doc showWindows];
    [doc release];
}

- (IBAction)openProcessByProcessMenuItem:(id)sender {
    USE(sender);
    pid_t pid = [[sender representedObject] intValue];
    HFASSERT(pid > 0);
    [self openProcessByPID:pid];
}

- (IBAction)openProcess:(id)sender {
    USE(sender);
}

static NSInteger compareMenuItems(id item1, id item2, void *unused) {
    USE(unused);
    return [[item1 title] caseInsensitiveCompare:[item2 title]];
}

/* Suppress key equivalents for our process list menu, since we are expensive to populate */
- (BOOL)menuHasKeyEquivalent:(NSMenu *)menu forEvent:(NSEvent*)event target:(id*)target action:(SEL*)action {
    USE(menu);
    USE(event);
    USE(target);
    USE(action);
    return NO;
}

- (void)populateProcessListMenu:(NSMenu *)menu {
    if ([menu respondsToSelector:@selector(removeAllItems)]) {
	[menu removeAllItems];
    }
    else {
	NSUInteger count = [menu numberOfItems];
	while (count--) [menu removeItemAtIndex:count];
    }
    struct kinfo_proc *procs = NULL;
    size_t procIndex, numProcs = -1;
    GetBSDProcessList(&procs, &numProcs);
    Class runningAppClass = NSClassFromString(@"NSRunningApplication");
    NSMutableArray *items = [NSMutableArray array];
    for (procIndex = 0; procIndex < numProcs; procIndex++) {
	pid_t pid = procs[procIndex].kp_proc.p_pid;
	NSString *name = nameForProcessWithPID(pid);
	if (name) {
	    NSString *title = [name stringByAppendingFormat:@" (%ld)", (long)pid];
	    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(openProcessByProcessMenuItem:) keyEquivalent:@""];
            [item setTarget:self];
	    [item setRepresentedObject:@(pid)];
	    NSImage *image = [[runningAppClass runningApplicationWithProcessIdentifier:pid] icon];
	    if (image) {
		NSImage *icon = [image copy];
		[icon setSize:NSMakeSize(16, 16)];
		[item setImage:icon];
		[icon release];
	    }
	    [items addObject:item];
	    [item release];
	}
    }
    free(procs);
    
    [items sortUsingFunction:compareMenuItems context:NULL];
    FOREACH(NSMenuItem *, item, items) {
	[menu addItem:item];
    }    
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    [self populateProcessListMenu:menu];
}

@end
