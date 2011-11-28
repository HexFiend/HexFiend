//
//  HFDocumentOperation.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/26/08.
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFDocumentOperationView.h"
#import <HexFiend/HFProgressTracker.h>
#include <pthread.h>
#include <objc/message.h>

static NSString *sNibName;

#define NO_TRACKING_PERCENTAGE (-1)

@interface HFDocumentOperationView (PrivateStuff)
- (id)beginThread NS_RETURNS_RETAINED;
@end

@implementation HFDocumentOperationView

+ viewWithNibNamed:(NSString *)name owner:(id)owner {
    NSString *path = [[NSBundle bundleForClass:self] pathForResource:name ofType:@"nib"];
    if (! path) [NSException raise:NSInvalidArgumentException format:@"Unable to find nib named %@", name];
    sNibName = [name copy];
    NSMutableArray *topLevelObjects = [NSMutableArray array];
    if (! [NSBundle loadNibFile:path externalNameTable:[NSDictionary dictionaryWithObjectsAndKeys:topLevelObjects, @"NSTopLevelObjects", owner, @"NSOwner", nil] withZone:NULL]) {
        [NSException raise:NSInvalidArgumentException format:@"Unable to load nib at path %@", path];
    }
    [sNibName release];
    sNibName = nil;
    HFDocumentOperationView *resultObject = nil;
    NSMutableArray *otherObjects = nil;
    FOREACH(id, obj, topLevelObjects) {
        if ([obj isKindOfClass:[self class]]) {
            HFASSERT(resultObject == nil);
            resultObject = obj;
        }
        else {
            if (! otherObjects) otherObjects = [NSMutableArray array];
            [otherObjects addObject:obj];
        }
	/* Balance the retain acquired by virtue of being a top level object in a nib.  Call objc_msgSend directly so that the static analyzer can't see it, because the static analyzer doesn't know about top level objects from nibs. */
	objc_msgSend(obj, @selector(autorelease));
    }
    HFASSERT(resultObject != nil);
    if (otherObjects != nil) [resultObject setOtherTopLevelObjects:otherObjects];
    
    /* This object is NOT sent autorelease too many times, no matter what the analyzer says, because it has an extra retain by virtue of being a nib top level object. */
    return resultObject;
}

- (void)setOtherTopLevelObjects:(NSArray *)objects {
    objects = [objects copy];
    [otherTopLevelObjects release];
    otherTopLevelObjects = objects;
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

- (NSString *)displayName {
    return displayName;
}

- (void)setDisplayName:(NSString *)name {
    name = [name copy];
    [displayName release];
    displayName = name;
}


- initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    defaultSize = frame.size;
    nibName = [sNibName copy];
    views = [[NSMutableDictionary alloc] init];
    progress = NO_TRACKING_PERCENTAGE;
    return self;
}

- (void)dealloc {
    [otherTopLevelObjects release];
    [views release];
    [nibName release];
    [displayName release];
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

- (void)setIsFixedHeight:(BOOL)val {
    isFixedHeight = val;
}

- (BOOL)isFixedHeight {
    return isFixedHeight;
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
    if (! selName) [NSException raise:NSMallocException format:@"strdup failed"];
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
    if (! awokenFromNib && [self selectorIsSetMethod:sel]) return YES;
    return [super respondsToSelector:sel];
}

- (void)drawRect:(NSRect)dirtyRect {
    USE(dirtyRect);
    static NSGradient *sGradient = nil;
    if (! sGradient) {
        NSColor *startColor = [NSColor colorWithCalibratedWhite:1. alpha:1.];
        NSColor *midColor = [NSColor colorWithCalibratedWhite:.85 alpha:1.];
        NSColor *endColor = [NSColor colorWithCalibratedWhite:.9 alpha:1.];
        sGradient = [[NSGradient alloc] initWithColors:[NSArray arrayWithObjects:startColor, midColor, endColor, nil]];
    }
    [sGradient drawInRect:[self bounds] angle:-90];
}

- (BOOL)isOpaque {
    return YES;
}

- (void)spinUntilFinished {
    HFASSERT([self operationIsRunning]);
    [tracker endTrackingProgress];
    [tracker setDelegate:nil];
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
    [self willChangeValueForKey:@"operationIsRunning"];
    thread = NULL;
    [self didChangeValueForKey:@"operationIsRunning"];
    [tracker release];
    tracker = nil;
    [self release];
}

- (void)progressTrackerDidFinish:(HFProgressTracker *)track {
    USE(track);
    [self willChangeValueForKey:@"progress"];
    progress = NO_TRACKING_PERCENTAGE;
    [self didChangeValueForKey:@"progress"];
    [self spinUntilFinished];
}

- (void)progressTracker:(HFProgressTracker *)track didChangeProgressTo:(double)fraction {
    USE(track);
    if (fabs(fraction - progress) >= .01) {
        [self willChangeValueForKey:@"progress"];
        progress = fraction;
        [self didChangeValueForKey:@"progress"];
    }
}

- (double)progress {
    return progress;
}

- (IBAction)cancelViewOperation:sender {
    USE(sender);
    if ([self operationIsRunning] && ! operationIsCancelling) {
        operationIsCancelling = YES;
        [tracker requestCancel:self];
        [self spinUntilFinished];
        operationIsCancelling = NO;
    }
}

- (BOOL)operationIsRunning { return !! thread; }

- (id)beginThread {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    id result = [target performSelector:startSelector withObject:tracker];
    [result retain];
    [tracker noteFinished:self];
    [pool drain];
    return result; //result is released in spinUntilFinished
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
    [tracker setDelegate:self];
    [tracker setUserInfo:callbacks.userInfo];
    [progressIndicator setDoubleValue:0];
    
    [[views objectForKey:@"cancelButton"] setHidden:NO];
    [progressIndicator setHidden:NO];
    [tracker setProgressIndicator:progressIndicator];
    [tracker beginTrackingProgress];
    
    [self retain];
    [self willChangeValueForKey:@"operationIsRunning"];
    int threadResult = pthread_create(&thread, NULL, startThread, self);
    if (threadResult != 0) [NSException raise:NSGenericException format:@"pthread_create returned error %d", threadResult];
    [self didChangeValueForKey:@"operationIsRunning"];
}

- (HFProgressTracker *)progressTracker {
    return tracker;
}

@end
