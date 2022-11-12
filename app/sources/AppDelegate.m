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
#import <HexFiend/HFCustomEncoding.h>
#import <HexFiend/HFEncodingManager.h>

@interface AppDelegate ()

@property BOOL parsedCommandLineArgs;
@property NSArray *filesToOpen;
@property NSString *diffLeftFile;
@property NSString *diffRightFile;
@property NSData *dataToOpen;

@end

@implementation AppDelegate
{
    NSWindowController *_prefs;
}

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
    [extendForwardsItem setKeyEquivalentModifierMask:[extendForwardsItem keyEquivalentModifierMask] | NSEventModifierFlagShift];
    [extendBackwardsItem setKeyEquivalentModifierMask:[extendBackwardsItem keyEquivalentModifierMask] | NSEventModifierFlagShift];
    [extendForwardsItem setKeyEquivalent:@"]"];
    [extendBackwardsItem setKeyEquivalent:@"["];	
    [self buildEncodingMenu];
    [self buildByteGroupingMenu];

    [self processCommandLineArguments];

    NSDistributedNotificationCenter *ndc = [NSDistributedNotificationCenter defaultCenter];
    
    __weak typeof(self) weakSelf = self;

    [ndc addObserverForName:@"HFOpenFileNotification" object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        [NSApp activateIgnoringOtherApps:YES];
        NSDictionary *userInfo = notification.userInfo;
        NSArray *files = [userInfo objectForKey:@"files"];
        if ([files isKindOfClass:[NSArray class]]) {
            for (NSString *file in files) {
                if ([file isKindOfClass:[NSString class]]) {
                    [weakSelf openFile:file];
                }
            }
        }
    }];

    [ndc addObserverForName:@"HFDiffFilesNotification" object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        [NSApp activateIgnoringOtherApps:YES];
        NSDictionary *userInfo = notification.userInfo;
        NSArray *files = [userInfo objectForKey:@"files"];
        if ([files isKindOfClass:[NSArray class]] && files.count == 2) {
            NSString *file1 = [files objectAtIndex:0];
            NSString *file2 = [files objectAtIndex:1];
            if ([file1 isKindOfClass:[NSString class]] && [file2 isKindOfClass:[NSString class]]) {
                [weakSelf compareLeftFile:file1 againstRightFile:file2];
            }
        }
    }];

    [ndc addObserverForName:@"HFOpenDataNotification" object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        [NSApp activateIgnoringOtherApps:YES];
        NSDictionary *userInfo = notification.userInfo;
        NSData *data = [userInfo objectForKey:@"data"];
        [weakSelf openData:data];
    }];
}

- (void)buildEncodingMenu {
    NSStringEncoding defaultEncodings[] = {
        NSASCIIStringEncoding,
        NSMacOSRomanStringEncoding,
        NSISOLatin1StringEncoding,
        NSISOLatin2StringEncoding,
        NSUTF16LittleEndianStringEncoding,
        NSUTF16BigEndianStringEncoding,
    };
    HFEncodingManager *encodingManager = [HFEncodingManager shared];
    for (size_t i = 0; i < sizeof(defaultEncodings) / sizeof(defaultEncodings[0]); ++i) {
        NSStringEncoding encoding = defaultEncodings[i];
        HFNSStringEncoding *encodingObj = [encodingManager systemEncoding:encoding];
        HFASSERT(encodingObj != nil);
        NSString *title = encodingObj.name;
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(setStringEncodingFromMenuItem:) keyEquivalent:@""];
        item.representedObject = encodingObj;
        [stringEncodingMenu addItem:item];
    }
    
    NSString *encodingsFolder = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier] stringByAppendingPathComponent:@"Encodings"];
    NSArray<HFCustomEncoding *> *customEncodings = [encodingManager loadCustomEncodingsFromDirectory:encodingsFolder];
    if (customEncodings.count > 0) {
        [stringEncodingMenu addItem:[NSMenuItem separatorItem]];
        customEncodings = [customEncodings sortedArrayUsingSelector:@selector(compare:)];
        for (HFCustomEncoding *encoding in customEncodings) {
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:encoding.name action:@selector(setStringEncodingFromMenuItem:) keyEquivalent:@""];
            item.representedObject = encoding;
            [stringEncodingMenu addItem:item];
        }
    }
    
    [stringEncodingMenu addItem:[NSMenuItem separatorItem]];
    
    NSMenuItem *otherEncodingsItem = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Other…", "") action:@selector(showWindow:) keyEquivalent:@""];
    otherEncodingsItem.target = chooseStringEncoding;
    [stringEncodingMenu addItem:otherEncodingsItem];
}

