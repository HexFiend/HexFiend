//
//  MyDocumentController.m
//  HexFiend_2
//
//  Copyright 2010 ridiculous_fish. All rights reserved.
//

#import "MyDocumentController.h"
#import "BaseDataDocument.h"
#include <sys/stat.h>
#import "HFOpenAccessoryViewController.h"
#import "ExtendedAttributeDataDocument.h"

@interface MyDocumentController ()

@property HFOpenAccessoryViewController *openAccessoryController;

@end

@implementation MyDocumentController

- (void)noteNewRecentDocumentURL:(NSURL *)absoluteURL {
    /* Work around the fact that LS crashes trying to fetch icons for block and character devices.  Let's just prevent it for all files that aren't normal or directories, heck. */
    BOOL callSuper = YES;
    unsigned char path[PATH_MAX + 1];
    struct stat sb;
    if (absoluteURL && CFURLGetFileSystemRepresentation((CFURLRef)absoluteURL, YES, path, sizeof path) && 0 == stat((char *)path, &sb)) {
        if (! S_ISREG(sb.st_mode) && ! S_ISDIR(sb.st_mode)) {
            callSuper = NO;
        }
    }
    if (callSuper) {
        [super noteNewRecentDocumentURL:absoluteURL];
    }
}

- (BaseDataDocument *)transientDocumentToReplace {
    BaseDataDocument *result = nil;
    NSArray *documents = [self documents];
    if ([documents count] == 1) {
        BaseDataDocument *potentialResult = documents[0];
        if ([potentialResult respondsToSelector:@selector(isTransientAndCanBeReplaced)] && [potentialResult isTransientAndCanBeReplaced]) {
            result = potentialResult;
        }
    }
    return result;
}

- (void)displayDocument:(NSDocument *)doc {
    // Documents must be displayed on the main thread.
    if ([NSThread isMainThread]) {
        [doc makeWindowControllers];
        [doc showWindows];
    } else {
        [self performSelectorOnMainThread:_cmd withObject:doc waitUntilDone:YES];
    }
}

- (void)replaceTransientDocument:(NSArray *)documents {
    // Transient document must be replaced on the main thread, since it may undergo automatic display on the main thread.
    if ([NSThread isMainThread]) {
        BaseDataDocument *transientDoc = documents[0], *doc = documents[1];
        NSArray *controllersToTransfer = [[transientDoc windowControllers] copy];
        for(NSWindowController *controller in controllersToTransfer) {
            [doc addWindowController:controller];
            [transientDoc removeWindowController:controller];
            [doc adoptWindowController:controller fromTransientDocument:transientDoc];
        }
        [transientDoc close];
    } else {
        [self performSelectorOnMainThread:_cmd withObject:documents waitUntilDone:YES];
    }
}

- (void)openDocumentWithContentsOfURL:(NSURL *)url display:(BOOL)displayDocument completionHandler:(void (^)(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error))completionHandler {
    BaseDataDocument *transientDoc = [self transientDocumentToReplace];
    
    // Don't make NSDocumentController display the NSDocument it creates. Instead, do it later manually to ensure that the transient document has been replaced first.
    [super openDocumentWithContentsOfURL:url display:NO completionHandler:^(NSDocument *theDocument, BOOL theDocumentWasAlreadyOpen, NSError *theError) {
        if (theDocument) {
            if ([theDocument isKindOfClass:[BaseDataDocument class]] && transientDoc) {
                [transientDoc setTransient:NO];
                [self replaceTransientDocument:@[transientDoc, theDocument]];
            }
            if (displayDocument) [self displayDocument:theDocument];
        }
        completionHandler(theDocument, theDocumentWasAlreadyOpen, theError);
    }];
}

- (id)openUntitledDocumentAndDisplay:(BOOL)displayDocument error:(NSError **)outError {
    BaseDataDocument *doc = [super openUntitledDocumentAndDisplay:displayDocument error:outError];
    if ([doc respondsToSelector:@selector(setTransient:)]) {
        [doc setTransient:YES];
    }
    return doc;
}

- (void)beginOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)inTypes completionHandler:(void (^)(NSInteger result))completionHandler
{
    openPanel.treatsFilePackagesAsDirectories = YES;
    openPanel.showsHiddenFiles = YES;
    openPanel.resolvesAliases = [[NSUserDefaults standardUserDefaults] boolForKey:@"ResolveAliases"];
    if (!self.openAccessoryController) {
        self.openAccessoryController = [[HFOpenAccessoryViewController alloc] init];
    }
    openPanel.delegate = self.openAccessoryController;
    openPanel.accessoryView = self.openAccessoryController.view;
    openPanel.accessoryViewDisclosed = YES;
    [super beginOpenPanel:openPanel forTypes:inTypes completionHandler:completionHandler];
}

- (__kindof NSDocument *)makeDocumentWithContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError * _Nullable *)outError {
    NSString *attrName = self.openAccessoryController.extendedAttributeName;
    if (attrName) {
        ExtendedAttributeDataDocument *doc = [[ExtendedAttributeDataDocument alloc] initWithAttributeName:self.openAccessoryController.extendedAttributeName forURL:url];
        [self.openAccessoryController reset];
        return doc;
    }
    return [super makeDocumentWithContentsOfURL:url ofType:typeName error:outError];
}

@end
