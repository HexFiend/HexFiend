//
//  HFDocumentOperation.m
//  HexFiend_2
//
//  Created by Peter Ammon on 2/26/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "HFDocumentOperationView.h"

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
}

- initWithFrame:(NSRect)frame {
    [super initWithFrame:frame];
    defaultSize = frame.size;
    nibName = [sNibName copy];
    views = [[NSMutableDictionary alloc] init];
    viewNamesToFrames = [[NSMutableDictionary alloc] init];
    return self;
}

- (void)dealloc {
    [views release];
    [viewNamesToFrames release];
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
        [viewNamesToFrames setObject:[NSValue valueWithRect:[view frame]] forKey:name];
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

typedef struct { CGFloat offset; CGFloat length; } Position_t;

- (void)resizeView:(NSView *)view withOriginalFrame:(NSRect)originalFrame intoBounds:(NSRect)bounds {
    Position_t horizontal = computePosition(
}

- (void)resizeSubviewsWithOldSize:(NSSize)size {
    NSRect bounds = [self bounds];
    NSEnumerator *enumer = [views keyEnumerator];
    NSString *key;
    while ((key = [enumer nextObject])) {
        NSView *view = [views objectForKey:key];
        NSRect viewOriginalFrame = [[viewNamesToFrames objectForKey:key] rectValue];
        [self resizeView:view withOriginalFrame:viewOriginalFrame intoBounds:bounds];
    }
}

@end