- (void)buildByteGroupingMenu {
    NSInteger defaults[] = {0, 1, 2, 3, 4, 8, 16, 32};
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    for (size_t i = 0; i < sizeof(defaults) / sizeof(defaults[0]); i++) {
        [set addIndex:defaults[i]];
    }
    [set addIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@"BytesPerColumn"]];
    NSMenu *menu = [[NSMenu alloc] init];
    [set enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop __unused) {
        NSString *title = idx == 0 ? NSLocalizedString(@"None", "") : [NSString stringWithFormat:@"%ld", idx];
        NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title action:@selector(modifyByteGrouping:) keyEquivalent:@""];
        menuItem.tag = idx;
        menuItem.target = nil;
        [menu addItem:menuItem];
    }];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:NSLocalizedString(@"Custom…", "") action:@selector(customByteGrouping:) keyEquivalent:@""];
    byteGroupingMenuItem.submenu = menu;
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
    minimumRequiredCharacterSet = [minimumCharacterSetMutable copy];
    
    NSMutableSet *fontNames = [NSMutableSet setWithArray:[manager availableFontNamesWithTraits:NSFixedPitchFontMask]];
    [fontNames minusSet:[NSSet setWithArray:[manager availableFontNamesWithTraits:NSFixedPitchFontMask | NSBoldFontMask]]];
    [fontNames minusSet:[NSSet setWithArray:[manager availableFontNamesWithTraits:NSFixedPitchFontMask | NSItalicFontMask]]];
    NSMutableArray *fonts = [NSMutableArray arrayWithCapacity:[fontNames count]];
    for(NSString *fontName in fontNames) {
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
    NSUInteger indexOfItemToAdd = [menu indexOfItem:fontListPlaceholderMenuItem];
    [menu removeItem:fontListPlaceholderMenuItem];
    for(NSFont *font in fonts) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[font displayName] action:@selector(setFontFromMenuItem:) keyEquivalent:@""];
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
        };
        NSAttributedString *astr = [[NSAttributedString alloc] initWithString:[font displayName] attributes:attrs];
        [item setAttributedTitle:astr];
        [item setRepresentedObject:font];
        [item setTarget:self];
        [menu insertItem:item atIndex:indexOfItemToAdd++];
        /* Validate the menu item in case the menu is currently open, so it gets the right check */
        [self validateMenuItem:item];
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
            [item setTitle:NSLocalizedString(@"Compare Front Documents", "")];
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
            [item setTitle:NSLocalizedString(@"Compare Range of Front Documents", "")];
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
    DiffRangeWindowController *diffRangeWindowController = [[DiffRangeWindowController alloc] initWithWindowNibName:@"DiffRangeDialog"];
    [diffRangeWindowController runModal];
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == bookmarksMenu) {
        NSDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
        
        // Remove any old bookmark menu items
        if(bookmarksMenuItems) {
            for(NSMenuItem *bm in bookmarksMenuItems) {
                [bookmarksMenu removeItem:bm];
            }
            bookmarksMenuItems = nil;
        }
        
        if ([currentDocument respondsToSelector:@selector(copyBookmarksMenuItems)]) {
            bookmarksMenuItems = [(BaseDataDocument*)currentDocument copyBookmarksMenuItems];
            if(bookmarksMenuItems) {
                NSInteger index = [bookmarksMenu indexOfItem:noBookmarksMenuItem];
                for(NSMenuItem *bm in bookmarksMenuItems) {
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
        HFStringEncoding *selectedEncoding;
        BaseDataDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];
        if (currentDocument && [currentDocument isKindOfClass:[BaseDataDocument class]]) {
            selectedEncoding = [currentDocument stringEncoding];
        } else {
            selectedEncoding = self.defaultStringEncoding;
        }
        
        /* Now select that item */
        NSUInteger i, max = [menu numberOfItems];
        for (i=0; i < max; i++) {
            NSMenuItem *item = [menu itemAtIndex:i];
            [item setState:[selectedEncoding isEqual:item.representedObject] ? NSControlStateValueOn : NSControlStateValueOff];
        }
    }
    else {
        NSLog(@"Unknown menu in menuNeedsUpdate: %@", menu);
    }
}

- (HFStringEncoding *)defaultStringEncoding {
    HFEncodingManager *manager = [HFEncodingManager shared];
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultStringEncoding"];
    if ([obj isKindOfClass:[NSNumber class]]) {
        // Old format just stored encoding raw
        NSStringEncoding encoding = [(NSNumber *)obj integerValue];
        HFNSStringEncoding *encodingObj = [manager systemEncoding:encoding];
        if (encodingObj) {
            return encodingObj;
        } else {
            NSLog(@"Failed to find encoding object for %ld", encoding);
        }
    } else if ([obj isKindOfClass:[NSData class]]) {
        NSError *err = nil;
        HFStringEncoding *encodingObj = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSData class] fromData:obj error:&err];
        if ([encodingObj isKindOfClass:[HFCustomEncoding class]]) {
            return encodingObj;
        } else if ([encodingObj isKindOfClass:[HFNSStringEncoding class]]) {
            // we only encode the raw encoding in HFNSStringEncoding, so get the
            // object from the manager so we can use proper name and identifier
            HFNSStringEncoding *nsencoding = (HFNSStringEncoding *)encodingObj;
            encodingObj = [manager systemEncoding:nsencoding.encoding];
            if (encodingObj) {
                return encodingObj;
            } else {
                NSLog(@"Failed to find encoding object for %ld", nsencoding.encoding);
            }
        } else {
            NSLog(@"Invalid encoding object: %@", encodingObj);
        }
    }
    return manager.ascii;
}

