//
//  AppDelegate.m
//  HexFiend_2
//
//  Created by Peter Ammon on 4/1/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "AppDelegate.h"
#import "BaseDataDocument.h"
#import "ProcessMemoryDocument.h"
#import "DiffDocument.h"
#import "MyDocumentController.h"
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/sysctl.h>

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)note {
    USE(note);
    /* Make sure our NSDocumentController subclass gets installed */
    [MyDocumentController sharedDocumentController];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    USE(note);
#if NDEBUG
    /* Remove the Debug menu unless we want it */
    NSMenu *mainMenu = [NSApp mainMenu];
    NSInteger index = [mainMenu indexOfItemWithTitle:@"Debug"];
    if (index != -1) [mainMenu removeItemAtIndex:index];
#endif
    [NSThread detachNewThreadSelector:@selector(buildFontMenu:) toTarget:self withObject:nil];
    [extendForwardsItem setKeyEquivalentModifierMask:[extendForwardsItem keyEquivalentModifierMask] | NSShiftKeyMask];
    [extendBackwardsItem setKeyEquivalentModifierMask:[extendBackwardsItem keyEquivalentModifierMask] | NSShiftKeyMask];
    [extendForwardsItem setKeyEquivalent:@"]"];
    [extendBackwardsItem setKeyEquivalent:@"["];
}

static NSComparisonResult compareFontDisplayNames(NSFont *a, NSFont *b, void *unused) {
    USE(unused);
    return [[a displayName] caseInsensitiveCompare:[b displayName]];
}

- (void)buildFontMenu:unused {
    USE(unused);
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSFontManager *manager = [NSFontManager sharedFontManager];
    NSCharacterSet *minimumRequiredCharacterSet;
    NSMutableCharacterSet *minimumCharacterSetMutable = [[NSMutableCharacterSet alloc] init];
    [minimumCharacterSetMutable addCharactersInRange:NSMakeRange('0', 10)];
    [minimumCharacterSetMutable addCharactersInRange:NSMakeRange('a', 26)];
    [minimumCharacterSetMutable addCharactersInRange:NSMakeRange('A', 26)];
    minimumRequiredCharacterSet = [[minimumCharacterSetMutable copy] autorelease];
    [minimumCharacterSetMutable release];
    
    NSMutableSet *fontNames = [NSMutableSet setWithArray:[manager availableFontNamesWithTraits:NSFixedPitchFontMask]];
    [fontNames minusSet:[NSSet setWithArray:[manager availableFontNamesWithTraits:NSFixedPitchFontMask | NSBoldFontMask]]];
    [fontNames minusSet:[NSSet setWithArray:[manager availableFontNamesWithTraits:NSFixedPitchFontMask | NSItalicFontMask]]];
    NSMutableArray *fonts = [NSMutableArray arrayWithCapacity:[fontNames count]];
    FOREACH(NSString *, fontName, fontNames) {
        NSFont *font = [NSFont fontWithName:fontName size:0];
        NSString *displayName = [font displayName];
        if (! [displayName length]) continue;
        unichar firstChar = [displayName characterAtIndex:0];
        if (firstChar == '#' || firstChar == '.') continue;
        if (! [[font coveredCharacterSet] isSupersetOfSet:minimumRequiredCharacterSet]) continue; //weed out some useless fonts, like Monotype Sorts
        [fonts addObject:font];
    }
    [fonts sortUsingFunction:compareFontDisplayNames context:NULL];
    [self performSelectorOnMainThread:@selector(receiveFonts:) withObject:fonts waitUntilDone:NO modes:[NSArray arrayWithObjects:NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, nil]];
    [pool drain];
}

- (void)receiveFonts:(NSArray *)fonts {
    NSMenu *menu = [fontMenuItem submenu];
    [menu removeItemAtIndex:0];
    NSUInteger itemIndex = 0;
    FOREACH(NSFont *, font, fonts) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[font displayName] action:@selector(setFontFromMenuItem:) keyEquivalent:@""];
        [item setRepresentedObject:font];
        [item setTarget:self];
        [menu insertItem:item atIndex:itemIndex++];
        /* Validate the menu item in case the menu is currently open, so it gets the right check */
        [self validateMenuItem:item];
        [item release];
    }
}

- (void)setFontFromMenuItem:(NSMenuItem *)item {
    NSFont *font = [item representedObject];
    HFASSERT([font isKindOfClass:[NSFont class]]);
    BaseDataDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
    NSFont *documentFont = [document font];
    font = [[NSFontManager sharedFontManager] convertFont: font toSize: [documentFont pointSize]];
    [document setFont:font registeringUndo:YES];
}

