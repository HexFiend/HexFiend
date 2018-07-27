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
    [extendForwardsItem setKeyEquivalentModifierMask:[extendForwardsItem keyEquivalentModifierMask] | NSShiftKeyMask];
    [extendBackwardsItem setKeyEquivalentModifierMask:[extendBackwardsItem keyEquivalentModifierMask] | NSShiftKeyMask];
    [extendForwardsItem setKeyEquivalent:@"]"];
    [extendBackwardsItem setKeyEquivalent:@"["];	
    [self buildEncodingMenu];

    [self processCommandLineArguments];

    NSDistributedNotificationCenter *ndc = [NSDistributedNotificationCenter defaultCenter];
    
    [ndc addObserverForName:@"HFOpenFileNotification" object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        [NSApp activateIgnoringOtherApps:YES];
        NSDictionary *userInfo = notification.userInfo;
        NSArray *files = [userInfo objectForKey:@"files"];
        if ([files isKindOfClass:[NSArray class]]) {
            for (NSString *file in files) {
                if ([file isKindOfClass:[NSString class]]) {
                    [self openFile:file];
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
                [self compareLeftFile:file1 againstRightFile:file2];
            }
        }
    }];

    [ndc addObserverForName:@"HFOpenDataNotification" object:nil queue:nil usingBlock:^(NSNotification * _Nonnull notification) {
        [NSApp activateIgnoringOtherApps:YES];
        NSDictionary *userInfo = notification.userInfo;
        NSData *data = [userInfo objectForKey:@"data"];
        [self openData:data];
    }];
}

- (void)buildEncodingMenu {
    NSArray<NSDictionary *> *encodings = @[
        @{
              @"value" : @(NSASCIIStringEncoding),
              @"title" : NSLocalizedString(@"ASCII (strict 7 bit)", ""),
        },
        @{
              @"value" : @(NSMacOSRomanStringEncoding),
              @"title" : NSLocalizedString(@"MacRoman", ""),
        },
        @{
              @"value" : @(NSISOLatin1StringEncoding),
              @"title" : NSLocalizedString(@"ISO Latin-1 (Western Europe)", ""),
        },
        @{
              @"value" : @(NSISOLatin2StringEncoding),
              @"title" : NSLocalizedString(@"ISO Latin-2 (Eastern Europe)", ""),
        },
        @{
              @"value" : @(NSUTF16LittleEndianStringEncoding),
              @"title" : NSLocalizedString(@"UTF-16 Little (0xFFFE)", ""),
        },
        @{
              @"value" : @(NSUTF16BigEndianStringEncoding),
              @"title" : NSLocalizedString(@"UTF-16 Big (0xFEFF)", ""),
        },
    ];
    for (NSDictionary *dict in encodings) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:dict[@"title"] action:@selector(setStringEncodingFromMenuItem:) keyEquivalent:@""];
        item.representedObject = [[HFNSStringEncoding alloc] initWithEncoding:[(NSNumber *)dict[@"value"] integerValue]];
        [stringEncodingMenu addItem:item];
    }
    
    NSString *encodingsFolder = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier] stringByAppendingPathComponent:@"Encodings"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray<HFCustomEncoding *> *customEncodings = [NSMutableArray array];
    for (NSString *filename in [fm enumeratorAtPath:encodingsFolder]) {
        if ([filename.pathExtension isEqualToString:@"json"]) {
            NSString *path = [encodingsFolder stringByAppendingPathComponent:filename];
            HFCustomEncoding *encoding = [[HFCustomEncoding alloc] initWithPath:path];
            if (!encoding) {
                NSLog(@"Error with file %@", path);
                continue;
            }
            [customEncodings addObject:encoding];
        }
    }
    if (customEncodings.count > 0) {
        [stringEncodingMenu addItem:[NSMenuItem separatorItem]];
        [customEncodings sortUsingSelector:@selector(compare:)];
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
    [menu removeItemAtIndex:0];
    NSUInteger itemIndex = 0;
    for(NSFont *font in fonts) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[font displayName] action:@selector(setFontFromMenuItem:) keyEquivalent:@""];
        NSDictionary *attrs = @{
            NSFontAttributeName: font,
        };
        NSAttributedString *astr = [[NSAttributedString alloc] initWithString:[font displayName] attributes:attrs];
        [item setAttributedTitle:astr];
        [item setRepresentedObject:font];
        [item setTarget:self];
        [menu insertItem:item atIndex:itemIndex++];
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
    DiffRangeWindowController* range = [[DiffRangeWindowController alloc] initWithWindowNibName:@"DiffRangeDialog"];
    [range showWindow:self];
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
            [item setState:[selectedEncoding isEqual:item.representedObject] ? NSOnState : NSOffState];
        }
    }
    else {
        NSLog(@"Unknown menu in menuNeedsUpdate: %@", menu);
    }
}

- (HFStringEncoding *)defaultStringEncoding {
    id obj = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultStringEncoding"];
    if ([obj isKindOfClass:[NSNumber class]]) {
        // Old format just stored encoding raw
        NSStringEncoding encoding = [(NSNumber *)obj integerValue];
        return [[HFNSStringEncoding alloc] initWithEncoding:encoding];
    } else if ([obj isKindOfClass:[NSData class]]) {
        HFStringEncoding *encoding = [NSKeyedUnarchiver unarchiveObjectWithData:obj];
        if ([encoding isKindOfClass:[HFStringEncoding class]]) {
            return encoding;
        } else {
            NSLog(@"Invalid encoding object: %@", encoding);
        }
    }
    return [HFNSStringEncoding ascii];
}

- (void)setStringEncoding:(HFStringEncoding *)encoding {
    [[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:encoding] forKey:@"DefaultStringEncoding"];
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
                    NSData *data = nil;
                    if (@available(macOS 10.9, *)) {
                        data = [[NSData alloc] initWithBase64EncodedString:base64 options:0];
                    } else {
                        NSLog(@"Feature not available on 10.8");
                    }
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
