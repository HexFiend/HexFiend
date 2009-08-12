//
//  HFPrivilegedHelperConnection.m
//  HexFiend_2
//
//  Created by Peter Ammon on 7/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "HFPrivilegedHelperConnection.h"
#import "HFHelperProcessSharedCode.h"
#import "FortunateSon.h"

static HFPrivilegedHelperConnection *sSharedConnection;


struct inheriting_fork_return_t {
    task_t child_task;
    pid_t child_pid;
};
static struct inheriting_fork_return_t fork_with_inherit(const char *path);

@implementation HFPrivilegedHelperConnection

+ (HFPrivilegedHelperConnection *)sharedConnection {
    if (! sSharedConnection) {
	sSharedConnection = [[self alloc] init];
    }
    return sSharedConnection;
}

- (id)init {
    [super init];
    return self;
}

- (BOOL)launchAndConnect {
    BOOL result = YES;
    NSBundle *bund = [NSBundle bundleForClass:[self class]];
    NSString *helperPath = [bund pathForResource:@"FortunateSon" ofType:@""];
    if (! helperPath) {
	[NSException raise:NSInternalInconsistencyException format:@"Couldn't find FortunateSon helper tool in bundle %@", bund];
    }
    NSString *launcherPath = [bund pathForResource:@"FortunateSonCopier" ofType:@""];
    if (! launcherPath) {
	[NSException raise:NSInternalInconsistencyException format:@"Couldn't find FortunateSonCopier helper tool in bundle %@", bund];
    }
    
    OSStatus status;
    
    AuthorizationRef authorizationRef = NULL;
    status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
    result = result && (status == noErr);
    
    if (result) {
        AuthorizationItem authItems = { kAuthorizationRightExecute, 0, NULL, 0};
        AuthorizationRights authRights = {1, &authItems};

        AuthorizationFlags authFlags = kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed | kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights;
                    
        status = AuthorizationCopyRights(authorizationRef, &authRights, NULL, authFlags, NULL);
        if (status != errAuthorizationSuccess) {
            result = NO;
            if (status == errAuthorizationCanceled || status == errAuthorizationDenied) {
                NSLog(@"AuthorizationCopyRights returned error: %ld", (long)status);
            }
        }
    }
    
    FILE *pipe = NULL;
    if (result) {
        const char *launcherPathCString = [launcherPath fileSystemRepresentation];
        const char * const arguments[] = {launcherPathCString, [helperPath fileSystemRepresentation]};
        OSStatus authorizationResult = AuthorizationExecuteWithPrivileges(authorizationRef, launcherPathCString, 0, (char * const *)arguments, &pipe);
        
        if (authorizationResult != errAuthorizationSuccess) {
            NSLog(@"AuthorizationExecuteWithPrivileges %s returned error: %ld (%lx)", launcherPathCString, (long)authorizationResult, (long)authorizationResult);
            result = NO;
        }
    }
    
    if (result) {
        NSMutableString *resultString = [NSMutableString string];
        /* Read from the tool until it exits */
        char buffer[512];
        while ((fgets(buffer, sizeof buffer, pipe))) {
            [resultString appendString:[NSString stringWithUTF8String:buffer]];
        }
        
        NSArray *resultStrings = [resultString componentsSeparatedByString:@"\n"];
        NSLog(@"Results: %@", resultStrings);
    }

    //struct inheriting_fork_return_t fork_return = fork_with_inherit([path fileSystemRepresentation]);
    //printf("CHILD PID: %d\n", fork_return.child_pid);
    return result;
}

+ (void)load {
    id pool = [[NSAutoreleasePool alloc] init];
    [self performSelector:@selector(test:) withObject:nil afterDelay:.1];
    [pool release];
}

+ (void)test:unused {
    USE(unused);
    HFPrivilegedHelperConnection *helper = [HFPrivilegedHelperConnection sharedConnection];
    [helper launchAndConnect];
}

@end

// We need to weak-import posix_spawn and friends as they're not available on Tiger.
// The BSD-level system headers do not have availability macros, so we redeclare the
// functions ourselves with the "weak" attribute.

#define WEAK_IMPORT __attribute__((weak))
#define POSIX_SPAWN_SETEXEC 0x0040
typedef void *posix_spawnattr_t;
typedef void *posix_spawn_file_actions_t;
int posix_spawnattr_init(posix_spawnattr_t *) WEAK_IMPORT;
int posix_spawn(pid_t * __restrict, const char * __restrict, const posix_spawn_file_actions_t *, const posix_spawnattr_t * __restrict, char *const __argv[ __restrict], char *const __envp[ __restrict]) WEAK_IMPORT;
int posix_spawnattr_setbinpref_np(posix_spawnattr_t * __restrict, size_t, cpu_type_t *__restrict, size_t *__restrict) WEAK_IMPORT;
int posix_spawnattr_setflags(posix_spawnattr_t *, short) WEAK_IMPORT;

extern char ***_NSGetEnviron(void);

static struct inheriting_fork_return_t fork_with_inherit(const char *path) {
    struct inheriting_fork_return_t result = {-1, -1};
    const struct inheriting_fork_return_t errorReturn = {-1, -1};
    kern_return_t       err;
    mach_port_t         parent_recv_port = MACH_PORT_NULL;
    mach_port_t         child_recv_port = MACH_PORT_NULL;

    if (setup_recv_port(&parent_recv_port) != 0)
        return errorReturn;
    CHECK_MACH_ERROR(task_set_bootstrap_port(mach_task_self(), parent_recv_port));

    //TODO: use posix_spawnattr_setspecialport_np here instead of fiddling with the bootstrap port
    char * argv[] = {(char *)path, NULL};
    int posixErr = posix_spawn(&result.child_pid, path, NULL/*file actions*/, NULL/*spawn attr*/, argv, *_NSGetEnviron());
    if (posixErr != 0) {
	printf("posix_spawn failed\n");
	return errorReturn;
    }

    /* talk to the child */
    err = task_set_bootstrap_port (mach_task_self (), bootstrap_port);
    CHECK_MACH_ERROR (err);
    if (recv_port (parent_recv_port, &result.child_task) != 0)
	return errorReturn;
    if (recv_port (parent_recv_port, &child_recv_port) != 0)
	return errorReturn;
    if (send_port (child_recv_port, bootstrap_port, MACH_MSG_TYPE_COPY_SEND) != 0)
	return errorReturn;
    err = mach_port_deallocate (mach_task_self(), parent_recv_port);
    CHECK_MACH_ERROR (err);
    int val;
    _GratefulFatherSayHey(child_recv_port, "From Daddy", &val);
    printf("Daddy got back Val: %d\n", val);

    return result;
}
