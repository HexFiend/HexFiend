//
//  HFPrivilegedHelperConnection.h
//  HexFiend_2
//
//  Created by Peter Ammon on 7/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFPrivilegedHelperConnection : NSObject {
    task_t childTask;
    mach_port_t childReceivePort;
}

+ (HFPrivilegedHelperConnection *)sharedConnection;
- (BOOL)launchAndConnect;
- (void)connectIfNecessary;

- (BOOL)readBytes:(void *)bytes range:(HFRange)range process:(pid_t)process error:(NSError **)error;

@end
