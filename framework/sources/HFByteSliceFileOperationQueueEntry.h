//
//  HFByteSliceFileOperationQueueEntry.h
//  HexFiend_2
//
//  Created by Peter Ammon on 3/15/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface HFByteSliceFileOperationQueueEntry : NSObject {
	@public
	NSUInteger length;
	unsigned long long offset; //target location
	unsigned char *bytes;
	unsigned long long source; //for debugging
}

@end
