//
//  HFDocumentOperation.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/26/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "HFDocumentOperationView.h"
#import <HexFiend/HFProgressTracker.h>
#include <pthread.h>

static NSString *sNibName;

@implementation HFDocumentOperationView

+ viewWithNibNamed:(NSString *)name {
    NSString *path = [[NSBundle bundleForClass:self] pathForResource:name ofType:@"nib"];
    if (! path) [NSException raise:NSInvalidArgumentException format:@"Unable to find nib named %@", name];
    sNibName = [name copy];
    NSMutableArray *topLevelObjects = [NSMutableArray array];
    if (! [NSBundle loadNibFile:path externalNameTable:[NSDictionary dictionaryWithObjectsAndKeys:topLevelObjects, @"NSTopLevelObjects", nil] withZone:NULL]) {
        [NSException raise:NSInvalidArgumentException format:@"Unable to load nib at path %@", path];
    }
    [sNibName release];
    sNibName = nil;
    FOREACH(id, obj, topLevelObjects) {
        if ([obj isKindOfClass:[self class]]) return [obj autorelease];
    }
    [NSException raise:NSInvalidArgumentException format:@"Unable to find instance of class %@ in top level objects for nib %@", NSStringFromClass([self class]), path];
    return nil;
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if (! awokenFromNib) {
        if ([value isKindOfClass:[NSView class]]) {
            [views setObject:value forKey:key];
            return;
        }
    }
    [super setValue:value forKey:key];
}

- (void)awakeFromNib {
    awokenFromNib = YES;
    [super awakeFromNib];
}

- initWithFrame:(NSRect)frame {
    [super initWithFrame:frame];
    defaultSize = frame.size;
    nibName = [sNibName copy];
    views = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)dealloc {
    [views release];
    [nibName release];
    [super dealloc];
}

- viewNamed:(NSString *)name {
    NSView *view = [views objectForKey:name];
    if (! view) [NSException raise:NSInvalidArgumentException format:@"No view named %@ in nib %@", name, nibName];
    return view;
}

- (CGFloat)defaultHeight {
    return defaultSize.height;
}

- (BOOL)selectorIsSetMethod:(SEL)sel {
    BOOL result = NO;
    const char *selName = sel_getName(sel);
    size_t len = strlen(selName);
    if (len >= 5) {
        if (strncmp(selName, "set", 3) == 0 && isupper(selName[3])) {
            const char *first = strchr(selName, ':');
            const char *last = strrchr(selName, ':');
            if (first != NULL && first == last && first[1] == 0) {
                result = YES;
            }
        }
    }
    return result;
}

- (NSString *)viewNameFromSelector:(SEL)sel {
    HFASSERT([self selectorIsSetMethod:sel]);
    char *selName = strdup(3 + sel_getName(sel));
    if (! selName) [NSException raise:NSMallocException format:@"strup failed"];
    selName[0] = tolower(selName[0]);
    NSString *result = [[[NSString alloc] initWithBytesNoCopy:selName length:strlen(selName) - 1 encoding:NSMacOSRomanStringEncoding freeWhenDone:YES] autorelease];
    return result;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    SEL sel = [invocation selector];
    if ([self selectorIsSetMethod:sel]) {
        id view = nil;
        [invocation getArgument:&view atIndex:2];
        HFASSERT([view isKindOfClass:[NSView class]]);
        NSString *name = [self viewNameFromSelector:sel];
        [views setObject:view forKey:name];
    }
    else {
        [NSException raise:NSInvalidArgumentException format:@"Can't forward %@", invocation];
    }
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    if ([self selectorIsSetMethod:sel]) {
        return [super methodSignatureForSelector:@selector(setMenu:)]; //identical to our set method
    }
    return [super methodSignatureForSelector:sel];
}

- (BOOL)respondsToSelector:(SEL)sel {
    if ([self selectorIsSetMethod:sel]) return YES;
    return [super respondsToSelector:sel];
}

- (void)spinUntilFinished {
    HFASSERT([self operationIsRunning]);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:HFProgressTrackerDidFinishNotification object:tracker];
    [tracker endTrackingProgress];
    [[views objectForKey:@"cancelButton"] setHidden:YES];
    [[views objectForKey:@"progressIndicator"] setHidden:YES];
    void *result = nil;
    int pthreadErr = pthread_join(thread, &result);
    if (pthreadErr) [NSException raise:NSGenericException format:@"pthread_join returned %d", result];
    [target performSelector:endSelector withObject:result];
    [(id)result release];
    [target release];
    target = nil;
    [tracker release];
    tracker = nil;
    thread = NULL;
    [tracker release];
    tracker = nil;
    [self release];
}

- (void)didFinishNotification:(NSNotification *)note {
    USE(note);
    [self spinUntilFinished];
}

- (IBAction)cancelViewOperation:sender {
    USE(sender);
    if ([self operationIsRunning]) {
        [tracker requestCancel:self];
        [self spinUntilFinished];
    }
}

- (BOOL)operationIsRunning { return !! thread; }

- (id)beginThread {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    id result = [target performSelector:startSelector withObject:tracker];
    [result retain];
    [tracker noteFinished:self];
    [pool release];
    return result;
}

static void *startThread(void *self) {
    return [(id)self beginThread];
}

- (void)startOperationWithCallbacks:(struct HFDocumentOperationCallbacks)callbacks {
    HFASSERT(! [self operationIsRunning]);
    NSProgressIndicator *progressIndicator = [views objectForKey:@"progressIndicator"];
    startSelector = callbacks.startSelector;
    endSelector = callbacks.endSelector;
    target = [callbacks.target retain];
    tracker = [[HFProgressTracker alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didFinishNotification:) name:HFProgressTrackerDidFinishNotification object:tracker];
    [tracker setUserInfo:callbacks.userInfo];
    [progressIndicator setDoubleValue:0];
    
    [[views objectForKey:@"cancelButton"] setHidden:NO];
    [progressIndicator setHidden:NO];
    [tracker setProgressIndicator:progressIndicator];
    [tracker beginTrackingProgress];
    
    [self retain];
    int threadResult = pthread_create(&thread, NULL, startThread, self);
    if (threadResult != 0) [NSException raise:NSGenericException format:@"pthread_create returned error %d", threadResult];
}

- (HFProgressTracker *)progressTracker {
    return tracker;
}

@end