/* Returns either nil, or an array of two documents that would be compared in the "Compare Front Documents" menu item. */
- (NSArray *)documentsForDiffing {
    id resultDocs[2];
    NSUInteger i = 0;
    FOREACH(NSDocument *, doc, [NSApp orderedDocuments]) {
        if ([doc isKindOfClass:[BaseDataDocument class]] && ! [doc isKindOfClass:[DiffDocument class]]) {
            resultDocs[i++] = doc;
            if (i == 2) break;
        }
    }
    if (i == 2) {
        return [NSArray arrayWithObjects:resultDocs count:2];
    }
    else {
        return nil;
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    SEL sel = [item action];
    if (sel == @selector(setFontFromMenuItem:)) {
        BaseDataDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
        BOOL check = NO;
        if (document) {
            NSFont *font = [document font];
            check = [[item title] isEqualToString:[font displayName]];
        }
        [item setState:check];
        return document != nil;
    }
    else if (sel == @selector(diffFrontDocuments:)) {
        NSArray *docs = [self documentsForDiffing];
        if (docs) {
            NSString *firstTitle = [[docs objectAtIndex:0] displayName];
            NSString *secondTitle = [[docs objectAtIndex:1] displayName];
            [item setTitle:[NSString stringWithFormat:@"Compare \u201C%@\u201D and \u201C%@\u201D", firstTitle, secondTitle]];
            return YES;
        }
        else {
            /* Zero or one document, so give it a generic title and disable it */
            [item setTitle:@"Compare Front Documents"];
            return NO;
        }
    }
    return YES;
}

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

- (IBAction)diffFrontDocuments:(id)sender {
    USE(sender);
    NSArray *docs = [self documentsForDiffing];
    if (! docs) return; //the menu item would be disabled in this case
    HFByteArray *left = [[docs objectAtIndex:0] byteArray];
    HFByteArray *right = [[docs objectAtIndex:1] byteArray];
    DiffDocument *doc = [[DiffDocument alloc] initWithLeftByteArray:left rightByteArray:right];
    [doc setLeftFileName:[[docs objectAtIndex:0] displayName]];
    [doc setRightFileName:[[docs objectAtIndex:1] displayName]];
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

static NSInteger compareMenuItems(id item1, id item2, void *unused) {
    USE(unused);
    return [[item1 title] caseInsensitiveCompare:[item2 title]];
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
	    [item setRepresentedObject:[NSNumber numberWithLong:pid]];
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
    [items sortUsingFunction:compareMenuItems context:NULL];
    FOREACH(NSMenuItem *, item, items) {
	[menu addItem:item];
    }    
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == [processListMenuItem submenu]) {
	[self populateProcessListMenu:menu];
    }
    else if (menu == bookmarksMenu) {
	NSDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
	if ([currentDocument respondsToSelector:@selector(populateBookmarksMenu:)]) {
	    [(BaseDataDocument *)currentDocument populateBookmarksMenu:menu];
	}
	else {
	    /* Nil document, or unknown type.  Remove all menu items except the first one. */
	    NSUInteger itemCount = [bookmarksMenu numberOfItems];
	    while (itemCount > 1) {
		[bookmarksMenu removeItemAtIndex:--itemCount];
	    }
	}
    }
    else if (menu == [fontMenuItem submenu]) {
        /* Nothing to do */
    }
    else if (menu == stringEncodingMenu) {
        /* Check the menu item whose string encoding corresponds to the key document, or if none do, select the default. */
        NSInteger selectedEncoding;
	BaseDataDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
	if (currentDocument && [currentDocument isKindOfClass:[BaseDataDocument class]]) {
	    selectedEncoding = [currentDocument stringEncoding];
	} else {
            selectedEncoding = [[NSUserDefaults standardUserDefaults] integerForKey:@"DefaultStringEncoding"];
        }
        
        /* Now select that item */
        NSUInteger i, max = [menu numberOfItems];
        for (i=0; i < max; i++) {
            NSMenuItem *item = [menu itemAtIndex:i];
            [item setState:[item tag] == selectedEncoding];
        }
    }
    else {
        NSLog(@"Unknown menu in menuNeedsUpdate: %@", menu);
    }
}

- (IBAction)setStringEncodingFromMenuItem:(NSMenuItem *)item {
    [[NSUserDefaults standardUserDefaults] setInteger:[item tag] forKey:@"DefaultStringEncoding"];
}

- (IBAction)openProcess:(id)sender {
    USE(sender);
}

@end