- (void)setStringEncoding:(HFStringEncoding *)encoding {
    NSError *err = nil;
    [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:encoding requiringSecureCoding:NO error:&err] forKey:@"DefaultStringEncoding"];
}

- (IBAction)setStringEncodingFromMenuItem:(NSMenuItem *)item {
    HFStringEncoding *encoding = item.representedObject;
    HFASSERT([encoding isKindOfClass:[HFStringEncoding class]]);
    [self setStringEncoding:encoding];
}

- (IBAction)openPreferences:(id)sender {
    if (!_prefs) {
        _prefs = [[NSWindowController alloc] initWithWindowNibName:@"Preferences"];
    }
    [_prefs showWindow:sender];
}

- (void)parseCommandLineArguments {
    if (!self.parsedCommandLineArgs) {
        NSMutableArray *filesToOpen = [NSMutableArray array];
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        // first argument is process path
        if (args.count > 1 && (args.count - 1) % 2 == 0) {
            for (NSUInteger i = 1; i < args.count; i += 2) {
                NSString *arg = args[i];
                if ([arg isEqualToString:@"-HFOpenFile"]) {
                    [filesToOpen addObject:args[i + 1]];
                } else if ([arg isEqualToString:@"-HFDiffLeftFile"]) {
                    self.diffLeftFile = args[i + 1];
                } else if ([arg isEqualToString:@"-HFDiffRightFile"]) {
                    self.diffRightFile = args[i + 1];
                } else if ([arg isEqualToString:@"-HFOpenData"]) {
                    NSString *base64 = args[i + 1];
                    NSData *data = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
                    self.dataToOpen = data;
                }
            }
        }
        self.filesToOpen = filesToOpen;
        self.parsedCommandLineArgs = YES;
    }
}

- (void)processCommandLineArguments {
    [self parseCommandLineArguments];
    for (NSString *path in self.filesToOpen) {
        [self openFile:path];
    }
    if (self.diffLeftFile && self.diffRightFile) {
        [self compareLeftFile:self.diffLeftFile againstRightFile:self.diffRightFile];
    }
    if (self.dataToOpen) {
        [self openData:self.dataToOpen];
        self.dataToOpen = nil;
    }
}

- (void)openFile:(NSString *)path {
    NSURL *url = [NSURL fileURLWithPath:path];
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    if ([url checkResourceIsReachableAndReturnError:nil]) {
        // Open existing file
        [dc openDocumentWithContentsOfURL:url display:YES completionHandler:^(NSDocument * document __unused, BOOL documentWasAlreadyOpen __unused, NSError * error __unused) {
        }];
    } else {
        // Open new document for file
        NSDocument *doc = [dc openUntitledDocumentAndDisplay:YES error:nil];
        doc.fileURL = url;
    }
}

- (void)openData:(NSData *)data {
    NSDocumentController *dc = [NSDocumentController sharedDocumentController];
    BaseDataDocument *doc = nil;
    // Use transient document if available
    for (BaseDataDocument *d in dc.documents) {
        if (d.transient) {
            doc = d;
            break;
        }
    }
    // Otherwise make a new document
    if (!doc) {
        doc = [dc openUntitledDocumentAndDisplay:YES error:nil];
    }
    [doc insertData:data];
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication * __unused)sender {
    [self parseCommandLineArguments];
    return self.filesToOpen.count == 0 && (!self.diffLeftFile || !self.diffRightFile);
}

- (void)compareLeftFile:(NSString *)leftFile againstRightFile:(NSString *)rightFile {
    NSError *err = nil;
    HFByteArray *array1 = [BaseDataDocument byteArrayfromURL:[NSURL fileURLWithPath:leftFile] error:&err];
    HFByteArray *array2 = [BaseDataDocument byteArrayfromURL:[NSURL fileURLWithPath:rightFile] error:&err];
    if (array1 && array2) {
        [DiffDocument compareByteArray:array1
                      againstByteArray:array2
                            usingRange:HFRangeMake(0, 0)
                          leftFileName:[[leftFile lastPathComponent] stringByDeletingPathExtension]
                         rightFileName:[[rightFile lastPathComponent] stringByDeletingPathExtension]];
    }
}

@end

#if MacAppStore

// define a stubby proxy, to hide the Check For Updates menu item
// if Sparkle is not present
@interface SUUpdater : NSObject
@end

@implementation SUUpdater

- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if ([item action] == @selector(checkForUpdates:)) {
        [item setHidden:YES];
        return NO;
    }
    return YES;
}

- (IBAction)checkForUpdates:(id)sender {
    USE(sender);
}

@end

#endif
