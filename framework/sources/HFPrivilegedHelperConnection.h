//
//  HFPrivilegedHelperConnection.h
//  HexFiend_2
//
//  Created by Peter Ammon on 7/31/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FortunateSonIPCTypes.h"

@interface HFPrivilegedHelperConnection : NSObject {
    task_t childTask;
    mach_port_t childReceivePort;
}

+ (HFPrivilegedHelperConnection *)sharedConnection;
- (BOOL)launchAndConnect;
- (BOOL)connectIfNecessary;

- (BOOL)readBytes:(void *)bytes range:(HFRange)range process:(pid_t)process error:(NSError **)error;
- (BOOL)getAttributes:(VMRegionAttributes *)outAttributes length:(unsigned long long *)outLength offset:(unsigned long long)offset process:(pid_t)process error:(NSError **)error;

- (BOOL)openFileAtPath:(const char *)path writable:(BOOL)writable result:(int *)outFD resultError:(int *)outErrno fileSize:(unsigned long long *)outFileSize fileType:(uint16_t *)outFileType inode:(unsigned long long *)outInode device:(int *)outDevice;

/* Reads the file 'fd' at offset 'offset' into the given buffer 'result' with the given length and given alignment.  Returns how many bytes were read in that length. */
- (BOOL)readFile:(int)fd offset:(unsigned long long)offset alignment:(uint32_t)alignment length:(uint32_t *)inoutLength result:(unsigned char *)result error:(int *)outErr;

- (BOOL)closeFile:(int)fd;

@end
