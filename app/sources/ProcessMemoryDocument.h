//
//  ProcessMemoryDocument.h
//  HexFiend_2
//
//  Copyright 2009 ridiculous_fish. All rights reserved.
//

#import "BaseDataDocument.h"

@interface ProcessMemoryDocument : BaseDataDocument {

}

- (void)openProcessWithPID:(pid_t)pid;

@end
