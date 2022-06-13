#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HFDirectoryWatcher : NSObject

- (instancetype)initWithPath:(NSString *)path handler:(dispatch_block_t)aHandler;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
