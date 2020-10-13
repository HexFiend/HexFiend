//
//  HFDocumentOperation.m
//  HexFiend_2
//
//  Copyright 2008 ridiculous_fish. All rights reserved.
//

#import "HFDocumentOperationView.h"
#import <HexFiend/HexFiend.h>

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
    if (! [[NSBundle mainBundle] loadNibNamed:name owner:owner topLevelObjects:&topLevelObjects]) {
        [NSException raise:NSInvalidArgumentException format:@"Unable to load nib at path %@", path];
    }
    sNibName = nil;
    HFDocumentOperationView *resultObject = nil;
    NSMutableArray *otherObjects = nil;
    for(id obj in topLevelObjects) {
        if ([obj isKindOfClass:[self class]]) {
            HFASSERT(resultObject == nil);
            resultObject = obj;
        }
        else {
            if (! otherObjects) otherObjects = [NSMutableArray array];
            [otherObjects addObject:obj];
        }
    }
    HFASSERT(resultObject != nil);
    if (otherObjects != nil) [resultObject setOtherTopLevelObjects:otherObjects];
    
    /* This object is NOT sent autorelease too many times, no matter what the analyzer says, because it has an extra retain by virtue of being a nib top level object. */
    return resultObject;
}

- (void)setOtherTopLevelObjects:(NSArray *)objects {
    objects = [objects copy];
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
        for(NSView *subview in [view subviews]) {
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
    
    NSRect bounds = self.bounds;
    
    if (HFDarkModeEnabled()) {
        [[NSColor controlBackgroundColor] set];
        NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);
        return;
    }

    static NSGradient *sGradient = nil;
    if (! sGradient) {
        NSColor *startColor = [NSColor colorWithCalibratedWhite:1. alpha:1.];
        NSColor *midColor = [NSColor colorWithCalibratedWhite:.85 alpha:1.];
        NSColor *endColor = [NSColor colorWithCalibratedWhite:.9 alpha:1.];
        sGradient = [[NSGradient alloc] initWithColors:@[startColor, midColor, endColor]];
    }
    [sGradient drawInRect:bounds angle:-90];
    
    [[NSColor lightGrayColor] set];
    NSRect line = NSMakeRect(NSMinX(bounds), NSMinY(bounds), NSWidth(bounds), 1.0);
    NSFrameRectWithWidthUsingOperation(line, 1.0, NSCompositingOperationSourceOver);
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
    completionHandler = nil;
    tracker = nil;
    [self willChangeValueForKey:@"operationIsRunning"];
    waitGroup = NULL;
    [self didChangeValueForKey:@"operationIsRunning"];
    [cancelButton setHidden: ! [self operationIsRunning]];
    tracker = nil;
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
    completionHandler = [handler copy];

    tracker = [[HFProgressTracker alloc] init];
    [tracker setDelegate:self];
    [progressIndicator setDoubleValue:0];
    
    [cancelButton setHidden:NO];
    [progressIndicator setHidden:NO];
    [tracker setProgressIndicator:progressIndicator];
    [tracker beginTrackingProgress];
    
    [self willChangeValueForKey:@"operationIsRunning"];
    waitGroup = dispatch_group_create();
    dispatch_group_async(waitGroup, dispatch_get_global_queue(0, 0), ^{
        @autoreleasepool {
            self->threadResult = block(self->tracker);
            [self->tracker noteFinished:self];
        }
    });
    [self didChangeValueForKey:@"operationIsRunning"];
    [cancelButton setHidden: ! [self operationIsRunning]];
}

- (HFProgressTracker *)progressTracker {
    return tracker;
}

@end
