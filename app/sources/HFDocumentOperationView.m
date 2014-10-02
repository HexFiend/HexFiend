//
//  HFDocumentOperation.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFDocumentOperationView.h"
#import <HexFiend/HFProgressTracker.h>
#include <dispatch/dispatch.h>
#include <objc/message.h>

static NSString *sNibName;

#define NO_TRACKING_PERCENTAGE (-1)

@interface HFDocumentOperationView (PrivateStuff)
- (id)beginThread NS_RETURNS_RETAINED;
@end

@interface NSObject (BackwardCompatibleDeclarations)
- (NSString *)userInterfaceItemIdentifier;
@end

@implementation HFDocumentOperationView

+ (HFDocumentOperationView *)viewWithNibNamed:(NSString *)name owner:(id)owner {
    NSString *path = [[NSBundle bundleForClass:self] pathForResource:name ofType:@"nib"];
    if (! path) [NSException raise:NSInvalidArgumentException format:@"Unable to find nib named %@", name];
    sNibName = [name copy];
    NSMutableArray *topLevelObjects = [NSMutableArray array];
    if ([[NSBundle mainBundle] respondsToSelector:@selector(loadNibNamed:owner:topLevelObjects:)]) {
        /* for Mac OS X 10.8 or higher */
        // unlike -loadNibFile:externalNameTable:withZone: which is deprecated in 10.8, this method does
        // not retain top level objects automatically, so objects must be set retain
        if (! [[NSBundle mainBundle] loadNibNamed:name owner:owner topLevelObjects:&topLevelObjects]) {
            [NSException raise:NSInvalidArgumentException format:@"Unable to load nib at path %@", path];
        }
        [topLevelObjects retain];
    } else {
        /* for Mac OS X 10.7 or lower */
        if (! [NSBundle loadNibFile:path externalNameTable:@{@"NSTopLevelObjects": topLevelObjects, @"NSOwner": owner} withZone:NULL]) {
            [NSException raise:NSInvalidArgumentException format:@"Unable to load nib at path %@", path];
        }
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

- (void)awakeFromNib {
    awokenFromNib = YES;
    [super awakeFromNib];
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    defaultSize = frame.size;
    nibName = [sNibName copy];
    progress = NO_TRACKING_PERCENTAGE;
    return self;
}

- (void)dealloc {
    [otherTopLevelObjects release];
    [nibName release];
    [_displayName release];
    [super dealloc];
}

static NSView *searchForViewWithIdentifier(NSView *view, NSString *identifier) {
    /* Maybe this view is it */
    NSView *result = nil;
    if ([view respondsToSelector:@selector(identifier)]) {
        if ([[view identifier] isEqual:identifier]) result = view;
    } else if ([view respondsToSelector:@selector(userInterfaceItemIdentifier)]) {
        if ([[view userInterfaceItemIdentifier] isEqual:identifier]) result = view;
    }
    
    if (! result) {
        /* Try subviews */
        FOREACH(NSView *, subview, [view subviews]) {
            if ((result = searchForViewWithIdentifier(subview, identifier))) break;
        }
    }
    return result;
}

- (NSView *)viewNamed:(NSString *)name {
    NSView *view = searchForViewWithIdentifier(self, name);
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

- (void)drawRect:(NSRect)dirtyRect {
    USE(dirtyRect);
    static NSGradient *sGradient = nil;
    if (! sGradient) {
        NSColor *startColor = [NSColor colorWithCalibratedWhite:1. alpha:1.];
        NSColor *midColor = [NSColor colorWithCalibratedWhite:.85 alpha:1.];
        NSColor *endColor = [NSColor colorWithCalibratedWhite:.9 alpha:1.];
        sGradient = [[NSGradient alloc] initWithColors:@[startColor, midColor, endColor]];
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
    [cancelButton setHidden:YES];
    [progressIndicator setHidden:YES];
    dispatch_group_wait(waitGroup, DISPATCH_TIME_FOREVER);
    completionHandler(threadResult);
    [(id)threadResult release];
    [tracker release];
    tracker = nil;
    [self willChangeValueForKey:@"operationIsRunning"];
    dispatch_release(waitGroup);
    waitGroup = NULL;
    [self didChangeValueForKey:@"operationIsRunning"];
    [cancelButton setHidden: ! [self operationIsRunning]];
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
    if (fabs(fraction - progress) >= .001) {
        [self willChangeValueForKey:@"progress"];
        progress = fraction;
        [self didChangeValueForKey:@"progress"];
        [progressIndicator setDoubleValue:progress];
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

- (BOOL)operationIsRunning { return !! waitGroup; }

- (void)startOperation:(id (^)(HFProgressTracker *tracker))block completionHandler:(void (^)(id result))handler {
    HFASSERT(! [self operationIsRunning]);
    startBlock = [block copy];
    completionHandler = [handler copy];

    tracker = [[HFProgressTracker alloc] init];
    [tracker setDelegate:self];
    [progressIndicator setDoubleValue:0];
    
    [cancelButton setHidden:NO];
    [progressIndicator setHidden:NO];
    [tracker setProgressIndicator:progressIndicator];
    [tracker beginTrackingProgress];
    
    [self retain];
    [self willChangeValueForKey:@"operationIsRunning"];
    waitGroup = dispatch_group_create();
    dispatch_group_async(waitGroup, dispatch_get_global_queue(0, 0), ^{
        @autoreleasepool {
            threadResult = [startBlock(tracker) retain];
            [tracker noteFinished:self];
        }
    });
    [self didChangeValueForKey:@"operationIsRunning"];
    [cancelButton setHidden: ! [self operationIsRunning]];
}

- (HFProgressTracker *)progressTracker {
    return tracker;
}

@end
