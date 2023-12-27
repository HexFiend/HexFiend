//
//  HFPrivilegedHelperConnection.h
//  HexFiend_2
//
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <HexFiend/HFFrameworkPrefix.h>
#import <HexFiend/HFPrivilegedHelper.h>
#import "FortunateSonIPCTypes.h"

NS_ASSUME_NONNULL_BEGIN

struct HFProcessInfo_t {
    unsigned char bits; //either 32 or 64
};

@interface HFPrivilegedHelperConnection : NSObject <HFPrivilegedHelper> {
    NSMachPort *childReceiveMachPort;
}

@property BOOL disabled; ///< When set, fail all requests as if the connection failed.

+ (instancetype)sharedConnection;
- (BOOL)launchAndConnect:(NSError **)error;
- (BOOL)connectIfNecessary;

- (BOOL)readBytes:(void *)bytes range:(HFRange)range process:(pid_t)process error:(NSError **)error;
- (BOOL)getAttributes:(VMRegionAttributes *)outAttributes length:(unsigned long long *)outLength offset:(unsigned long long)offset process:(pid_t)process error:(NSError **)error;

- (BOOL)getInfo:(struct HFProcessInfo_t *)outInfo forProcess:(pid_t)process;

- (BOOL)openFileAtPath:(const char *)path writable:(BOOL)writable fileDescriptor:(int *)outFD error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
