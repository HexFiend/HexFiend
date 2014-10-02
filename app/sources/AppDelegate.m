//
//  AppDelegate.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "AppDelegate.h"
#import "BaseDataDocument.h"
#import "DiffDocument.h"
#import "MyDocumentController.h"
#import "DiffRangeWindowController.h"
#include <assert.h>
#include <errno.h>
#include <stdbool.h>
#include <stdlib.h>
#include <stdio.h>

@implementation AppDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)note {
    USE(note);
    /* Make sure our NSDocumentController subclass gets installed */
    [MyDocumentController sharedDocumentController];
}

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    USE(note);

    if (! [[NSUserDefaults standardUserDefaults] boolForKey:@"HFDebugMenu"]) {
        /* Remove the Debug menu unless we want it */
        NSMenu *mainMenu = [NSApp mainMenu];
        NSInteger index = [mainMenu indexOfItemWithTitle:@"Debug"];
        if (index != -1) [mainMenu removeItemAtIndex:index];
    }

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
    @autoreleasepool {
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
    [self performSelectorOnMainThread:@selector(receiveFonts:) withObject:fonts waitUntilDone:NO modes:@[NSDefaultRunLoopMode, NSEventTrackingRunLoopMode]];
    } // @autoreleasepool
    
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
        NSArray *docs = [DiffDocument getFrontTwoDocumentsForDiffing];
        if (docs) {
            NSString *firstTitle = [docs[0] displayName];
            NSString *secondTitle = [docs[1] displayName];
            [item setTitle:[NSString stringWithFormat:@"Compare \u201C%@\u201D and \u201C%@\u201D", firstTitle, secondTitle]];
            return YES;
        }
        else {
            /* Zero or one document, so give it a generic title and disable it */
            [item setTitle:@"Compare Front Documents"];
            return NO;
        }
    } else if (sel == @selector(diffFrontDocumentsByRange:)) {
        NSArray *docs = [DiffDocument getFrontTwoDocumentsForDiffing];
        if (docs) {
            NSString *firstTitle = [docs[0] displayName];
            NSString *secondTitle = [docs[1] displayName];
            [item setTitle:[NSString stringWithFormat:@"Compare Range of \u201C%@\u201D and \u201C%@\u201D", firstTitle, secondTitle]];
            return YES;
        }
        else {
            /* Zero or one document, so give it a generic title and disable it */
            [item setTitle:@"Compare Range of Front Documents"];
            return NO;
        }
    }
    return YES;
}

- (IBAction)diffFrontDocuments:(id)sender {
    USE(sender);
    [DiffDocument compareFrontTwoDocuments];
}

- (IBAction)diffFrontDocumentsByRange:(id)sender {
    USE(sender);
    DiffRangeWindowController* range = [[DiffRangeWindowController alloc] initWithWindowNibName:@"DiffRangeDialog"];
    [range showWindow:self];
    [range release];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == bookmarksMenu) {
        NSDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
        
        // Remove any old bookmark menu items
        if(bookmarksMenuItems) {
            FOREACH(NSMenuItem *, bm, bookmarksMenuItems) {
                [bookmarksMenu removeItem:bm];
            }
            [bookmarksMenuItems release];
            bookmarksMenuItems = nil;
        }
        
        if ([currentDocument respondsToSelector:@selector(copyBookmarksMenuItems)]) {
            bookmarksMenuItems = [currentDocument performSelector:@selector(copyBookmarksMenuItems)];
            if(bookmarksMenuItems) {
                NSInteger index = [bookmarksMenu indexOfItem:noBookmarksMenuItem];
                FOREACH(NSMenuItem *, bm, bookmarksMenuItems) {
                    [bookmarksMenu insertItem:bm atIndex:index++];
                }
            }
        }
    
        [noBookmarksMenuItem setHidden:bookmarksMenuItems && [bookmarksMenuItems count]];
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

- (void)setStringEncoding:(NSStringEncoding)encoding {
    [[NSUserDefaults standardUserDefaults] setInteger:encoding forKey:@"DefaultStringEncoding"];    
}

- (IBAction)setStringEncodingFromMenuItem:(NSMenuItem *)item {
    [self setStringEncoding:[item tag]];
}

@end
