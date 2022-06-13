#import "HFDirectoryWatcher.h"

@interface HFDirectoryWatcher ()

@property FSEventStreamRef fsStream;
@property dispatch_block_t handler;

@end

static void HFBinaryTemplateFSEvent(__unused ConstFSEventStreamRef streamRef,
                              void *clientCallBackInfo,
                              __unused size_t numEvents,
                              __unused void *eventPaths,
                              __unused const __unused FSEventStreamEventFlags *eventFlags,
                              __unused const FSEventStreamEventId *eventIds) {
    HFDirectoryWatcher* watcher = (__bridge HFDirectoryWatcher *)clientCallBackInfo;
    watcher.handler();
}

@implementation HFDirectoryWatcher

- (instancetype)initWithPath:(NSString *)path handler:(dispatch_block_t)aHandler {
    self = [super init];
    self.handler = aHandler;
    FSEventStreamContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
    self.fsStream = FSEventStreamCreate(kCFAllocatorDefault,
                                        HFBinaryTemplateFSEvent,
                                        &context,
                                        (__bridge CFArrayRef)(@[path]),
                                        kFSEventStreamEventIdSinceNow,
                                        0.1, // Avoid events from "Safe Save"
                                        kFSEventStreamCreateFlagFileEvents|
                                        kFSEventStreamCreateFlagIgnoreSelf|
                                        kFSEventStreamCreateFlagUseCFTypes);
    FSEventStreamSetDispatchQueue(self.fsStream, dispatch_get_main_queue());
    FSEventStreamStart(self.fsStream);
    return self;
}

- (void)stop {
    FSEventStreamStop(self.fsStream);
}

@end
